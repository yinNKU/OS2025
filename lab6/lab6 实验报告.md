## lab6 实验报告

### 练习1: 理解调度器框架的实现（不需要编码）
本节结合 lab6 实际代码（sched.c / trap.c / init.c / default_sched.c）说明调度类的初始化流程、一次完整的调度执行路径，以及调度算法的切换机制。

#### 1) 调度类的初始化流程（从内核启动到 sched_init 完成）

内核启动阶段在 `kern/init/init.c:kern_init()` 中完成一系列子系统初始化，其中与调度器相关的调用顺序为：

1. `sched_init()`：初始化调度器框架并绑定一个具体的调度类（sched_class）。
2. `proc_init()`：创建 idle 进程、init 进程等，并设置 `current = idleproc`。
3. `clock_init()` + `intr_enable()`：打开时钟中断，为抢占式调度提供触发源。
4. `cpu_idle()`：idle 线程循环检查 `need_resched`，必要时进入 `schedule()` 进行进程切换。

`sched_init()` 的关键逻辑在 `kern/schedule/sched.c`：

- `sched_class = &default_sched_class;`
    - 这里把全局指针 `sched_class` 直接指向某个具体调度类对象（Round Robin 的 `default_sched_class`）。
    - `default_sched_class` 定义在 `kern/schedule/default_sched.c` 中，它把 `.init/.enqueue/.dequeue/.pick_next/.proc_tick` 五个函数指针分别绑定到 RR 的实现（RR_init/RR_enqueue/...）。
    - `sched.c` 通过 `#include <default_sched.h>` 引入 `extern struct sched_class default_sched_class;`，从而把“框架”和“具体算法实现”关联起来。

- 初始化 run_queue：
    - `rq = &__rq; rq->max_time_slice = MAX_TIME_SLICE;`
    - `sched_class->init(rq);`：通过函数指针调用 RR_init，对 `rq->run_list`、`rq->proc_num` 等进行初始化。

总结：调度器框架的核心是 `sched_class` 这组函数指针。内核启动时只需要在 `sched_init()` 里把 `sched_class` 指向某个实现（如 `default_sched_class`），后续所有“入队/出队/选取/时钟 tick”都通过 `sched_class->xxx()` 间接调用对应算法。

#### 2) 进程调度流程（时钟中断触发 → proc_tick → schedule 调用链）

下面给出一次“时间片耗尽导致的抢占式调度”的完整流程图（以 RR 为例）。

```mermaid
flowchart TD
        A[时钟中断 IRQ_S_TIMER] --> B[trap_dispatch -> interrupt_handler]
        B --> C[clock_set_next_event(); ticks++]
        C --> D{current != NULL 且 current->rq != NULL ?}
        D -- 是 --> E[sched_class_proc_tick(current)]
        E --> F[sched_class->proc_tick(rq, current)
                        例如 RR_proc_tick]
        F --> G{time_slice 是否减到 0 ?}
        G -- 是 --> H[current->need_resched = 1]
        G -- 否 --> I[返回]
        H --> J[trap() 收尾阶段]
        I --> J
        J --> K{是否从用户态陷入? (!in_kernel)}
        K -- 是且 need_resched=1 --> L[schedule()]
        K -- 否 --> M[从中断/异常返回]

        L --> N[current->need_resched = 0]
        N --> O{current->state == PROC_RUNNABLE ?}
        O -- 是 --> P[sched_class->enqueue(rq, current)
                                 例如 RR_enqueue]
        O -- 否 --> Q[跳过入队]
        P --> R[next = sched_class->pick_next(rq)
                        例如 RR_pick_next]
        Q --> R
        R --> S{next != NULL ?}
        S -- 是 --> T[sched_class->dequeue(rq, next)
                                 例如 RR_dequeue]
        S -- 否 --> U[next = idleproc]
        T --> V[proc_run(next) 发生切换]
        U --> V
```

补充两点与代码细节一致的说明：

- `sched_class_proc_tick(current)` 的调用点在 `kern/trap/trap.c:interrupt_handler()` 的 `IRQ_S_TIMER` 分支中：每次时钟中断都会先设置下一次时钟事件、增加 tick 计数，然后调用 `sched_class_proc_tick`。

- `schedule()` 的调用点在 `kern/trap/trap.c:trap()`：在 `trap_dispatch(tf)` 处理完中断/异常后，如果本次陷入不是内核态（`!in_kernel`），并且 `current->need_resched` 被置位，则调用 `schedule()`。
    - 对内核线程（如 idle 线程），调度也可以在 `proc.c:cpu_idle()` 中通过轮询 `need_resched` 触发：`if (current->need_resched) schedule();`。

**need_resched 标志位的作用**

- `need_resched` 是一个“延迟调度请求”标志：
    - 由调度算法在 `proc_tick` 中置位（如 RR/stride 在时间片用尽时置位），或由主动让出 CPU 的系统调用置位（如 `do_yield()` 把 `current->need_resched = 1`）。
- 置位并不立刻切换，而是在安全点统一检查并调用 `schedule()`：
    - 用户态陷入返回前的 `trap()` 末尾，或 idle 循环中。
- 在 `schedule()` 开头会清零 `current->need_resched = 0`，避免重复调度。

这种设计的优点是：调度决策与“真正执行上下文切换”的时机解耦，避免在任意代码路径/中断处理中间直接切换造成复杂的重入与一致性问题。

#### 3) 调度算法的切换机制（如何新增 stride，需要改哪些代码 & 为什么易切换）

以新增（或启用）stride 调度为例，通常需要改动/关注以下几类代码：

1. **实现一个新的 sched_class**
     - 新建或完善 `kern/schedule/default_sched_stride.c`（本实验中已提供），实现：
         - `stride_init / stride_enqueue / stride_dequeue / stride_pick_next / stride_proc_tick`
     - 并定义导出的调度类对象：
         - `struct sched_class stride_sched_class = { ... }`

2. **在头文件中暴露该调度类符号**
     - 通过头文件声明：`extern struct sched_class stride_sched_class;`
     - 当前 lab6 已在 `kern/schedule/default_sched.h` 中同时声明了 `default_sched_class` 与 `stride_sched_class`。

3. **在 sched_init 里选择要使用的调度类**
     - 修改 `kern/schedule/sched.c:sched_init()` 中的绑定语句：
         - 从 `sched_class = &default_sched_class;` 改为 `sched_class = &stride_sched_class;`
     - 更工程化的方式是用编译选项/宏进行切换，例如：

```c
// 伪代码示意
#ifdef USE_STRIDE
        sched_class = &stride_sched_class;
#else
        sched_class = &default_sched_class;
#endif
```

4. **保证新的算法文件参与编译链接**
     - 需要把新的 `.c` 文件加入构建系统（Makefile/CMakeLists）。
     - 当前 lab6 的 `CMakeLists.txt` 已包含 `kern/schedule/default_sched_stride.c`，说明 stride 调度器已经能被编译进内核。

5. **（可选/按算法需要）扩展数据结构**
     - 某些算法需要额外状态：例如 stride 需要 `proc_struct` 中的 `lab6_stride/lab6_priority` 等字段，并在 `run_queue` 中用 `lab6_run_pool` 维护可运行进程的优先队列（本实验的 `run_queue` 已预留该字段）。

**为什么当前设计使切换调度算法容易？**

- 调度框架的核心逻辑（`wakeup_proc()` / `schedule()` / `sched_class_proc_tick()`）只依赖 `struct sched_class` 定义的统一接口，不关心“队列如何组织、优先级如何比较、stride 如何更新”等策略细节。
- 因此切换算法时：
    - 只需替换 `sched_class` 指针指向的对象（或通过宏/配置选择），
    - 再确保新算法实现了同样的 5 个回调函数。
- 这种“策略（policy）与机制（mechanism）分离”的设计，使得调度算法可插拔、可扩展，修改范围集中且对框架侵入性小。


### 练习2: 实现 Round Robin 调度算法

`Round Robin` 调度算法的调度思想是让所有 runnable 态的进程分时轮流使用 CPU 时间。`Round Robin` 调度器维护当前 runnable 进程的有序运行队列。当前进程的时间片用完之后，调度器将当前进程放置到运行队列的尾部，再从其头部取出进程进行调度。

在这个理解的基础上，我们来分析算法的具体实现。 

这里 `Round Robin` 调度算法的主要实现在 `default_sched.c` 之中，源码如下：

```c
/*
  file_path = kern/schedule/default_sched.c
*/
//RR_init函数：这个函数被封装为 sched_init 函数，用于调度算法的初始化，使用grep命令可以知道，该函数仅在 ucore 入口的 init.c 里面被调用进行初始化
static void RR_init(struct run_queue *rq) { //初始化进程队列
    list_init(&(rq->run_list));//初始化运行队列
    rq->proc_num = 0;//初始化进程数为 0
}
//RR_enqueue函数：该函数的功能为将指定的进程的状态置成 RUNNABLE，并且放入调用算法中的可执行队列中，被封装成 sched_class_enqueue 函数，可以发现这个函数仅在 wakeup_proc 和 schedule 函数中被调用，前者为将某个不是 RUNNABLE 的进程加入可执行队列，而后者是将正在执行的进程换出到可执行队列中去
static void RR_enqueue(struct run_queue *rq, struct proc_struct *proc) {//将进程加入就绪队列
    assert(list_empty(&(proc->run_link)));//进程控制块指针非空
    list_add_before(&(rq->run_list), &(proc->run_link));//把进程的进程控制块指针放入到 rq 队列末尾
    if (proc->time_slice == 0 || proc->time_slice > rq->max_time_slice) {//进程控制块的时间片为 0 或者进程的时间片大于分配给进程的最大时间片
        proc->time_slice = rq->max_time_slice;//修改时间片
    }
    proc->rq = rq;//加入进程池
    rq->proc_num ++;//就绪进程数加一
}
//RR_dequeue 函数：该函数的功能为将某个在队列中的进程取出，其封装函数 sched_class_dequeue 仅在 schedule 中被调用，表示将调度算法选择的进程从等待的可执行的进程队列中取出进行执行
static void RR_dequeue(struct run_queue *rq, struct proc_struct *proc) {//将进程从就绪队列中移除
    assert(!list_empty(&(proc->run_link)) && proc->rq == rq);//进程控制块指针非空并且进程在就绪队列中
    list_del_init(&(proc->run_link));//将进程控制块指针从就绪队列中删除
    rq->proc_num --;//就绪进程数减一
}
//RR_pick_next 函数：该函数的封装函数同样仅在 schedule 中被调用，功能为选择要执行的下个进程
static struct proc_struct *RR_pick_next(struct run_queue *rq) {//选择下一调度进程
    list_entry_t *le = list_next(&(rq->run_list));//选取就绪进程队列 rq 中的队头队列元素
    if (le != &(rq->run_list)) {//取得就绪进程
        return le2proc(le, run_link);//返回进程控制块指针
    }
    return NULL;
}
//RR_proc_tick 函数：该函数表示每次时钟中断的时候应当调用的调度算法的功能，仅在进行时间中断的 ISR 中调用
static void RR_proc_tick(struct run_queue *rq, struct proc_struct *proc) {//时间片
    if (proc->time_slice > 0) {//到达时间片
        proc->time_slice --;//执行进程的时间片 time_slice 减一
    }
    if (proc->time_slice == 0) {//时间片为 0
        proc->need_resched = 1;//设置此进程成员变量 need_resched 标识为 1，进程需要调度
    }
}
//sched_class 定义一个 c 语言类的实现，提供调度算法的切换接口
struct sched_class default_sched_class = {
    .name = "RR_scheduler",
    .init = RR_init,
    .enqueue = RR_enqueue,
    .dequeue = RR_dequeue,
    .pick_next = RR_pick_next,
    .proc_tick = RR_proc_tick,
};
```

现在我们来逐个函数的分析，从而了解 `Round Robin` 调度算法的原理。 

首先是 `RR_init` 函数，函数完成了对进程队列的初始化。

```c
//RR_init函数：这个函数被封装为 sched_init 函数，用于调度算法的初始化，使用grep命令可以知道，该函数仅在 ucore 入口的 init.c 里面被调用进行初始化
static void RR_init(struct run_queue *rq) { //初始化进程队列
    list_init(&(rq->run_list));//初始化运行队列
    rq->proc_num = 0;//初始化进程数为 0
}
```

其中的 run_queue 结构体如下：

```c
struct run_queue {
    list_entry_t run_list;//其运行队列的哨兵结构，可以看作是队列头和尾
    unsigned int proc_num;//内部进程总数
    int max_time_slice;//每个进程一轮占用的最多时间片
    // For LAB6 ONLY
    skew_heap_entry_t *lab6_run_pool;//优先队列形式的进程容器
};
```

而 run_queue 结构体中的 skew_heap_entry 结构体如下：

```c
struct skew_heap_entry {
     struct skew_heap_entry *parent, *left, *right;//树形结构的进程容器
};
typedef struct skew_heap_entry skew_heap_entry_t;
```

然后是 `RR_enqueue` 函数，首先，它把进程的进程控制块指针放入到 rq 队列末尾，且如果进程控制块的时间片为 0，则需要把它重置为 `max_time_slice`。这表示如果进程在当前的执行时间片已经用完，需要等到下一次有机会运行时，才能再执行一段时间。然后在依次调整 rq 和 rq 的进程数目加一。

```c
//RR_enqueue函数：该函数的功能为将指定的进程的状态置成 RUNNABLE，并且放入调用算法中的可执行队列中，被封装成 sched_class_enqueue 函数，可以发现这个函数仅在 wakeup_proc 和 schedule 函数中被调用，前者为将某个不是 RUNNABLE 的进程加入可执行队列，而后者是将正在执行的进程换出到可执行队列中去
static void RR_enqueue(struct run_queue *rq, struct proc_struct *proc) {//将进程加入就绪队列
    assert(list_empty(&(proc->run_link)));//进程控制块指针非空
    list_add_before(&(rq->run_list), &(proc->run_link));//把进程的进程控制块指针放入到 rq 队列末尾
    if (proc->time_slice == 0 || proc->time_slice > rq->max_time_slice) {//进程控制块的时间片为 0 或者进程的时间片大于分配给进程的最大时间片
        proc->time_slice = rq->max_time_slice;//修改时间片
    }
    proc->rq = rq;//加入进程池
    rq->proc_num ++;//就绪进程数加一
}
```

然后是 `RR_dequeue` 函数，它简单的把就绪进程队列 rq 的进程控制块指针的队列元素删除，然后使就绪进程个数的proc_num减一。

```c
//RR_dequeue 函数：该函数的功能为将某个在队列中的进程取出，其封装函数 sched_class_dequeue 仅在 schedule 中被调用，表示将调度算法选择的进程从等待的可执行的进程队列中取出进行执行
static void RR_dequeue(struct run_queue *rq, struct proc_struct *proc) {//将进程从就绪队列中移除
    assert(!list_empty(&(proc->run_link)) && proc->rq == rq);//进程控制块指针非空并且进程在就绪队列中
    list_del_init(&(proc->run_link));//将进程控制块指针从就绪队列中删除
    rq->proc_num --;//就绪进程数减一
}
```

接下来是 `RR_pick_next` 函数，即选取函数。它选取就绪进程队列 rq 中的队头队列元素，并把队列元素转换成进程控制块指针，即置为当前占用 CPU 的程序。

```c
//RR_pick_next 函数：该函数的封装函数同样仅在 schedule 中被调用，功能为选择要执行的下个进程
static struct proc_struct *RR_pick_next(struct run_queue *rq) {//选择下一调度进程
    list_entry_t *le = list_next(&(rq->run_list));//选取就绪进程队列 rq 中的队头队列元素
    if (le != &(rq->run_list)) {//取得就绪进程
        return le2proc(le, run_link);//返回进程控制块指针
    }
    return NULL;
}
```

最后是 `RR_proc_tick`，它每一次时间片到时的时候，当前执行进程的时间片 time_slice 便减一。如果 time_slice 降到零，则设置此进程成员变量 need_resched 标识为 1，这样在下一次中断来后执行 trap 函数时，会由于当前进程程成员变量 need_resched 标识为 1 而执行 schedule 函数，从而把当前执行进程放回就绪队列末尾，而从就绪队列头取出在就绪队列上等待时间最久的那个就绪进程执行。 

```c
//RR_proc_tick 函数：该函数表示每次时钟中断的时候应当调用的调度算法的功能，仅在进行时间中断的 ISR 中调用
static void RR_proc_tick(struct run_queue *rq, struct proc_struct *proc) {//时间片
    if (proc->time_slice > 0) {//到达时间片
        proc->time_slice --;//执行进程的时间片 time_slice 减一
    }
    if (proc->time_slice == 0) {//时间片为 0
        proc->need_resched = 1;//设置此进程成员变量 need_resched 标识为 1，进程需要调度
    }
}
```

`sched_class` 定义一个 c 语言类的实现，提供调度算法的切换接口。

```c
struct sched_class default_sched_class = {
    .name = "RR_scheduler",
    .init = RR_init,
    .enqueue = RR_enqueue,
    .dequeue = RR_dequeue,
    .pick_next = RR_pick_next,
    .proc_tick = RR_proc_tick,
};
```

> 请理解并分析 sched_calss 中各个函数指针的用法，并结合 Round Robin 调度算法描述 ucore 的调度执行过程;

首先我们可以查看一下 sched_class 类中的内容：

```c
struct sched_class {
  const char *name;// 调度器的名字
  void (*init) (struct run_queue *rq);// 初始化运行队列
  void (*enqueue) (struct run_queue *rq, struct proc_struct *p);// 将进程 p 插入队列 rq
  void (*dequeue) (struct run_queue *rq, struct proc_struct *p);// 将进程 p 从队列 rq 中删除
  struct proc_struct* (*pick_next) (struct run_queue *rq);// 返回运行队列中下一个可执行的进程
  void (*proc_tick)(struct run_queue* rq, struct proc_struct* p);// timetick 处理函数
};
```

接下来我们结合具体算法来描述一下 ucore 调度执行过程：

- 在ucore中调用调度器的主体函数（不包括 init，proc_tick）的代码仅存在在 wakeup_proc 和 schedule，前者的作用在于将某一个指定进程放入可执行进程队列中，后者在于将当前执行的进程放入可执行队列中，然后将队列中选择的下一个执行的进程取出执行；

- 当需要将某一个进程加入就绪进程队列中，则需要将这个进程的能够使用的时间片进行初始化，然后将其插入到使用链表组织的队列的对尾；这就是具体的 Round-Robin enqueue 函数的实现；

- 当需要将某一个进程从就绪队列中取出的时候，只需要将其直接删除即可；

- 当需要取出执行的下一个进程的时候，只需要将就绪队列的队头取出即可；

- 每当出现一个时钟中断，则会将当前执行的进程的剩余可执行时间减 1，一旦减到了 0，则将其标记为可以被调度的，这样在 ISR 中的后续部分就会调用 schedule 函数将这个进程切换出去；

> 请在实验报告中简要说明如何设计实现”多级反馈队列调度算法“，给出概要设计，鼓励给出详细设计;

设计如下：

- 在 proc_struct 中添加总共 N 个多级反馈队列的入口，每个队列都有着各自的优先级，编号越大的队列优先级约低，并且优先级越低的队列上时间片的长度越大，为其上一个优先级队列的两倍；并且在 PCB 中记录当前进程所处的队列的优先级；

- 处理调度算法初始化的时候需要同时对 N 个队列进行初始化；

- 在处理将进程加入到就绪进程集合的时候，观察这个进程的时间片有没有使用完，如果使用完了，就将所在队列的优先级调低，加入到优先级低 1 级的队列中去，如果没有使用完时间片，则加入到当前优先级的队列中去；

- 在同一个优先级的队列内使用时间片轮转算法；

- 在选择下一个执行的进程的时候，有限考虑高优先级的队列中是否存在任务，如果不存在才转而寻找较低优先级的队列；（有可能导致饥饿）

- 从就绪进程集合中删除某一个进程就只需要在对应队列中删除即可；

- 处理时间中断的函数不需要改变；

至此完成了多级反馈队列调度算法的具体设计；

---

## 补充分析（按要求完成）

### 1) 对比 lab5 与 lab6 中同名但实现不同的函数

这里选择 `kern/schedule/sched.c` 中的 `schedule()` 与 `wakeup_proc()` 进行对比（lab5/lab6 均存在，且实现差异很大）。

#### (1) lab5: schedule() 基于 proc_list 线性扫描

lab5 的 `schedule()` 不依赖“就绪队列”，而是从全局进程链表 `proc_list` 中从 `current` 的位置开始向后遍历，找到下一个 `PROC_RUNNABLE` 进程来运行。

- 优点：实现简单，不需要维护额外的 runnable 容器。
- 缺点/局限：
    - 调度开销是 $O(N)$（N 为系统进程总数），进程多时扫描成本高。
    - 调度策略被写死在 `schedule()` 中：如果要加入 RR/stride/优先级等策略，就只能不断往 `schedule()` 里堆逻辑，难以维护与切换。
    - “可运行集合”是隐式的（通过 `proc->state` 过滤），无法自然表达 RR 的 FIFO 队列顺序或 stride 的最小键选择结构。

#### (2) lab6: schedule() 基于调度框架 + run_queue + sched_class

lab6 的 `schedule()` 把“机制”和“策略”解耦：

- 机制（framework）固定在 `sched.c`：
    - `enqueue(current)`（如当前仍 runnable）
    - `pick_next()` 选下一个
    - `dequeue(next)` 从 runnable 容器移除
    - `proc_run(next)` 切换
- 策略（policy）由 `struct sched_class` 提供回调：
    - RR 使用链表 FIFO（`run_list`）
    - stride 使用优先队列（`lab6_run_pool`）

#### (3) 为什么要做这个改动？不做会出什么问题？

1. **不做改动将难以实现可插拔算法**：stride/RR/优先级等都需要不同的数据结构与状态，lab6 通过 `sched_class` 把策略隔离，使切换只需换一个指针。
2. **不做改动会破坏“唤醒后可运行”语义**：
     - lab6 的 runnable 集合是显式的 run_queue。
     - 因此 `wakeup_proc()` 在把进程状态改为 `PROC_RUNNABLE` 后，还必须把它插入 run_queue（`sched_class_enqueue(proc)`）。
     - 如果仍采用 lab5 的 `wakeup_proc()`（只改状态、不入队），进程虽然 runnable，但不在 run_queue 中，`pick_next()` 永远选不到它，表现为“唤醒了但永远不运行”。
3. **性能与语义**：RR 需要严格 FIFO 轮转；stride 需要基于最小 stride 选取。仅靠扫描 `proc_list` 很难既保持语义清晰又保持性能可控。

### 2) RR 各函数实现思路、链表操作选择、关键代码与边界情况

本实验 RR 使用双向循环链表实现 FIFO 队列，`rq->run_list` 是哨兵结点（空队列时 `next/prev` 指向自身）。选择链表的原因：队尾入队 + 队头取出是 RR 的核心操作，链表能 $O(1)$ 完成。

#### (1) RR_init

- 思路：初始化队列和统计信息。
- 关键点：`list_init(&(rq->run_list))` 统一处理空/非空边界；`rq->proc_num=0`。
- 边界：初始化后队列为空，后续 `RR_pick_next` 必须在空队列时返回 `NULL`。

#### (2) RR_enqueue（队尾入队）

- 为什么用 `list_add_before(&(rq->run_list), &(proc->run_link))`？
    - `rq->run_list` 是哨兵，把结点插到哨兵“之前”就是插到链表尾部。
    - 这保证 FIFO：先进入队列的先被调度。
- 关键代码解释：
    - `assert(list_empty(&(proc->run_link)))`：防止同一进程重复入队导致链表断裂。
    - `if (proc->time_slice == 0 || proc->time_slice > rq->max_time_slice) proc->time_slice = rq->max_time_slice;`
        - 处理两类边界：
            1) 时间片耗尽重新入队，应当重置；
            2) time_slice 异常过大，统一裁剪到 max。
    - `proc->rq = rq; rq->proc_num++;`：维护归属与计数。

#### (3) RR_dequeue（出队）

- 为什么用 `list_del_init` 而不是 `list_del`？
    - `list_del_init` 会把该结点自身也恢复成“空链”状态，使得下次入队前 `list_empty` 判定成立，避免二次删除/悬挂问题。
- 边界：通过 `assert(proc->rq == rq)` 防止跨队列误删。

#### (4) RR_pick_next（取队头，不删除）

- 思路：队头即 `list_next(&(rq->run_list))`。
- 边界：若返回的还是哨兵（`le == &rq->run_list`），说明队列空，返回 `NULL`，由 `schedule()` 回退到 `idleproc`。

#### (5) RR_proc_tick（时间片递减 + 请求调度）

- 思路：每次时钟 tick 把 `time_slice` 递减；耗尽时通过 `need_resched` 请求调度。
- 边界：只在 `time_slice > 0` 时递减，避免负数。
- 为什么一定要设置 `need_resched`？
    - tick 处理本质是“记账”，真正上下文切换在安全点执行。
    - 若不置位 `need_resched`，即使 time_slice 为 0，系统也不会主动进入 `schedule()`，会导致当前进程长期占用 CPU，RR 退化为“永不抢占”。

### 3) 实验结果：make grade 输出 + QEMU 调度现象

#### (1) make grade 输出

在 lab6 目录执行 `make grade`：

```text
priority:                (3.1s)
    -check result:                             OK
    -check output:                             OK
Total Score: 50/50
```

#### (2) QEMU 中可观察到的调度现象（如何观察 + 现象描述）

运行：在 lab6 目录执行 `make qemu`。

可观察现象（可在报告中配合 QEMU 输出截图/日志记录）：

- 启动时会打印 `sched class: RR_scheduler`，说明 `sched_init()` 已成功绑定 RR 调度类。
- 时钟中断会持续触发：`ticks` 递增，并在满足 `ticks % TICK_NUM == 0` 时打印 tick（例如 `100 ticks`），说明抢占式调度的“触发源”正常。
- 当系统同时存在多个 runnable 进程时：
    - 进程会按 FIFO 顺序轮转获得 CPU；
    - 每个进程最多运行 `max_time_slice` 个 tick，耗尽后被放回队尾；
    - 因此用户程序输出（或调试输出中的 pid/runs 变化）会呈现“交错/轮转”现象。

说明：若希望更直观看到切换，可以临时在 `schedule()` 或 `proc_run()` 中加入调试打印（例如打印 `current->pid` 与 `next->pid`）。提交最终代码时应去除这些调试输出。

### 4) Round Robin 优缺点、时间片调优与 need_resched 的必要性

#### (1) 优点

- 公平性较好：所有 runnable 进程按队列顺序轮转。
- 实现简单，策略易理解。

#### (2) 缺点

- 对任务类型不敏感：交互型与 CPU 密集型进程同等待遇，交互响应不一定最优。
- 时间片敏感：
    - 时间片过小：上下文切换频繁，开销增大、吞吐下降。
    - 时间片过大：响应变差，接近先来先服务。

#### (3) 如何调整时间片优化系统性能

- 设上下文切换开销为 $C$，时间片为 $Q$，则切换开销占比近似 $C/Q$。
    - 增大 $Q$ 可降低开销占比，提高吞吐，但降低交互响应。
    - 减小 $Q$ 可改善响应，但会提高切换开销。
- 实践中应结合负载（交互/吞吐）折中选择；本实验可通过修改 `MAX_TIME_SLICE` 来调节。

#### (4) 为什么 RR_proc_tick 必须设置 need_resched

- `need_resched` 是“请求调度”的跨模块信号：
    - 调度类在 tick 中置位；
    - trap 返回用户态前统一检查该标志并调用 `schedule()`。
- 不置位则无法形成抢占式轮转，其他进程可能长期饥饿。

### 5) 拓展思考：优先级 RR 与多核调度

#### (1) 实现优先级 RR 的修改方向

一种直接的方案是“多队列 RR”（每个优先级一个 FIFO 队列）：

- 在 `run_queue` 中维护 `run_list[PRI_NUM]`。
- `proc_struct` 增加 `priority` 字段。
- `enqueue`：按 `priority` 入对应队尾。
- `pick_next`：从最高优先级非空队列取队头。
- 为避免低优先级饥饿：可引入 aging（等待越久逐步提高优先级）或周期性提升。

另一种方案是“权重 RR”：不同优先级分配不同时间片（例如 `time_slice = base * weight`），无需多队列但公平性/响应性需要额外权衡。

#### (2) 当前实现是否支持多核调度？如何改进？

当前实现本质上是单核模型，不是真正的 SMP：

- 只有一个全局 `rq` 与一个全局 `current`；临界区保护主要是 `local_intr_save/restore`，无法阻止其他 CPU 并发访问。

若要支持多核，需要至少：

- 引入 per-CPU 的 `current` 与 `run_queue`（或全局队列 + 自旋锁）。
- 为 run_queue 增加自旋锁 `rq_lock`，并在 `enqueue/dequeue/pick_next` 等路径持锁。
- 实现负载均衡（可利用 `sched_class` 中预留的 SMP 扩展接口思想）：在 CPU 间迁移 runnable 进程，避免某核空闲而另一核拥塞。
