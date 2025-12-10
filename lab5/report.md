# Lab 5 扩展练习：Copy on Write (COW) 实现报告

## 1. 实现源码

COW 机制的实现主要涉及内存管理部分，具体修改了 `kern/mm/mmu.h`, `kern/mm/vmm.c`, `kern/mm/pmm.c` 以及 `kern/process/proc.c`。

### 1.1 定义 COW 标志位
在 `kern/mm/mmu.h` 中，利用 RISC-V 页表项的保留位（RSW，第8-9位）定义 `PTE_COW`。

```c
// kern/mm/mmu.h
#define PTE_COW 0x100  // Copy On Write (利用 RSW 位)
```

### 1.2 启用共享映射 (`dup_mmap`)
在 `kern/mm/vmm.c` 中，修改 `dup_mmap` 函数。当进程 fork 时，`copy_mm` 会调用此函数。我们将 `share` 参数设置为 `1`，表示尝试共享页面而不是直接复制。

```c
// kern/mm/vmm.c - dup_mmap
int dup_mmap(struct mm_struct *to, struct mm_struct *from) {
    // ... 遍历 vma ...
    bool share = 1; // 启用共享
    if (copy_range(to->pgdir, from->pgdir, vma->vm_start, vma->vm_end, share) != 0) {
        return -E_NO_MEM;
    }
    // ...
}
```

### 1.3 修改内存复制逻辑 (`copy_range`)
在 `kern/mm/pmm.c` 中，`copy_range` 函数负责具体的页表复制。当 `share=1` 时，我们不再分配新页，而是让父子进程共享物理页，并设置为只读 + COW。

```c
// kern/mm/pmm.c - copy_range
if (share) {
    // 共享模式：
    // 1. 将子进程的 PTE 指向父进程的物理页
    // 2. 权限设置为：移除写权限 (PTE_W)，添加 COW 标志 (PTE_COW)
    ret = page_insert(to, page, start, (perm & ~PTE_W) | PTE_COW);
    
    // 3. 更新父进程的 PTE：同样移除写权限，添加 COW 标志
    // 注意：这里直接修改了父进程的页表项，需要刷新 TLB
    *ptep = (*ptep & ~PTE_W) | PTE_COW;
    tlb_invalidate(from, start);
} else {
    // 原有的深拷贝逻辑 (share=0)
    // ... alloc_page, memcpy, page_insert ...
}
```

### 1.4 实现 COW 缺页处理 (`do_pgfault`)
在 `kern/mm/vmm.c` 的 `do_pgfault` 中，增加对 `CAUSE_STORE_PAGE_FAULT` 的处理逻辑。

```c
// kern/mm/vmm.c - do_pgfault
// 检查是否是写异常且页表项包含 COW 标志
if (error_code == CAUSE_STORE_PAGE_FAULT && (*ptep & PTE_COW)) {
    struct Page *page = pte2page(*ptep);
    
    // 情况 1: 引用计数为 1
    // 说明当前物理页只有当前进程在使用（其他进程可能已经 COW 分离了，或者进程已退出）
    // 此时不需要复制，直接恢复写权限即可
    if (page->ref == 1) {
            *ptep = (*ptep & ~PTE_COW) | PTE_W;
            tlb_invalidate(mm->pgdir, addr);
            return 0;
    }

    // 情况 2: 引用计数 > 1
    // 说明有多个进程共享此页，必须进行复制
    struct Page *npage = alloc_page();
    if (npage == NULL) {
        return -E_NO_MEM;
    }
    
    // 复制页面内容
    memcpy(page2kva(npage), page2kva(page), PGSIZE);
    
    // 建立新映射：
    // 使用原有的权限（PTE_USER），加上写权限（PTE_W），去掉 COW 标志
    uint32_t perm = (*ptep & PTE_USER) | PTE_W;
    perm &= ~PTE_COW;
    
    // page_insert 会自动处理引用计数：
    // 1. 增加 npage 的引用计数
    // 2. 减少原 page 的引用计数（因为当前 PTE 不再指向它）
    if (page_insert(mm->pgdir, npage, addr, perm) != 0) {
        free_page(npage);
        return -E_NO_MEM;
    }
    return 0;
}
```

## 2. 测试用例

创建了用户态测试程序 `user/cowtest.c`。

```c
#include <stdio.h>
#include <ulib.h>
#include <string.h>

int main(void) {
    int pid;
    volatile int value = 100;
    
    cprintf("COW Test: Parent before fork, value = %d\n", value);

    pid = fork();

    if (pid == 0) {
        // 子进程
        cprintf("COW Test: Child before write, value = %d\n", value);
        // 此时读取应该正常，且物理地址与父进程相同（只读共享）
        
        cprintf("COW Test: Child writing to value...\n");
        value = 200; // 触发写异常 -> COW -> 分配新页 -> 修改值
        
        cprintf("COW Test: Child after write, value = %d\n", value);
        if (value != 200) exit(-1);
        cprintf("COW Test: Child exiting.\n");
        exit(0);
    } else {
        // 父进程
        wait();
        // 子进程修改后，父进程的值应保持不变
        cprintf("COW Test: Parent after child exit, value = %d\n", value);
        if (value != 100) {
             cprintf("COW Test: Parent value changed! COW failed isolation.\n");
             exit(-1);
        }
        cprintf("COW Test: Parent value correct. COW Test Passed.\n");
    }
    return 0;
}
```

**测试结果说明**：
1.  父进程初始化变量 `value = 100`。
2.  `fork()` 后，父子进程共享同一物理页，PTE 均为 `Read-only | COW`。
3.  子进程读取 `value`，成功（读权限存在）。
4.  子进程写入 `value = 200`，触发 `Store Page Fault`。
5.  内核捕获异常，发现 `PTE_COW`，执行页面复制，将子进程虚拟地址映射到新物理页，并设置为 `Read/Write`。
6.  子进程写入成功，`value` 变为 200。
7.  父进程读取 `value`，由于父进程的页表未变（或引用计数减为1后恢复写权限），其物理页内容仍为 100。

## 3. 设计报告：COW 状态转换说明

我们可以将物理页面的状态看作一个有限状态机（FSM），其状态主要由 **引用计数 (ref)** 和 **页表项标志 (PTE flags)** 决定。

### 状态定义
1.  **Exclusive (独占)**:
    *   `page->ref == 1`
    *   PTE: `PTE_W` (可写), 无 `PTE_COW`。
    *   这是普通分配页面的初始状态。

2.  **Shared (共享/COW)**:
    *   `page->ref > 1`
    *   PTE: 无 `PTE_W` (只读), 有 `PTE_COW`。
    *   这是 `fork` 之后的状态。

3.  **Shared-Last (共享-最后)**:
    *   `page->ref == 1`
    *   PTE: 无 `PTE_W` (只读), 有 `PTE_COW`。
    *   这是当其他共享进程都已 COW 分离或退出，只剩最后一个进程持有该页时的状态。

### 状态转换图

```mermaid
graph TD
    A[Exclusive (Ref=1, W)] -->|Fork| B[Shared (Ref=2, R, COW)]
    B -->|Fork| B2[Shared (Ref++, R, COW)]
    
    B -->|Read| B
    
    B -->|Write (Trigger Page Fault)| C{Ref > 1?}
    C -->|Yes| D[Alloc New Page]
    D --> E[New Page: Exclusive (Ref=1, W)]
    D --> F[Old Page: Ref--]
    
    F -->|Ref > 1| B
    F -->|Ref == 1| G[Shared-Last (Ref=1, R, COW)]
    
    G -->|Write (Trigger Page Fault)| H[Restore Write Perm]
    H --> A
```

### 详细转换说明

1.  **Fork (Exclusive -> Shared)**:
    *   父进程调用 `fork`。
    *   遍历页表，对于 `Exclusive` 的页面，将其 PTE 改为只读并添加 COW 标志。
    *   子进程复制该 PTE。
    *   物理页引用计数 `ref++`。
    *   父子进程现在都处于 `Shared` 状态。

2.  **Write on Shared (Ref > 1)**:
    *   进程尝试写入 `Shared` 页面。
    *   触发缺页异常。
    *   内核检测到 `ref > 1`。
    *   **Action**: 分配新物理页，拷贝内容。
    *   **Current Process**: 更新 PTE 指向新页，设置 `PTE_W`，移除 `PTE_COW`。当前进程持有的新页变为 `Exclusive` 状态。
    *   **Original Page**: 引用计数 `ref--`。如果 `ref` 降为 1，该页对于剩余的那个进程变为 `Shared-Last` 状态（虽然 PTE 里还有 COW 标志，但物理上已独占）。

3.  **Write on Shared-Last (Ref == 1)**:
    *   进程尝试写入 `Shared-Last` 页面（即 PTE 仍标记为 COW，但物理页 `ref=1`）。
    *   触发缺页异常。
    *   内核检测到 `ref == 1`。
    *   **Action**: 不分配新页。
    *   **Current Process**: 直接修改 PTE，恢复 `PTE_W`，移除 `PTE_COW`。
    *   状态变回 `Exclusive`。

## 4. Dirty COW (CVE-2016-5195) 分析与模拟

### 4.1 Dirty COW 原理
Dirty COW 是 Linux 内核中的一个竞态条件漏洞。它利用了 Copy-on-Write 机制中的一个缺陷：
1.  线程 A 尝试写入一个只读的 COW 页面（例如映射的只读文件）。
2.  内核开始处理缺页中断，准备复制页面。
3.  线程 B 同时调用 `madvise(MADV_DONTNEED)`，告诉内核丢弃该页面的映射。
4.  由于竞态，内核可能在线程 B 丢弃映射后，错误地将写操作应用到了**原始的只读页面**（即文件缓存页）上，而不是新复制的页面上。
5.  结果是用户修改了本该只读的文件内容（如 `/etc/passwd`），导致提权。

### 4.2 在 ucore 中模拟的可能性
在目前的 ucore 实验环境中，**很难直接复现** Dirty COW 漏洞，原因如下：
1.  **缺乏多线程/SMP 支持**：目前的 ucore 实验主要运行在单核模式下，且内核是非抢占的（或者抢占点非常有限）。处理缺页异常 (`do_pgfault`) 的过程通常是原子执行的，不会被另一个用户线程打断去执行类似 `madvise` 的操作。
2.  **缺乏 `madvise` 系统调用**：ucore 没有提供内存建议的系统调用来主动丢弃页面映射。

### 4.3 假设环境下的模拟与解决方案
如果 ucore 支持多核 (SMP) 并且允许内核抢占，那么潜在的风险点在于 `do_pgfault` 中的“检查-复制-映射”序列是否是原子的。

**模拟思路**：
假设我们有两个线程 T1 和 T2。
*   T1 执行写操作触发 COW。
*   T2 执行一个自定义的系统调用 `sys_discard_map(addr)`（模拟 `madvise`）。

**代码逻辑漏洞 (伪代码)**：
```c
// do_pgfault
if (is_cow) {
    new_page = alloc_page();
    copy_page(old_page, new_page);
    // <--- 此时发生上下文切换，T2 运行 sys_discard_map，清空了 PTE --->
    // T1 恢复运行
    page_insert(mm->pgdir, new_page, addr, perm); // 重新建立了映射
}
```
在 Linux 的 Dirty COW 中，问题更复杂，涉及到 `get_user_pages` 的重试机制。但在 ucore 中，如果 `page_insert` 仅仅是更新页表，风险相对较小，因为我们操作的是私有内存（Anonymous Memory）。Dirty COW 的威力在于修改了**文件映射**（File-backed mapping）。

**ucore 的安全性**：
目前 ucore 的 COW 实现针对的是匿名内存（堆/栈/数据段），即使发生竞态，最坏的结果是破坏了进程自身的内存一致性，而不会像 Linux 那样修改了磁盘上的只读文件（因为 ucore 的 `fork` COW 不涉及文件缓存页的写回）。

**解决方案**：
为了防止此类竞态，必须确保在处理 COW 缺页异常时，对相关页表项或内存区域（VMA）加锁。
1.  **页表锁 (Page Table Lock)**: 在修改 PTE 之前获取锁，确保没有其他线程能同时修改该 PTE。
2.  **引用计数检查的原子性**: 确保 `page->ref` 的读取和后续操作是原子的，或者在锁保护下进行。

在 ucore 当前实现中，由于 `do_pgfault` 是在内核态串行执行的（对于同一进程），且没有其他机制并发修改页表，因此是安全的。
