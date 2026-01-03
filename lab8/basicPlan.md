这次实验要求如下：
练习1: 完成读文件操作的实现（需要编码）
首先了解打开文件的处理流程，然后参考本实验后续的文件读写操作的过程分析，填写在 kern/fs/sfs/sfs_inode.c中 的sfs_io_nolock()函数，实现读文件中数据的代码。

练习2: 完成基于文件系统的执行程序机制的实现（需要编码）
改写proc.c中的load_icode函数和其他相关函数，实现基于文件系统的执行程序机制。执行：make qemu。如果能看看到sh用户程序的执行界面，则基本成功了。如果在sh用户界面上可以执行exit, hello（更多用户程序放在user目录下）等其他放置在sfs文件系统中的其他执行程序，则可以认为本实验基本成功。
请你规划实现内容
Research Lab8 implementation details

读取 [](file:///d%3A/1%E5%A4%A7%E4%B8%89%E4%B8%8A/%E6%93%8D%E4%BD%9C%E7%B3%BB%E7%BB%9F/OS/OS2025/lab8/kern/fs/sfs/)

读取 [](file:///d%3A/1%E5%A4%A7%E4%B8%89%E4%B8%8A/%E6%93%8D%E4%BD%9C%E7%B3%BB%E7%BB%9F/OS/OS2025/lab8/kern/process/)

搜索文本 `sfs_io_nolock` (`**/lab8/kern/fs/sfs/sfs_inode.c`)，4 个结果

读取 [](file:///d%3A/1%E5%A4%A7%E4%B8%89%E4%B8%8A/%E6%93%8D%E4%BD%9C%E7%B3%BB%E7%BB%9F/OS/OS2025/lab8/kern/process/proc.c#1-1)，行 1 到 1000

读取 [](file:///d%3A/1%E5%A4%A7%E4%B8%89%E4%B8%8A/%E6%93%8D%E4%BD%9C%E7%B3%BB%E7%BB%9F/OS/OS2025/lab8/kern/fs/sfs/sfs_inode.c#540-540)，行 540 到 650

搜索文本 `sfs_bmap_load_nolock` (`**/lab8/kern/fs/sfs/sfs_inode.c`)，8 个结果

读取 [](file:///d%3A/1%E5%A4%A7%E4%B8%89%E4%B8%8A/%E6%93%8D%E4%BD%9C%E7%B3%BB%E7%BB%9F/OS/OS2025/lab8/kern/fs/sfs/sfs_inode.c#340-340)，行 340 到 400

读取 [](file:///d%3A/1%E5%A4%A7%E4%B8%89%E4%B8%8A/%E6%93%8D%E4%BD%9C%E7%B3%BB%E7%BB%9F/OS/OS2025/lab5/kern/process/proc.c#400-400)，行 400 到 600

## Plan: Ucore Lab8 文件系统实现与集成

本计划旨在完成 Lab8 的两个核心练习：实现 SFS 文件系统的读写逻辑，以及将进程管理与文件系统集成，实现从磁盘加载并运行用户程序。

### 步骤

1. **实现 SFS 读写核心逻辑**：在 kern/fs/sfs/sfs_inode.c 的 `sfs_io_nolock` 函数中，实现对磁盘块的循环处理。逻辑需涵盖：计算起始/结束块偏移、处理首尾不对齐的块（使用 `sfs_buf_op`）以及中间对齐的完整块（使用 `sfs_block_op`），并调用 `sfs_bmap_load_nolock` 获取物理块号。

2. **完善进程控制块初始化**：在 kern/process/proc.c 的 `alloc_proc` 函数中，初始化新成员 `proc->filesp = NULL`，确保每个新进程的文件描述符表指针初始为空。

3. **集成文件描述符管理到进程生命周期**：
    *   在 `do_fork` 中调用 `copy_files`，根据 `clone_flags` 决定是共享还是复制父进程的文件表。
    *   在 `do_exit` 中调用 `put_files`，在进程退出时释放其占用的文件资源。

4. **重构程序加载机制 `load_icode`**：在 kern/process/proc.c 中重新实现 `load_icode`。
    *   使用 `load_icode_read` 替代 `memcpy`，通过文件描述符 `fd` 从磁盘读取 ELF 头部和程序头表。
    *   遍历 `PT_LOAD` 段，建立 VMA 映射，分配物理页，并将文件内容加载到对应内存地址。
    *   在用户栈顶正确压入 `argc` 和 `argv` 参数字符串及其指针数组。

5. **设置用户态执行环境**：在 `load_icode` 末尾正确配置 `trapframe`，设置 `tf->gpr.sp` 为用户栈指针，`tf->epc` 为程序入口点，并确保 `sstatus` 的 `SPP` 位清零以返回用户态。

### 进一步考虑

1. **SFS 写入同步**：在 `sfs_io_nolock` 处理写入时，若文件长度增加，务必更新 `sin->din->size` 并设置 `sin->dirty = 1` 以便后续同步回磁盘。
2. **参数空间计算**：在 `load_icode` 中计算用户栈空间时，需考虑字符串对齐和指针数组的大小，避免栈溢出或地址错误。
3. **错误处理路径**：在 `load_icode` 的各个阶段（如内存分配失败、读取文件失败）需建立完善的清理机制（`goto` 到清理标签），防止内存泄漏或文件句柄泄露。