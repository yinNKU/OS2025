## 分支任务：使用 GDB 调试 QEMU 模拟的 RISC-V 页表查询过程

#### 1. QEMU 源码分析与地址翻译路径

在 QEMU 中，RISC-V 架构的地址翻译核心逻辑位于 `target/riscv/cpu_helper.c` 文件中的 `get_physical_address` 函数。

**关键调用路径：**
当 Guest OS（如 ucore）执行一条访存指令（如 `ld` 或 `sd`）时，如果该地址在 QEMU 的软件 TLB（SoftMMU TLB）中未命中，会触发以下调用链：
1.  `store_helper` / `load_helper` (在 `accel/tcg/cputlb.c`): TCG 生成的访存辅助函数。
2.  `tlb_fill` (在 `accel/tcg/cputlb.c`): 处理 TLB 未命中的通用入口。
3.  `riscv_cpu_tlb_fill` (在 `target/riscv/cpu_helper.c`): RISC-V 架构特定的 TLB 填充函数。
4.  `get_physical_address` (在 `target/riscv/cpu_helper.c`): **核心函数**，模拟硬件页表遍历（Page Table Walk）。

**关键分支语句分析 (`get_physical_address`)：**

*   **模式检查与直通模式**:
    ```c
    if (mode == PRV_M || !riscv_feature(env, RISCV_FEATURE_MMU)) {
        *physical = addr;
        // ...
        return TRANSLATE_SUCCESS;
    }
    ```
    如果 CPU 处于 Machine Mode (M-mode) 或者未开启 MMU，则直接将虚拟地址作为物理地址（Identity Mapping）。

*   **SATP/MSTATUS 配置读取**:
    ```c
    if (env->priv_ver >= PRIV_VERSION_1_10_0) {
        base = get_field(env->satp, SATP_PPN) << PGSHIFT; // 获取页表基址
        vm = get_field(env->satp, SATP_MODE);             // 获取分页模式 (如 SV39)
        // ...
    }
    ```
    这里模拟了硬件读取 `satp` 寄存器以获取根页表物理地址的过程。

*   **页表遍历循环**:
    ```c
    for (i = 0; i < levels; i++, ptshift -= ptidxbits) {
        // 计算当前级页表的索引
        target_ulong idx = (addr >> (PGSHIFT + ptshift)) & ((1 << ptidxbits) - 1);
        // 计算页表项（PTE）的物理地址
        target_ulong pte_addr = base + idx * ptesize;
        // 从物理内存读取 PTE
        target_ulong pte = ldq_phys(cs->as, pte_addr);
        // ...
    }
    ```
    这是模拟硬件逐级查找页表的关键循环。

#### 2. 单步调试页表翻译流程

在调试过程中，我们观察到了 `get_physical_address` 中的 `for` 循环是如何工作的。

*   **循环的作用**: 该循环模拟了多级页表的遍历。对于 SV39 模式，`levels` 为 3。循环会执行 3 次（理想情况下），分别对应一级页表（页目录）、二级页表和三级页表（页表项）。
*   **关键操作解释**:
    1.  `idx = ...`: 从虚拟地址 `addr` 中提取当前级别的 VPN (Virtual Page Number) 片段。
    2.  `pte_addr = base + idx * ptesize`: 结合当前页表的基地址 `base` 和索引 `idx`，计算出目标 PTE 在物理内存中的地址。
    3.  `ldq_phys(...)`: QEMU 使用此函数直接访问模拟的物理内存，读取 64 位的 PTE 内容。
    4.  **PTE 有效性检查**: 代码中包含一系列 `if-else` 语句检查 `PTE_V` (Valid)、`PTE_R/W/X` (权限位)。
        *   如果 `!(pte & (PTE_R | PTE_W | PTE_X))`，说明这是中间级页表，代码更新 `base = ppn << PGSHIFT`，让下一轮循环指向下一级页表。
        *   如果权限位被设置，说明这是叶子节点（Leaf PTE），循环结束，找到物理页帧号。

#### 3. QEMU 模拟 TLB 查找的细节

**查找代码位置**:
QEMU 的 TLB 查找逻辑主要在 `accel/tcg/cputlb.c` 和 `include/exec/cpu_ldst_template.h` 中。

**查找流程**:
是的，按照 RISC-V 流程，确实是 **先查 TLB，Miss 后查页表**。QEMU 也是这样模拟的：

1.  **查 TLB (Fast Path)**:
    在 `store_helper` 中：
    ```c
    // 计算索引
    uintptr_t index = tlb_index(env, mmu_idx, addr);
    // 获取表项
    CPUTLBEntry *entry = tlb_entry(env, mmu_idx, addr);
    // 比较 Tag (tlb_hit)
    if (!tlb_hit(tlb_addr, addr)) {
        // TLB Miss -> 进入 Slow Path
        tlb_fill(...);
    }
    ```
    这段代码就是模拟 CPU 硬件查找 TLB 的过程。

2.  **查页表 (Slow Path)**:
    `tlb_fill` 最终调用 `get_physical_address` (如上所述) 进行页表遍历。如果遍历成功，会调用 `tlb_set_page` 将新的映射填入 QEMU 的 SoftMMU TLB 中，以便下次快速访问。

#### 4. QEMU 模拟 TLB 与真实 CPU TLB 的逻辑区别

*   **真实 CPU TLB**: 是硬件缓存，容量有限（如 64-128 项），通常是全相联或组相联。未开启分页（Bare Metal）时，TLB 行为取决于具体微架构，但通常地址直接透传，不经过 TLB 转换或经过一个特殊的透明 TLB。
*   **QEMU SoftMMU TLB**: 是一个纯软件的哈希表（直接映射或低路数关联）。
    *   **逻辑区别**: 即使在 **未开启虚拟地址空间** (如 M-mode) 时，QEMU **仍然使用 TLB**。
    *   **调试观察**: 当我们在 M-mode 下调试访存指令时，发现 `get_physical_address` 会直接返回 `*physical = addr` (Identity Mapping)。但是，QEMU 依然会将这个 "虚拟地址=物理地址" 的映射关系填入 SoftMMU TLB。
    *   **原因**: QEMU 为了性能统一了访存路径。无论是否开启分页，所有访存都先查 SoftMMU TLB。如果未开启分页，就填入一个恒等映射。这与真实硬件在关闭 MMU 时直接绕过 TLB 的行为在实现细节上是不同的，但对软件来说效果一致。

## 分支任务：gdb 调试系统调用（ecall / sret）

目的：使用双重 GDB（Host 附加 QEMU，Guest 连接 QEMU gdbstub）观察用户态发起 `ecall`、内核处理、以及通过 `sret` 返回用户态的完整流程；并阅读 QEMU 中相关翻译与 helper 实现以解释关键细节。

### 关键源码位置（QEMU 4.1.1）
- 翻译层（生成 helper 调用）: `target/riscv/insn_trans/trans_privileged.inc.c`
  - `trans_ecall`：调用 `generate_exception(ctx, RISCV_EXCP_U_ECALL)` 生成异常 helper。
  - `trans_sret`：生成对 `gen_helper_sret` 的 helper 调用。
- helper / 运行时：`target/riscv/op_helper.c`
  - `helper_raise_exception` -> `riscv_raise_exception`：在运行时设置异常并退出 TB，回到 QEMU 主循环处理 trap。
  - `helper_sret` / `helper_mret`：恢复特权与返回 PC 的实现。
- 高层处理：`target/riscv/cpu_helper.c`
  - `riscv_cpu_do_interrupt`：异常/中断分发与 syscall 处理入口。

### 调试思路（双重 GDB）
- Host-GDB（附加 QEMU 进程）：在 QEMU C 代码层设置断点（如 `riscv_raise_exception`、`riscv_cpu_do_interrupt`、`helper_sret`），用于观察 QEMU 如何在 C 层处理中断与返回。
- Guest-GDB（连接 QEMU gdbstub）：加载用户程序符号（`add-symbol-file obj/__user_*.out`），在 `syscall` 封装处断下并单步到汇编 `ecall` 指令，然后让 Guest 执行 `si` 触发 `ecall`。

### 操作步骤
1) 启动 QEMU（终端 A）
```bash
cd lab5
make debug
```
2) Host-GDB（终端 B）——附加到正在运行的 qemu-system-riscv64 并设置断点：
```bash
sudo gdb /path/to/qemu-system-riscv64
(gdb) attach <QEMU_PID>
(gdb) break riscv_raise_exception
(gdb) break riscv_cpu_do_interrupt
(gdb) break helper_sret
(gdb) continue
```
3) Guest-GDB（终端 C）——连接 gdbstub、加载用户符号并停在 `ecall` 前：
```bash
riscv64-unknown-elf-gdb obj/<kernel-or-user-elf>
(gdb) target remote :1234
(gdb) add-symbol-file obj/__user_exit.out   # 示例
(gdb) break user/libs/syscall.c:18
(gdb) continue
# 当停在 syscall() 时，使用 `si` 单步到 ecall
(gdb) si
```

### 观测流程要点
- 在 Guest 上单步执行 `ecall`（`si`）后，QEMU 翻译生成的 helper 会在 Host 层触发并使 TB 退出，Host-GDB 中的 `riscv_raise_exception` / `riscv_cpu_do_interrupt` 断点会命中。
- 在 Host-GDB 中可查看 `env->pc`、异常码（如 `RISCV_EXCP_U_ECALL`）以及调用栈（`bt`），然后沿着 `riscv_cpu_do_interrupt` 跟踪到内核的 syscall 分发位置，观察寄存器 `a0..a7` 的参数如何被读取。
- 处理结束后内核执行 `sret`，QEMU 对 `sret` 生成 `helper_sret`，在 Host-GDB 设置 `break helper_sret` 可捕获返回用户态前的恢复操作，查看 `mstatus`/`sepc`/返回 PC 等。

### 为什么在 Host 看到 C 层代码？（TCG 简述）
QEMU 的 TCG 翻译把目标指令翻译成 host 机器代码。对复杂或特权相关的操作（如 `ecall`/`sret`），TCG 不直接内联所有语义，而是生成对 C helper 的调用（例如 `gen_helper_sret` / `generate_exception`），helper 在运行时执行复杂逻辑并通过 `exit_tb()` 让 QEMU 回到 C 层处理。

## 练习1: 加载应用程序并执行

### 1. 设计实现过程

`load_icode` 函数的主要作用是将 ELF 格式的二进制程序加载到内存中，并为该进程建立用户态的内存空间和执行环境。我们需要补充的是第 6 步：设置 `trapframe`（中断帧），以便内核在完成加载后，能够正确地切换回用户态并开始执行应用程序。

**代码实现 (kern/process/proc.c):**

我们在 `load_icode` 函数的末尾添加了如下代码：

```c
    /* LAB5:EXERCISE1 YOUR CODE */
    // 设置用户栈指针：指向用户栈的顶部
    tf->gpr.sp = USTACKTOP;
    
    // 设置程序计数器 (PC/EPC)：指向 ELF 头中定义的入口点
    tf->epc = elf->e_entry;
    
    // 设置 sstatus 寄存器：
    // 1. 清除 SSTATUS_SPP 位：确保 sret 指令执行后，CPU 特权级切换回 User Mode (U-mode)。
    // 2. 设置 SSTATUS_SPIE 位：确保返回用户态后，中断是开启的 (Enable Interrupts)。
    tf->status = (sstatus & ~SSTATUS_SPP) | SSTATUS_SPIE;
    
    // 清除 SSTATUS_SIE 位：在内核态处理期间禁用中断，直到 sret 恢复 SPIE 到 SIE。
    tf->status &= ~SSTATUS_SIE;
```

### 2. 从 RUNNING 到执行第一条指令的经过

当一个用户态进程被 ucore 的调度器选择占用 CPU 执行（状态变为 RUNNING）后，到它执行应用程序第一条指令的完整过程如下：

1.  **调度 (Schedule):** `schedule()` 函数决定运行该进程，调用 `proc_run(next)`。
2.  **上下文切换 (Context Switch):** `proc_run` 调用 `switch_to`，汇编代码将 CPU 的寄存器（callee-saved registers）和栈指针切换到新进程的内核栈和上下文 (`proc->context`)。
3.  **返回内核入口:** `switch_to` 返回，由于新进程的 `context.ra` 在 `copy_thread` 中被设置为 `forkret` 的地址，CPU 跳转到 `forkret` 函数执行。
4.  **中断返回准备:** `forkret` 函数调用 `forkrets(current->tf)`。`forkrets` 是一段汇编代码，它将栈指针指向 `current->tf`（即我们在 `load_icode` 中设置好的 trapframe），然后跳转到 `__trapret`。
5.  **恢复寄存器:** `__trapret` (位于 `trapentry.S`) 执行一系列 `LOAD` 指令，从 trapframe 中恢复所有的通用寄存器（包括 `a0` 等参数寄存器）和状态寄存器 (`sstatus`, `sepc`)。
6.  **特权级切换 (sret):** 执行 `sret` 指令。
    *   CPU 检查 `sstatus` 的 `SPP` 位（我们在 `load_icode` 中设为 0），于是将当前特权级从 Supervisor Mode 切换到 User Mode。
    *   CPU 将程序计数器 (PC) 设置为 `sepc` 的值（即 `elf->e_entry`，应用程序入口）。
    *   CPU 恢复中断使能状态（根据 `SPIE` 位）。
7.  **执行用户代码:** 此时 CPU 处于用户态，PC 指向应用程序的第一条指令，SP 指向用户栈顶 (`USTACKTOP`)，应用程序开始执行。

---

## 练习2: 父进程复制自己的内存空间给子进程

### 1. 设计实现过程

`do_fork` 函数在创建子进程时，会调用 `copy_mm` -> `dup_mmap` -> `copy_range` 来复制父进程的内存空间。`copy_range` 的任务是逐页复制内存内容。

**代码实现 (kern/mm/pmm.c):**

我们在 `copy_range` 函数中实现了如下逻辑：

```c
            /* LAB5:EXERCISE2 YOUR CODE */
            // 1. 获取源页面（父进程）的内核虚拟地址
            void *src_kvaddr = page2kva(page);
            
            // 2. 获取目标页面（子进程，已分配）的内核虚拟地址
            void *dst_kvaddr = page2kva(npage);
            
            // 3. 内存拷贝：将源页面的内容完整复制到目标页面
            memcpy(dst_kvaddr, src_kvaddr, PGSIZE);
            
            // 4. 建立映射：将新页面插入到子进程的页表中
            // 使用与父进程相同的线性地址 (start) 和权限 (perm)
            ret = page_insert(to, npage, start, perm);
```

## 练习3: 进程执行 fork/exec/wait/exit 的实现

### 1. 执行流程与用户态/内核态分析

*   **fork:**
    *   **用户态:** 调用 `fork()` 库函数，执行 `ecall` 指令陷入内核。
    *   **内核态:** `sys_fork` -> `do_fork`。
        *   分配 `proc_struct`，分配内核栈。
        *   **关键:** 复制父进程的内存布局 (`copy_mm`) 和中断帧 (`copy_thread`)。
        *   设置子进程的 `tf->gpr.a0 = 0` (子进程返回值为0)。
        *   将子进程加入进程列表，设为 `PROC_RUNNABLE`。
        *   父进程 `do_fork` 返回子进程 PID。
    *   **返回:** 父进程从系统调用返回（得到 PID），子进程被调度后从 `forkret` 开始执行，最终返回用户态（得到 0）。

*   **exec:**
    *   **用户态:** 调用 `exec()`，执行 `ecall`。
    *   **内核态:** `sys_exec` -> `do_execve`。
        *   回收当前进程的内存空间 (`exit_mmap`)。
        *   调用 `load_icode` 加载新的 ELF 二进制文件。
        *   **关键:** 重新设置 `trapframe`（如练习1所述），将 PC 设为新程序入口，SP 设为新用户栈。
    *   **返回:** `sret` 后，进程不再返回到调用 `exec` 的地方，而是从新程序的入口点开始执行。

*   **wait:**
    *   **用户态:** 调用 `wait()`，执行 `ecall`。
    *   **内核态:** `sys_wait` -> `do_wait`。
        *   查找是否有状态为 `PROC_ZOMBIE` 的子进程。
        *   如果有，回收其剩余资源（`proc_struct`, 内核栈），返回其 PID 和退出码。
        *   如果子进程还在运行，将当前进程状态设为 `PROC_SLEEPING`，并调用 `schedule()` 让出 CPU。
    *   **交互:** 当子进程退出时会唤醒父进程，父进程从 `schedule()` 返回继续执行回收操作。

*   **exit:**
    *   **用户态:** 调用 `exit()`，执行 `ecall`。
    *   **内核态:** `sys_exit` -> `do_exit`。
        *   释放页表和内存空间 (`mm_destroy`)。
        *   将状态设为 `PROC_ZOMBIE`。
        *   唤醒父进程 (`wakeup_proc(parent)`)。
        *   调用 `schedule()` 主动让出 CPU，且不再返回。

**内核态与用户态交错:**
程序主要在用户态运行。当需要操作系统服务（如创建进程）或发生硬件中断（如时钟中断）时，通过 `ecall` 或中断机制切换到内核态。内核在当前进程的内核栈上执行处理逻辑，处理完毕后通过 `sret` 指令恢复上下文并返回用户态。执行结果通常通过寄存器（如 RISC-V 的 `a0`）传递给用户程序。

### 2. 用户态进程执行状态生命周期图

```text
   (alloc_proc)
        |
        V
  +-------------+
  | PROC_UNINIT |
  +-------------+
        | do_fork
        V
  +-------------+   scheduler/   +--------------+
  | PROC_RUNNABLE | <----------> | PROC_RUNNING |
  +-------------+     yield      +--------------+
        ^     |                    |      |
        |     | do_wait/           |      | do_exit
 wakeup |     | do_sleep           |      |
        |     V                    |      V
  +-------------+                  +-------------+
  | PROC_SLEEPING |                | PROC_ZOMBIE |
  +-------------+                  +-------------+
                                          |
                                          | do_wait (by parent)
                                          V
                                     (reclaimed)
```

*   **NULL -> UNINIT:** `alloc_proc` 分配进程控制块。
*   **UNINIT -> RUNNABLE:** `do_fork` 完成进程初始化。
*   **RUNNABLE -> RUNNING:** 调度器 (`schedule`) 选中该进程。
*   **RUNNING -> RUNNABLE:** 时间片耗尽或被抢占。
*   **RUNNING -> SLEEPING:** 进程请求等待某个事件（如 `wait`, `sleep`）。
*   **SLEEPING -> RUNNABLE:** 等待的事件发生（如子进程退出，被 `wakeup`）。
*   **RUNNING -> ZOMBIE:** 进程执行结束 (`exit`)，等待父进程回收。
*   **ZOMBIE -> NULL:** 父进程执行 `wait` 回收资源。
## 练习3：fork / exec / wait / exit 源码分析

下面给出对 `fork`、`exec`、`wait`、`exit` 在 ucore 中实现的简要分析，包括哪些操作在用户态完成、哪些在内核态完成，以及内核与用户态如何交错执行和结果如何返回给用户程序。

1) 总体执行流程（概述）

- `fork`：用户进程调用库函数触发软中断（`ecall`），陷入内核；内核在内核态分配新进程表项、复制或写时复制父进程的页表/内存、复制文件描述符等资源，设置子进程上下文，返回子进程 PID 给父进程并在子进程上下文中返回 0。
- `exec`：用户进程调用 `execve` 类系统调用（通过 `ecall`），内核在内核态加载新程序映像（从文件系统读入二进制、建立新的用户页表、设置用户栈、参数与环境），替换当前进程的地址空间，最后在用户态从新程序入口继续执行（返回用户态时并不返回 exec 的系统调用，只有失败时才返回错误代码）。
- `wait`：用户进程调用 `wait`/`waitpid`，陷入内核；内核检查子进程表项，若子进程还没终止则把父进程设置为睡眠（BLOCKED），并在子进程终止时被唤醒。内核在父进程返回时向父进程提供子进程退出状态。
- `exit`：用户进程调用 `exit` 系统调用，陷入内核；内核释放进程资源（关闭文件、释放内存或标记为可回收、记录退出码），将进程状态置为 `ZOMBIE` 并唤醒等待该子进程的父进程（若存在），最后调度其他进程运行。

2) 哪些操作在用户态完成，哪些在内核态完成

- 用户态完成的：
  - 发起系统调用的用户库函数（例如 C 库中的 `fork()`、`execve()`、`wait()`、`exit()`）——这些函数执行若干用户逻辑（参数准备、封装）并执行一条陷入指令（`ecall`）。
  - `exec` 前后的用户态局部准备（构造参数字符串、环境指针等）。

- 内核态完成的：
  - `fork`：分配进程表项、复制进程描述符、内核态页表复制或写时复制处理、初始化子进程 PCB/上下文、设置返回值等。
  - `exec`：打开并读取可执行文件、解析 ELF，分配新的用户虚拟空间/页表、建立用户栈与参数、设置 `pc`/`sp`，并卸载原进程的用户内存结构。
  - `wait`：检查子进程状态表、把父进程阻塞在等待队列、在子进程退出时收集退出状态并返回给父进程。
  - `exit`：释放/标记用户资源、记录退出码、唤醒父进程或把自己标记为僵尸、执行调度切换。

3) 内核态与用户态如何交错执行（同步/异步机制）

- 同步交错（常见于 `fork`、`exec` 的请求—响应流程）：用户态发起 `ecall`，CPU 进入内核态并执行系统调用处理逻辑，系统调用完成后通过修改返回寄存器并执行 `sret`/`mret` 等返回指令恢复用户态执行。也就是说：用户态 -> 内核态（运行系统调用）-> 用户态（返回值可见）。
- 异步交错（常见于 `wait` / `exit` 的进程调度、阻塞/唤醒）：父进程调用 `wait` 并在内核态被阻塞（睡眠、切换至其他进程），子进程执行 `exit` 进入内核态并设置子状态、唤醒父进程；被唤醒的父进程在内核态继续检查并返回结果，然后恢复用户态继续执行。

4) 内核态执行结果如何返回给用户程序

- 返回值通常通过约定的寄存器（例如 `a0`/`a1` 等）传递：内核在系统调用完成前设置返回寄存器并在返回到用户态时使 CPU 执行返回指令（如 `sret` 或 `mret`），用户态继续执行，用户代码从库函数返回并读取寄存器中的返回值。
- 若系统调用在内核中导致阻塞（如 `wait`），内核会在阻塞结束时（被唤醒后）再次运行父进程的系统调用后续逻辑，最终通过寄存器/用户栈返回值并返回用户态。

5) ucore 中用户态进程的执行状态生命周期图（字符画）

下面是一个简洁的文本状态图，包含典型状态与触发事件/函数：

```
                            +-----------------+
                            |      NEW        |
                            | create/alloc PCB|
                            +--------+--------+
                                        |
                                        | fork()/create
                                        v
 +-----------+   schedule   +-------+   ecall/syscall    +-----------+
 | RUNNABLE  |<------------|RUNNING|------------------->| IN KERNEL |
 | (ready)   |             |(on CPU)|<--return (sret)---| (syscall) |
 +-----+-----+             +---+---+                    +-----+-----+
         | schedule                |                                |
         | (dispatcher)            | blocking syscalls / sleep      |
         v                        v                                v
    +---+---+                +---+---+                        +---+---+
    |RUNNING|--------------->|SLEEPING|<---wakeup/event-------| ZOMBIE|
    |(user)|  blocking I/O   |(blocked)|                       |(exited)|
    +---+---+                +---+---+                        +---+---+
         |                        |  ^                             |
         | exit()/kill            |  | interrupt/wakeup             | parent wait()
         v                        |  |                             v
    +---+---+                    |  +--------------------------> REAPED
    | ZOMBIE|--------------------+                                (removed)
    +-------+
```

说明：
- `RUNNABLE` → `RUNNING`：由调度器（`schedule`）选中进入 CPU。
- `RUNNING` → `IN KERNEL`：执行 syscall/异常（`ecall`），进入内核态处理（`fork`/`exec`/`wait`/`exit` 等）。内核处理完成后通过 `sret/mret` 返回用户态（回到 `RUNNING` 或 `RUNNABLE`）。
- `RUNNING` → `SLEEPING`：执行阻塞系统调用（如等待 I/O、`wait` 等）或主动睡眠。被等待事件发生时由内核 `wakeup` 唤醒，转为 `RUNNABLE`。
- `RUNNING` → `ZOMBIE`：调用 `exit()` 或被终止后，内核保留部分信息，变为僵尸。
- `ZOMBIE` → `REAPED`：父进程调用 `wait()` 收集退出码并清理资源，进程最终被移除。

6) 总结

- `fork/exec/wait/exit` 的调用在用户态由库函数发起，但核心资源管理与页表/内存/进程表修改都在内核态执行。
- 内核通过陷入（`ecall`）进入内核态，完成系统调用逻辑，然后通过返回指令与寄存器约定把结果交还给用户态。
- `wait`/`exit` 展示了内核与用户态的异步交错（阻塞/唤醒、调度），以及内核如何在进程间同步状态。

