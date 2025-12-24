**调度类与框架分析（Lab6）**

- 目标：基于 lab6 代码，解析调度类 `sched_class` 的接口与调用时机，比较 lab5/lab6 在运行队列设计上的差异，说明框架函数的解耦方式、初始化与调度全流程，并分析如何无痛切换或新增调度算法（如 stride）。

**核心代码位置**
- 调度框架与接口：[lab6/kern/schedule/sched.h](lab6/kern/schedule/sched.h)，[lab6/kern/schedule/sched.c](lab6/kern/schedule/sched.c)
- 默认 RR 调度类声明/定义：[lab6/kern/schedule/default_sched.h](lab6/kern/schedule/default_sched.h)，[lab6/kern/schedule/default_sched.c](lab6/kern/schedule/default_sched.c)
- Stride 调度类（挑战）：[lab6/kern/schedule/default_sched_stride.c](lab6/kern/schedule/default_sched_stride.c)
- 时钟与中断路径：[lab6/kern/driver/clock.c](lab6/kern/driver/clock.c)，[lab6/kern/trap/trap.c](lab6/kern/trap/trap.c)
- 进程与切换：[lab6/kern/process/proc.c](lab6/kern/process/proc.c)
- 斜堆结构：[lab6/libs/skew_heap.h](lab6/libs/skew_heap.h)

**sched_class 结构体分析**
- `name`: 调度类名称，仅用于可读性和日志输出（见 sched_init 打印）。
- `init(rq)`: 初始化运行队列 `run_queue` 的内部结构与元数据（如清空队列、`proc_num=0`、准备堆或链表）。在内核初始化阶段由框架调用，用于让算法自定义其队列组织形式。
- `enqueue(rq, proc)`: 将可运行进程加入运行队列（需设置 `proc->time_slice`、`proc->rq`、并按算法策略入队）。在被唤醒、让出 CPU 后保持就绪、或当前进程仍 RUNNABLE 且需要重新排队时调用。
- `dequeue(rq, proc)`: 将指定进程从运行队列移除。典型在 `schedule()` 选出 `next` 后，从队列删除此进程以便切换运行。
- `pick_next(rq)`: 选择下一个要运行的进程。RR 通常取队首；Stride 取最小 `stride` 的进程（优先队列/斜堆）。
- `proc_tick(rq, proc)`: 时钟滴答处理。主要扣减时间片并在用尽时置位 `proc->need_resched=1` 触发调度；如 Stride 会结合配额推进 `stride`。
- 采用函数指针的原因：
	- 解耦框架与策略：调度框架只依赖统一接口，算法独立在各自模块实现，便于插拔与切换。
	- 复用与扩展：新增算法仅需实现同样签名的一组函数并注册为 `struct sched_class`，无须改动框架逻辑。
	- 运行期选择/编译期切换都容易：只需切换 `sched_class` 指针指向不同实现。

**run_queue 结构体对比（lab5 vs lab6）**
- lab5：没有独立的 `run_queue` 结构。调度器直接遍历全局进程链表 `proc_list` 选择下一个 RUNNABLE（见 [lab5/kern/schedule/sched.c](lab5/kern/schedule/sched.c)）。特点是简单，但耦合、不可扩展，不利于支持多种策略或高效数据结构。
- lab6：引入 `struct run_queue`（见 [lab6/kern/schedule/sched.h](lab6/kern/schedule/sched.h)）：
	- `run_list`: 链表头，适用于 RR 等 FIFO 策略。
	- `proc_num`: 当前就绪进程计数。
	- `max_time_slice`: 框架层给出的统一时间片基准（如 5）。
	- `lab6_run_pool`: 指向斜堆根节点（`skew_heap_entry_t*`），适用于基于优先级/stride 的最小堆选择。
- 为什么需要同时支持链表和斜堆：
	- RR 的核心操作是队尾入队、队首出队，链表即可 O(1) 完成。
	- Stride/多级反馈队列等需要按“最小键”选取下一个进程，优先队列（如斜堆）能以 O(logN) 插入/删除、O(1) 取最小。
	- 将二者并置在统一的 `run_queue`，使调度类可按需选择底层结构，同时复用框架层的数据（如 `max_time_slice`、`proc_num`）。

**调度器框架函数的解耦分析**
- `sched_init()`（见 [lab6/kern/schedule/sched.c](lab6/kern/schedule/sched.c)）
	- 初始化定时器链表；设置全局 `sched_class = &default_sched_class`（RR）；
	- 初始化全局运行队列 `rq` 并设置 `rq->max_time_slice = MAX_TIME_SLICE`；
	- 调用 `sched_class->init(rq)`，由具体算法初始化 `run_queue`。
- `wakeup_proc(proc)`（同文件）
	- 将目标进程置为 `PROC_RUNNABLE` 并清除 `wait_state`；
	- 若不是当前进程，则调用 `sched_class_enqueue(proc)` 将其按算法入队（RR 入链表，Stride 入斜堆）。
	- 框架不关心底层结构，完全由调度类处理。
- `schedule()`（同文件）
	- 清 `current->need_resched`；若 `current` 仍 `PROC_RUNNABLE`，则 `enqueue` 回就绪队列；
	- 通过 `pick_next()` 选择 `next`，并对其 `dequeue()`；若无就绪则选 `idleproc`；
	- 若 `next != current`，则 `proc_run(next)` 触发上下文切换。
- 小结：框架仅在“何时入队/出队/选择”上做调度时机管理，把“如何组织队列、如何选取进程”交给调度类。因而不同算法可共用同一套框架时序。

**调度类的初始化流程**
- 启动路径（见 [lab6/kern/init/init.c](lab6/kern/init/init.c)）：
	- `kern_init` 依次完成：控制台 → 内存管理 → 中断控制器/IDT → 虚存 → `sched_init()` → `proc_init()` → `clock_init()` → 开中断 `intr_enable()` → `cpu_idle()`。
	- 在 `sched_init()` 中绑定 `sched_class=&default_sched_class` 并调用其 `init(rq)`。随后 `proc_init()` 创建 `idleproc`/`initproc`，`clock_init()` 开启时钟中断。
	- 如需切换算法，只需调整 `sched_class` 指针（例如指向 `stride_sched_class`）。

**进程调度流程与 need_resched**
- 滴答与触发（见 [lab6/kern/trap/trap.c](lab6/kern/trap/trap.c)、[lab6/kern/driver/clock.c](lab6/kern/driver/clock.c)）：
	- 发生 `IRQ_S_TIMER`：设置下次时钟事件 `clock_set_next_event()`，维护 `ticks` 计数；
	- 调用 `sched_class_proc_tick(current)`：
		- RR：`time_slice--`，若归零则置位 `current->need_resched=1`；
		- Stride：在时间片/配额基础上推进 `lab6_stride`，并在合适时机置位 `need_resched`；
	- 返回异常路径 `trap()`，若当前在用户态且 `current->need_resched` 为 1，则调用 `schedule()`。
- `schedule()` 执行序（见上）：
	- 如 `current` 仍可运行则 `enqueue` 回队列；
	- `pick_next()` 选择 `next`，`dequeue(next)`；若无就绪进程则 `next=idleproc`；
	- 切换到 `next`。
- `need_resched` 的作用：
	- 表示“需要尽快进行一次调度”的请求位，由 `proc_tick` 或 `sys_yield` 等路径设置（见 [lab6/kern/process/proc.c](lab6/kern/process/proc.c) 的 `do_yield`）。
	- 在返回用户态前的 `trap()`、以及 `cpu_idle()` 自旋中被检查，一旦为 1 即进入 `schedule()`。

**进程调度流程图（时钟中断→RR/Stride→切换）**

```
[Timer IRQ]
		↓
[interrupt_handler (IRQ_S_TIMER)] —→ clock_set_next_event(), ticks++
		↓
[sched_class_proc_tick(current)]
		↓ (若 time_slice 用尽或策略需要)
 [set current.need_resched = 1]
		↓
[trap() 尾声 / 用户态返回前检查]
		├─ need_resched==0 → 继续当前进程
		└─ need_resched==1 → 调用 schedule()
													↓
							[current RUNNABLE? → enqueue(current)]
													↓
								[next = pick_next(rq)]
													↓
								[dequeue(next)；若空则 idleproc]
													↓
											[proc_run(next)]
```

**调度算法的切换机制（以新增 stride 为例）**
- 新增内容：
	- 在 [lab6/kern/schedule/default_sched_stride.c](lab6/kern/schedule/default_sched_stride.c) 中补全：
		- `BIG_STRIDE` 常量；
		- `stride_init/enqueue/dequeue/pick_next/proc_tick`；
		- 使用 `proc->lab6_priority`、`proc->lab6_stride` 与 `rq->lab6_run_pool`（斜堆）管理就绪队列，比较函数参见文件内 `proc_stride_comp_f` 与 [lab6/libs/skew_heap.h](lab6/libs/skew_heap.h)。
	- 在 [lab6/kern/schedule/default_sched.h](lab6/kern/schedule/default_sched.h) 已声明 `extern struct sched_class stride_sched_class;`，可直接引用。
- 切换方式：
	- 在框架的 `sched_init()` 中，将 `sched_class = &stride_sched_class;` 即可切换（或通过编译选项/宏控制）。
	- 其余 `wakeup_proc/schedule/proc_tick` 的时序与入口保持不变，真正的入队/选取/出队逻辑由 stride 的实现接管。
- 设计优势：
	- 调度器仅持有 `sched_class*` 与 `run_queue`，算法切换为“指针切换”，无需改动框架；
	- `run_queue` 同时支持链表与斜堆，避免为不同算法改动数据结构定义；
	- 算法模块间互不影响，便于独立开发与测试。

**小结**
- lab6 将“调度时序控制”（框架）与“调度策略实现”（类）清晰分离：框架定义何时入队/出队/选取/调度，策略决定如何组织队列与选择进程。
- `run_queue` 统一承载链表与斜堆两类结构，兼容 RR 与 Stride 等算法需求。
- 算法切换只需更改一个全局指针的绑定即可完成，极大降低了扩展成本。

**跨 Lab 差异函数对比与动因**
- 选择对比：`schedule()` 和 `wakeup_proc()`
	- lab5 的 `schedule()`（见 [lab5/kern/schedule/sched.c](lab5/kern/schedule/sched.c)）直接遍历全局 `proc_list` 查找一个 `PROC_RUNNABLE` 进程；未维护独立就绪队列，不区分算法策略。
	- lab6 的 `schedule()`（见 [lab6/kern/schedule/sched.c](lab6/kern/schedule/sched.c)）改为：
		- 当前进程若仍 RUNNABLE 则通过 `sched_class->enqueue()` 回队；
		- 使用 `sched_class->pick_next()` 选择下一个；再 `dequeue(next)`；
		- 框架不再关心“如何选”，而只负责“何时入/出队与切换”。
	- 不做此改动的后果：
		- 无法引入 RR/Stride 等不同策略；
		- 时钟驱动下的时间片用尽也无法将当前进程移动到队尾，失去 RR 的公平轮转；
		- 性能上无法使用更高效的结构（如斜堆），次优的全表遍历会放大调度开销。
	- `wakeup_proc()` 同理：lab5 仅设置状态；lab6 在置 RUNNABLE 后（且非当前进程）通过 `sched_class_enqueue()` 将进程按策略加入队列，保证被唤醒的进程参与后续调度。

**RR 各函数实现说明与关键点**
- 参考文件：[lab6/kern/schedule/default_sched.c](lab6/kern/schedule/default_sched.c)
- `RR_init(rq)`：
	- 操作：`list_init(&rq->run_list)` 初始化空表；`rq->proc_num=0`；`rq->lab6_run_pool=NULL`（RR 不用斜堆）。
	- 理由：RR 使用 FIFO 语义，双向循环链表最简单高效。
- `RR_enqueue(rq, proc)`：
	- 操作：
		- 时间片：`proc->time_slice` 若未设或已耗尽，重置为 `rq->max_time_slice`；
		- 关联队列：`proc->rq = rq`；
		- 入队：`list_add_before(&rq->run_list, &proc->run_link)` 插入队尾（表头前即队尾）；
		- 统计：`rq->proc_num++`。
	- 链表选择：`list_add_before(head, node)` 等价于 push 到尾部，满足 RR 的“先进先出”。
	- 边界：重复入队场景由调用方约束（例如只对 RUNNABLE 未在队列中的进程入队）。
- `RR_dequeue(rq, proc)`：
	- 操作：`list_del_init(&proc->run_link)` 从队列移除并重置指针，`proc_num--`（非负保护）。
	- 边界：当 `proc_num` 已为 0 时不再减负，避免下溢；`list_del_init` 防止“野链表”悬挂。
- `RR_pick_next(rq)`：
	- 操作：若 `list_empty(&rq->run_list)` 返回 NULL；否则取 `list_next(&rq->run_list)` 为队首并转换为 `struct proc_struct`。
	- 设计：仅选择，不在此处删除；由框架统一 `dequeue(next)`，便于解耦。
- `RR_proc_tick(rq, proc)`：
	- 操作：若 `time_slice>0` 则自减；为 0 时置 `proc->need_resched=1`。
	- 理由：`need_resched` 是跨路径的“调度请求位”，在 trap 返回用户态前或 idle 循环中被检查，触发 `schedule()`。

**make grade 与 QEMU 观测**
- 构建与运行
	- 基本命令：
		```bash
		cd lab6
		make clean && make
		make qemu  # 或 make grade
		```
	- 本仓库当前 lab6 仍有上游 Lab4/5 的未完成项（如 [lab6/kern/process/proc.c](lab6/kern/process/proc.c) 中 `alloc_proc/proc_run/do_fork` 等 TODO），导致 `make grade` 无法通过（无法启动用户程序 `priority`）。错误示例：
		- 缺失 `kernel_execve: pid = 2, name = "priority".` 等输出；
		- 缺失 `++ setup timer interrupts`（说明系统未进入 `clock_init` 正常路径）。
	- 待补齐上述 TODO 后，重新运行 `make grade` 可看到：
		- 启动日志（包括 `++ setup timer interrupts`）。
		- priority 程序相关的输出，以及“100 ticks”周期打印。
- QEMU 中的 RR 行为预期
	- 多个就绪进程将轮流获得 CPU；每当 `time_slice` 耗尽，当前进程被移至队尾，并置位 `need_resched`；
	- 周期性的 `100 ticks` 打印表明时钟中断在运行，RR 的时间片消耗在起作用；
	- 进程的 `runs` 计数在 [lab6/kern/schedule/sched.c](lab6/kern/schedule/sched.c) 的 `schedule()` 中累加，可辅助观测切换频度。

**RR 优缺点与时间片调优**
- 优点：实现简单；公平性强；避免单进程长期占用 CPU。
- 缺点：忽略进程差异（I/O 密集 vs 计算密集、优先级需求）；时间片设置不当会影响吞吐与响应：
	- 时间片过短：切换开销上升，CPU 时间浪费在上下文切换；
	- 时间片过长：交互响应变差，I/O 密集任务等待时间增长。
- 调优建议：
	- 基于任务性质（交互/批处理）与平台开销（上下文切换时延）设置基准时间片；
	- 可按进程类型（前台/后台）或动态反馈（如 MLFQ）调整时间片。
- 为什么在 `RR_proc_tick` 设置 `need_resched`：
	- 它是跨越中断与系统调用路径的“异步调度请求”，避免在中断上下文直接调用 `schedule()`；
	- 由 `trap()` 返回用户态前（见 [lab6/kern/trap/trap.c](lab6/kern/trap/trap.c)）或 `cpu_idle()` 循环检查并触发调度，确保上下文安全、路径一致。

**拓展：优先级 RR 与多核**
- 优先级 RR（Priority RR）设计思路：
	- 在 `run_queue` 中为不同优先级维护多条 FIFO 队列，`pick_next` 选择最高优先级非空队列的队首；同优先级内仍为 RR；
	- 变更点：
		- 数据结构：可使用数组/桶（优先级范围固定）或有序结构；
		- `enqueue/dequeue/pick_next`：按优先级维度定位队列，再执行对应的链表操作；
		- 可重用 `proc->lab6_priority` 作为优先级输入。
- 多核调度支持（当前实现为单核）：
	- 需要每核 `run_queue` 与自旋锁（或禁中断）保护，避免并发竞争；
	- `sched_class` 可扩展 `load_balance/get_proc`（在 [lab6/kern/schedule/sched.h](lab6/kern/schedule/sched.h) 已预留注释）做跨核均衡；
	- `wakeup_proc` 在目标核选择上需要 `select_cpu` 策略；必要时通过 IPI 触发目标核调度；
	- `current/idleproc`、`rq` 等改为 per-CPU 变量，`schedule()` 变为每核独立运行的调度循环。

**已实现与提交说明**
- RR 实现：见 [lab6/kern/schedule/default_sched.c](lab6/kern/schedule/default_sched.c)
- 时钟调度钩子：在 [lab6/kern/trap/trap.c](lab6/kern/trap/trap.c) 的 `IRQ_S_TIMER` 分支中：设置下次事件、维护 `ticks`、每 100 次打印、调用 `sched_class_proc_tick(current)`。
- 编译辅助：为避免链接失败，补全了 [lab6/kern/schedule/default_sched_stride.c](lab6/kern/schedule/default_sched_stride.c) 的最小实现（虽默认不启用 stride，但该文件会被编译）。


