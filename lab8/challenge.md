## Plan: Ucore Lab8 扩展挑战设计方案

本计划为 Ucore Lab8 的两个 Challenge 提供概要设计方案，旨在利用现有的 VFS 和 SFS 架构实现 UNIX 风格的管道和链接机制。

### Challenge 1: UNIX PIPE 机制设计

管道是进程间通信（IPC）的基础，在 ucore 中可将其抽象为一种特殊的内存文件。

#### 1. 核心数据结构
```c
// 管道缓冲区结构
struct pipe_buffer {
    char *data;            // 指向内存缓冲区的指针（如 4KB）
    size_t head;           // 写入位置
    size_t tail;           // 读取位置
    size_t size;           // 当前数据量
    struct semaphore sem_mutex; // 互斥锁，保护缓冲区操作
    struct semaphore sem_read;  // 读信号量，缓冲区为空时阻塞读者
    struct semaphore sem_write; // 写信号量，缓冲区满时阻塞写者
};

// 管道 inode 信息（集成在 vfs_inode 的 in_info 中）
struct pipe_inode_info {
    struct pipe_buffer *buf;    // 指向共享缓冲区
    uint32_t read_count;        // 读端引用计数
    uint32_t write_count;       // 写端引用计数
};
```

#### 2. 核心接口语义
*   `sys_pipe(int fd[2])`: 在内核中分配一个 `pipe_buffer`，创建两个 `file` 结构（读端和写端），它们指向同一个包装了 `pipe_inode_info` 的 `inode`。
*   `pipe_read(inode, iobuf)`: 若缓冲区为空且写端未关闭，则在 `sem_read` 上等待；否则读取数据并唤醒 `sem_write`。
*   `pipe_write(inode, iobuf)`: 若缓冲区已满且读端未关闭，则在 `sem_write` 上等待；否则写入数据并唤醒 `sem_read`。

#### 3. 同步互斥处理
*   使用 `sem_mutex` 保证对 `head/tail/size` 修改的原子性。
*   利用 `sem_read` 和 `sem_write` 实现生产-消费模型。
*   **特殊情况**：若所有写端关闭，`read` 返回 0（EOF）；若所有读端关闭，`write` 触发异常（如 SIGPIPE）。

---

### Challenge 2: 硬链接与软链接机制设计

基于 SFS 文件系统实现文件共享与路径重定向。

#### 1. 核心数据结构
```c
// SFS 磁盘索引节点（利用现有结构）
struct sfs_disk_inode {
    uint32_t size;          // 文件大小
    uint16_t type;          // SFS_TYPE_FILE, SFS_TYPE_DIR, SFS_TYPE_LINK
    uint16_t nlinks;        // 硬链接计数（Challenge 2 核心）
    uint32_t direct[SFS_NDIRECT]; // 直接索引块
    // ... 间接索引等
};

// 软链接数据块内容
// 对于 SFS_TYPE_LINK，其数据块存储的是目标路径字符串（如 "/bin/hello"）
```

#### 2. 核心接口语义
*   `sys_link(oldpath, newpath)` (硬链接):
    1. 查找 `oldpath` 对应的 inode 编号。
    2. 在 `newpath` 所在的目录中增加一个目录项，指向该 inode。
    3. 将该 inode 的 `nlinks` 加 1 并写回磁盘。
*   `sys_symlink(target, linkpath)` (软链接):
    1. 创建一个类型为 `SFS_TYPE_LINK` 的新 inode。
    2. 将 `target` 路径字符串写入该 inode 的数据块。
    3. 在 `linkpath` 所在目录创建指向该新 inode 的目录项。
*   `vfs_lookup` (路径解析增强):
    1. 在解析路径时，若遇到 `type == SFS_TYPE_LINK` 的 inode。
    2. 读取其内容（目标路径）。
    3. 递归调用 `vfs_lookup` 解析新路径（需维护 `link_count` 限制递归深度，防止死循环）。

#### 3. 同步互斥处理
*   **原子性**：在修改目录项和增加 `nlinks` 时，必须持有对应目录和 inode 的 `sfs_lock`。
*   **删除逻辑**：`sys_unlink` 减少 `nlinks`。只有当 `nlinks == 0` 且内存中该 inode 的引用计数 `ref_count == 0` 时，才释放磁盘块。

### 进一步考虑
1. **管道关闭**：需在 `file_close` 中检测是否为管道，并正确递减 `read_count/write_count`。
2. **软链接跨文件系统**：软链接存储的是路径字符串，因此天然支持跨文件系统（如果 ucore 未来支持多个挂载点）。