
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid
ffffffffc0200000:	00005297          	auipc	t0,0x5
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0)
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0205000 <boot_hartid>
    la t0, boot_dtb
ffffffffc020000c:	00005297          	auipc	t0,0x5
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0205008 <boot_dtb>
    sd a1, 0(t0)
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39)
ffffffffc0200018:	c02042b7          	lui	t0,0xc0204
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
ffffffffc020001c:	ffd0031b          	addiw	t1,zero,-3
ffffffffc0200020:	037a                	slli	t1,t1,0x1e
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
ffffffffc0200022:	406282b3          	sub	t0,t0,t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12
ffffffffc0200026:	00c2d293          	srli	t0,t0,0xc

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60
ffffffffc020002a:	fff0031b          	addiw	t1,zero,-1
ffffffffc020002e:	137e                	slli	t1,t1,0x3f
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1
ffffffffc0200030:	0062e2b3          	or	t0,t0,t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
ffffffffc0200034:	18029073          	csrw	satp,t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
ffffffffc0200038:	12000073          	sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)
ffffffffc020003c:	c0204137          	lui	sp,0xc0204

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 跳转到 kern_init
    lui t0, %hi(kern_init)
ffffffffc0200040:	c02002b7          	lui	t0,0xc0200
    addi t0, t0, %lo(kern_init)
ffffffffc0200044:	0d828293          	addi	t0,t0,216 # ffffffffc02000d8 <kern_init>
    jr t0
ffffffffc0200048:	8282                	jr	t0

ffffffffc020004a <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
ffffffffc020004a:	1141                	addi	sp,sp,-16
    extern char etext[], edata[], end[];
    cprintf("Special kernel symbols:\n");
ffffffffc020004c:	00001517          	auipc	a0,0x1
ffffffffc0200050:	2c450513          	addi	a0,a0,708 # ffffffffc0201310 <etext>
void print_kerninfo(void) {
ffffffffc0200054:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc0200056:	0f6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005a:	00000597          	auipc	a1,0x0
ffffffffc020005e:	07e58593          	addi	a1,a1,126 # ffffffffc02000d8 <kern_init>
ffffffffc0200062:	00001517          	auipc	a0,0x1
ffffffffc0200066:	2ce50513          	addi	a0,a0,718 # ffffffffc0201330 <etext+0x20>
ffffffffc020006a:	0e2000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc020006e:	00001597          	auipc	a1,0x1
ffffffffc0200072:	2a258593          	addi	a1,a1,674 # ffffffffc0201310 <etext>
ffffffffc0200076:	00001517          	auipc	a0,0x1
ffffffffc020007a:	2da50513          	addi	a0,a0,730 # ffffffffc0201350 <etext+0x40>
ffffffffc020007e:	0ce000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200082:	00005597          	auipc	a1,0x5
ffffffffc0200086:	f9658593          	addi	a1,a1,-106 # ffffffffc0205018 <slub_caches>
ffffffffc020008a:	00001517          	auipc	a0,0x1
ffffffffc020008e:	2e650513          	addi	a0,a0,742 # ffffffffc0201370 <etext+0x60>
ffffffffc0200092:	0ba000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc0200096:	00005597          	auipc	a1,0x5
ffffffffc020009a:	22658593          	addi	a1,a1,550 # ffffffffc02052bc <end>
ffffffffc020009e:	00001517          	auipc	a0,0x1
ffffffffc02000a2:	2f250513          	addi	a0,a0,754 # ffffffffc0201390 <etext+0x80>
ffffffffc02000a6:	0a6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
ffffffffc02000aa:	00005597          	auipc	a1,0x5
ffffffffc02000ae:	61158593          	addi	a1,a1,1553 # ffffffffc02056bb <end+0x3ff>
ffffffffc02000b2:	00000797          	auipc	a5,0x0
ffffffffc02000b6:	02678793          	addi	a5,a5,38 # ffffffffc02000d8 <kern_init>
ffffffffc02000ba:	40f587b3          	sub	a5,a1,a5
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000be:	43f7d593          	srai	a1,a5,0x3f
}
ffffffffc02000c2:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000c4:	3ff5f593          	andi	a1,a1,1023
ffffffffc02000c8:	95be                	add	a1,a1,a5
ffffffffc02000ca:	85a9                	srai	a1,a1,0xa
ffffffffc02000cc:	00001517          	auipc	a0,0x1
ffffffffc02000d0:	2e450513          	addi	a0,a0,740 # ffffffffc02013b0 <etext+0xa0>
}
ffffffffc02000d4:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000d6:	a89d                	j	ffffffffc020014c <cprintf>

ffffffffc02000d8 <kern_init>:

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc02000d8:	00005517          	auipc	a0,0x5
ffffffffc02000dc:	f4050513          	addi	a0,a0,-192 # ffffffffc0205018 <slub_caches>
ffffffffc02000e0:	00005617          	auipc	a2,0x5
ffffffffc02000e4:	1dc60613          	addi	a2,a2,476 # ffffffffc02052bc <end>
int kern_init(void) {
ffffffffc02000e8:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc02000ea:	8e09                	sub	a2,a2,a0
ffffffffc02000ec:	4581                	li	a1,0
int kern_init(void) {
ffffffffc02000ee:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc02000f0:	20e010ef          	jal	ra,ffffffffc02012fe <memset>
    dtb_init();
ffffffffc02000f4:	12c000ef          	jal	ra,ffffffffc0200220 <dtb_init>
    cons_init();  // init the console
ffffffffc02000f8:	11e000ef          	jal	ra,ffffffffc0200216 <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc02000fc:	00001517          	auipc	a0,0x1
ffffffffc0200100:	2e450513          	addi	a0,a0,740 # ffffffffc02013e0 <etext+0xd0>
ffffffffc0200104:	07e000ef          	jal	ra,ffffffffc0200182 <cputs>

    print_kerninfo();
ffffffffc0200108:	f43ff0ef          	jal	ra,ffffffffc020004a <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc020010c:	4c4000ef          	jal	ra,ffffffffc02005d0 <pmm_init>

    /* do nothing */
    while (1)
ffffffffc0200110:	a001                	j	ffffffffc0200110 <kern_init+0x38>

ffffffffc0200112 <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
ffffffffc0200112:	1141                	addi	sp,sp,-16
ffffffffc0200114:	e022                	sd	s0,0(sp)
ffffffffc0200116:	e406                	sd	ra,8(sp)
ffffffffc0200118:	842e                	mv	s0,a1
    cons_putc(c);
ffffffffc020011a:	0fe000ef          	jal	ra,ffffffffc0200218 <cons_putc>
    (*cnt) ++;
ffffffffc020011e:	401c                	lw	a5,0(s0)
}
ffffffffc0200120:	60a2                	ld	ra,8(sp)
    (*cnt) ++;
ffffffffc0200122:	2785                	addiw	a5,a5,1
ffffffffc0200124:	c01c                	sw	a5,0(s0)
}
ffffffffc0200126:	6402                	ld	s0,0(sp)
ffffffffc0200128:	0141                	addi	sp,sp,16
ffffffffc020012a:	8082                	ret

ffffffffc020012c <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
ffffffffc020012c:	1101                	addi	sp,sp,-32
ffffffffc020012e:	862a                	mv	a2,a0
ffffffffc0200130:	86ae                	mv	a3,a1
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200132:	00000517          	auipc	a0,0x0
ffffffffc0200136:	fe050513          	addi	a0,a0,-32 # ffffffffc0200112 <cputch>
ffffffffc020013a:	006c                	addi	a1,sp,12
vcprintf(const char *fmt, va_list ap) {
ffffffffc020013c:	ec06                	sd	ra,24(sp)
    int cnt = 0;
ffffffffc020013e:	c602                	sw	zero,12(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200140:	5a9000ef          	jal	ra,ffffffffc0200ee8 <vprintfmt>
    return cnt;
}
ffffffffc0200144:	60e2                	ld	ra,24(sp)
ffffffffc0200146:	4532                	lw	a0,12(sp)
ffffffffc0200148:	6105                	addi	sp,sp,32
ffffffffc020014a:	8082                	ret

ffffffffc020014c <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
ffffffffc020014c:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
ffffffffc020014e:	02810313          	addi	t1,sp,40 # ffffffffc0204028 <boot_page_table_sv39+0x28>
cprintf(const char *fmt, ...) {
ffffffffc0200152:	8e2a                	mv	t3,a0
ffffffffc0200154:	f42e                	sd	a1,40(sp)
ffffffffc0200156:	f832                	sd	a2,48(sp)
ffffffffc0200158:	fc36                	sd	a3,56(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020015a:	00000517          	auipc	a0,0x0
ffffffffc020015e:	fb850513          	addi	a0,a0,-72 # ffffffffc0200112 <cputch>
ffffffffc0200162:	004c                	addi	a1,sp,4
ffffffffc0200164:	869a                	mv	a3,t1
ffffffffc0200166:	8672                	mv	a2,t3
cprintf(const char *fmt, ...) {
ffffffffc0200168:	ec06                	sd	ra,24(sp)
ffffffffc020016a:	e0ba                	sd	a4,64(sp)
ffffffffc020016c:	e4be                	sd	a5,72(sp)
ffffffffc020016e:	e8c2                	sd	a6,80(sp)
ffffffffc0200170:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
ffffffffc0200172:	e41a                	sd	t1,8(sp)
    int cnt = 0;
ffffffffc0200174:	c202                	sw	zero,4(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200176:	573000ef          	jal	ra,ffffffffc0200ee8 <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
ffffffffc020017a:	60e2                	ld	ra,24(sp)
ffffffffc020017c:	4512                	lw	a0,4(sp)
ffffffffc020017e:	6125                	addi	sp,sp,96
ffffffffc0200180:	8082                	ret

ffffffffc0200182 <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
ffffffffc0200182:	1101                	addi	sp,sp,-32
ffffffffc0200184:	e822                	sd	s0,16(sp)
ffffffffc0200186:	ec06                	sd	ra,24(sp)
ffffffffc0200188:	e426                	sd	s1,8(sp)
ffffffffc020018a:	842a                	mv	s0,a0
    int cnt = 0;
    char c;
    while ((c = *str ++) != '\0') {
ffffffffc020018c:	00054503          	lbu	a0,0(a0)
ffffffffc0200190:	c51d                	beqz	a0,ffffffffc02001be <cputs+0x3c>
ffffffffc0200192:	0405                	addi	s0,s0,1
ffffffffc0200194:	4485                	li	s1,1
ffffffffc0200196:	9c81                	subw	s1,s1,s0
    cons_putc(c);
ffffffffc0200198:	080000ef          	jal	ra,ffffffffc0200218 <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc020019c:	00044503          	lbu	a0,0(s0)
ffffffffc02001a0:	008487bb          	addw	a5,s1,s0
ffffffffc02001a4:	0405                	addi	s0,s0,1
ffffffffc02001a6:	f96d                	bnez	a0,ffffffffc0200198 <cputs+0x16>
    (*cnt) ++;
ffffffffc02001a8:	0017841b          	addiw	s0,a5,1
    cons_putc(c);
ffffffffc02001ac:	4529                	li	a0,10
ffffffffc02001ae:	06a000ef          	jal	ra,ffffffffc0200218 <cons_putc>
        cputch(c, &cnt);
    }
    cputch('\n', &cnt);
    return cnt;
}
ffffffffc02001b2:	60e2                	ld	ra,24(sp)
ffffffffc02001b4:	8522                	mv	a0,s0
ffffffffc02001b6:	6442                	ld	s0,16(sp)
ffffffffc02001b8:	64a2                	ld	s1,8(sp)
ffffffffc02001ba:	6105                	addi	sp,sp,32
ffffffffc02001bc:	8082                	ret
    while ((c = *str ++) != '\0') {
ffffffffc02001be:	4405                	li	s0,1
ffffffffc02001c0:	b7f5                	j	ffffffffc02001ac <cputs+0x2a>

ffffffffc02001c2 <__panic>:
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
    if (is_panic) {
ffffffffc02001c2:	00005317          	auipc	t1,0x5
ffffffffc02001c6:	0ae30313          	addi	t1,t1,174 # ffffffffc0205270 <is_panic>
ffffffffc02001ca:	00032e03          	lw	t3,0(t1)
__panic(const char *file, int line, const char *fmt, ...) {
ffffffffc02001ce:	715d                	addi	sp,sp,-80
ffffffffc02001d0:	ec06                	sd	ra,24(sp)
ffffffffc02001d2:	e822                	sd	s0,16(sp)
ffffffffc02001d4:	f436                	sd	a3,40(sp)
ffffffffc02001d6:	f83a                	sd	a4,48(sp)
ffffffffc02001d8:	fc3e                	sd	a5,56(sp)
ffffffffc02001da:	e0c2                	sd	a6,64(sp)
ffffffffc02001dc:	e4c6                	sd	a7,72(sp)
    if (is_panic) {
ffffffffc02001de:	000e0363          	beqz	t3,ffffffffc02001e4 <__panic+0x22>
    vcprintf(fmt, ap);
    cprintf("\n");
    va_end(ap);

panic_dead:
    while (1) {
ffffffffc02001e2:	a001                	j	ffffffffc02001e2 <__panic+0x20>
    is_panic = 1;
ffffffffc02001e4:	4785                	li	a5,1
ffffffffc02001e6:	00f32023          	sw	a5,0(t1)
    va_start(ap, fmt);
ffffffffc02001ea:	8432                	mv	s0,a2
ffffffffc02001ec:	103c                	addi	a5,sp,40
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001ee:	862e                	mv	a2,a1
ffffffffc02001f0:	85aa                	mv	a1,a0
ffffffffc02001f2:	00001517          	auipc	a0,0x1
ffffffffc02001f6:	20e50513          	addi	a0,a0,526 # ffffffffc0201400 <etext+0xf0>
    va_start(ap, fmt);
ffffffffc02001fa:	e43e                	sd	a5,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001fc:	f51ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    vcprintf(fmt, ap);
ffffffffc0200200:	65a2                	ld	a1,8(sp)
ffffffffc0200202:	8522                	mv	a0,s0
ffffffffc0200204:	f29ff0ef          	jal	ra,ffffffffc020012c <vcprintf>
    cprintf("\n");
ffffffffc0200208:	00001517          	auipc	a0,0x1
ffffffffc020020c:	1d050513          	addi	a0,a0,464 # ffffffffc02013d8 <etext+0xc8>
ffffffffc0200210:	f3dff0ef          	jal	ra,ffffffffc020014c <cprintf>
ffffffffc0200214:	b7f9                	j	ffffffffc02001e2 <__panic+0x20>

ffffffffc0200216 <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc0200216:	8082                	ret

ffffffffc0200218 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc0200218:	0ff57513          	zext.b	a0,a0
ffffffffc020021c:	04e0106f          	j	ffffffffc020126a <sbi_console_putchar>

ffffffffc0200220 <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc0200220:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc0200222:	00001517          	auipc	a0,0x1
ffffffffc0200226:	1fe50513          	addi	a0,a0,510 # ffffffffc0201420 <etext+0x110>
void dtb_init(void) {
ffffffffc020022a:	fc86                	sd	ra,120(sp)
ffffffffc020022c:	f8a2                	sd	s0,112(sp)
ffffffffc020022e:	e8d2                	sd	s4,80(sp)
ffffffffc0200230:	f4a6                	sd	s1,104(sp)
ffffffffc0200232:	f0ca                	sd	s2,96(sp)
ffffffffc0200234:	ecce                	sd	s3,88(sp)
ffffffffc0200236:	e4d6                	sd	s5,72(sp)
ffffffffc0200238:	e0da                	sd	s6,64(sp)
ffffffffc020023a:	fc5e                	sd	s7,56(sp)
ffffffffc020023c:	f862                	sd	s8,48(sp)
ffffffffc020023e:	f466                	sd	s9,40(sp)
ffffffffc0200240:	f06a                	sd	s10,32(sp)
ffffffffc0200242:	ec6e                	sd	s11,24(sp)
    cprintf("DTB Init\n");
ffffffffc0200244:	f09ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc0200248:	00005597          	auipc	a1,0x5
ffffffffc020024c:	db85b583          	ld	a1,-584(a1) # ffffffffc0205000 <boot_hartid>
ffffffffc0200250:	00001517          	auipc	a0,0x1
ffffffffc0200254:	1e050513          	addi	a0,a0,480 # ffffffffc0201430 <etext+0x120>
ffffffffc0200258:	ef5ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc020025c:	00005417          	auipc	s0,0x5
ffffffffc0200260:	dac40413          	addi	s0,s0,-596 # ffffffffc0205008 <boot_dtb>
ffffffffc0200264:	600c                	ld	a1,0(s0)
ffffffffc0200266:	00001517          	auipc	a0,0x1
ffffffffc020026a:	1da50513          	addi	a0,a0,474 # ffffffffc0201440 <etext+0x130>
ffffffffc020026e:	edfff0ef          	jal	ra,ffffffffc020014c <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc0200272:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc0200276:	00001517          	auipc	a0,0x1
ffffffffc020027a:	1e250513          	addi	a0,a0,482 # ffffffffc0201458 <etext+0x148>
    if (boot_dtb == 0) {
ffffffffc020027e:	120a0463          	beqz	s4,ffffffffc02003a6 <dtb_init+0x186>
        return;
    }
    
    // 转换为虚拟地址
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc0200282:	57f5                	li	a5,-3
ffffffffc0200284:	07fa                	slli	a5,a5,0x1e
ffffffffc0200286:	00fa0733          	add	a4,s4,a5
    const struct fdt_header *header = (const struct fdt_header *)dtb_vaddr;
    
    // 验证DTB
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc020028a:	431c                	lw	a5,0(a4)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020028c:	00ff0637          	lui	a2,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200290:	6b41                	lui	s6,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200292:	0087d59b          	srliw	a1,a5,0x8
ffffffffc0200296:	0187969b          	slliw	a3,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020029a:	0187d51b          	srliw	a0,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020029e:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a2:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002a6:	8df1                	and	a1,a1,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a8:	8ec9                	or	a3,a3,a0
ffffffffc02002aa:	0087979b          	slliw	a5,a5,0x8
ffffffffc02002ae:	1b7d                	addi	s6,s6,-1
ffffffffc02002b0:	0167f7b3          	and	a5,a5,s6
ffffffffc02002b4:	8dd5                	or	a1,a1,a3
ffffffffc02002b6:	8ddd                	or	a1,a1,a5
    if (magic != 0xd00dfeed) {
ffffffffc02002b8:	d00e07b7          	lui	a5,0xd00e0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002bc:	2581                	sext.w	a1,a1
    if (magic != 0xd00dfeed) {
ffffffffc02002be:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfedac31>
ffffffffc02002c2:	10f59163          	bne	a1,a5,ffffffffc02003c4 <dtb_init+0x1a4>
        return;
    }
    
    // 提取内存信息
    uint64_t mem_base, mem_size;
    if (extract_memory_info(dtb_vaddr, header, &mem_base, &mem_size) == 0) {
ffffffffc02002c6:	471c                	lw	a5,8(a4)
ffffffffc02002c8:	4754                	lw	a3,12(a4)
    int in_memory_node = 0;
ffffffffc02002ca:	4c81                	li	s9,0
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002cc:	0087d59b          	srliw	a1,a5,0x8
ffffffffc02002d0:	0086d51b          	srliw	a0,a3,0x8
ffffffffc02002d4:	0186941b          	slliw	s0,a3,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002d8:	0186d89b          	srliw	a7,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002dc:	01879a1b          	slliw	s4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e0:	0187d81b          	srliw	a6,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002e4:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e8:	0106d69b          	srliw	a3,a3,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002ec:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f0:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002f4:	8d71                	and	a0,a0,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f6:	01146433          	or	s0,s0,a7
ffffffffc02002fa:	0086969b          	slliw	a3,a3,0x8
ffffffffc02002fe:	010a6a33          	or	s4,s4,a6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200302:	8e6d                	and	a2,a2,a1
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200304:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200308:	8c49                	or	s0,s0,a0
ffffffffc020030a:	0166f6b3          	and	a3,a3,s6
ffffffffc020030e:	00ca6a33          	or	s4,s4,a2
ffffffffc0200312:	0167f7b3          	and	a5,a5,s6
ffffffffc0200316:	8c55                	or	s0,s0,a3
ffffffffc0200318:	00fa6a33          	or	s4,s4,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020031c:	1402                	slli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020031e:	1a02                	slli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200320:	9001                	srli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200322:	020a5a13          	srli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200326:	943a                	add	s0,s0,a4
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200328:	9a3a                	add	s4,s4,a4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020032a:	00ff0c37          	lui	s8,0xff0
        switch (token) {
ffffffffc020032e:	4b8d                	li	s7,3
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200330:	00001917          	auipc	s2,0x1
ffffffffc0200334:	17890913          	addi	s2,s2,376 # ffffffffc02014a8 <etext+0x198>
ffffffffc0200338:	49bd                	li	s3,15
        switch (token) {
ffffffffc020033a:	4d91                	li	s11,4
ffffffffc020033c:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc020033e:	00001497          	auipc	s1,0x1
ffffffffc0200342:	16248493          	addi	s1,s1,354 # ffffffffc02014a0 <etext+0x190>
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200346:	000a2703          	lw	a4,0(s4)
ffffffffc020034a:	004a0a93          	addi	s5,s4,4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020034e:	0087569b          	srliw	a3,a4,0x8
ffffffffc0200352:	0187179b          	slliw	a5,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200356:	0187561b          	srliw	a2,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020035a:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020035e:	0107571b          	srliw	a4,a4,0x10
ffffffffc0200362:	8fd1                	or	a5,a5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200364:	0186f6b3          	and	a3,a3,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200368:	0087171b          	slliw	a4,a4,0x8
ffffffffc020036c:	8fd5                	or	a5,a5,a3
ffffffffc020036e:	00eb7733          	and	a4,s6,a4
ffffffffc0200372:	8fd9                	or	a5,a5,a4
ffffffffc0200374:	2781                	sext.w	a5,a5
        switch (token) {
ffffffffc0200376:	09778c63          	beq	a5,s7,ffffffffc020040e <dtb_init+0x1ee>
ffffffffc020037a:	00fbea63          	bltu	s7,a5,ffffffffc020038e <dtb_init+0x16e>
ffffffffc020037e:	07a78663          	beq	a5,s10,ffffffffc02003ea <dtb_init+0x1ca>
ffffffffc0200382:	4709                	li	a4,2
ffffffffc0200384:	00e79763          	bne	a5,a4,ffffffffc0200392 <dtb_init+0x172>
ffffffffc0200388:	4c81                	li	s9,0
ffffffffc020038a:	8a56                	mv	s4,s5
ffffffffc020038c:	bf6d                	j	ffffffffc0200346 <dtb_init+0x126>
ffffffffc020038e:	ffb78ee3          	beq	a5,s11,ffffffffc020038a <dtb_init+0x16a>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;
        memory_size = mem_size;
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc0200392:	00001517          	auipc	a0,0x1
ffffffffc0200396:	18e50513          	addi	a0,a0,398 # ffffffffc0201520 <etext+0x210>
ffffffffc020039a:	db3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc020039e:	00001517          	auipc	a0,0x1
ffffffffc02003a2:	1ba50513          	addi	a0,a0,442 # ffffffffc0201558 <etext+0x248>
}
ffffffffc02003a6:	7446                	ld	s0,112(sp)
ffffffffc02003a8:	70e6                	ld	ra,120(sp)
ffffffffc02003aa:	74a6                	ld	s1,104(sp)
ffffffffc02003ac:	7906                	ld	s2,96(sp)
ffffffffc02003ae:	69e6                	ld	s3,88(sp)
ffffffffc02003b0:	6a46                	ld	s4,80(sp)
ffffffffc02003b2:	6aa6                	ld	s5,72(sp)
ffffffffc02003b4:	6b06                	ld	s6,64(sp)
ffffffffc02003b6:	7be2                	ld	s7,56(sp)
ffffffffc02003b8:	7c42                	ld	s8,48(sp)
ffffffffc02003ba:	7ca2                	ld	s9,40(sp)
ffffffffc02003bc:	7d02                	ld	s10,32(sp)
ffffffffc02003be:	6de2                	ld	s11,24(sp)
ffffffffc02003c0:	6109                	addi	sp,sp,128
    cprintf("DTB init completed\n");
ffffffffc02003c2:	b369                	j	ffffffffc020014c <cprintf>
}
ffffffffc02003c4:	7446                	ld	s0,112(sp)
ffffffffc02003c6:	70e6                	ld	ra,120(sp)
ffffffffc02003c8:	74a6                	ld	s1,104(sp)
ffffffffc02003ca:	7906                	ld	s2,96(sp)
ffffffffc02003cc:	69e6                	ld	s3,88(sp)
ffffffffc02003ce:	6a46                	ld	s4,80(sp)
ffffffffc02003d0:	6aa6                	ld	s5,72(sp)
ffffffffc02003d2:	6b06                	ld	s6,64(sp)
ffffffffc02003d4:	7be2                	ld	s7,56(sp)
ffffffffc02003d6:	7c42                	ld	s8,48(sp)
ffffffffc02003d8:	7ca2                	ld	s9,40(sp)
ffffffffc02003da:	7d02                	ld	s10,32(sp)
ffffffffc02003dc:	6de2                	ld	s11,24(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003de:	00001517          	auipc	a0,0x1
ffffffffc02003e2:	09a50513          	addi	a0,a0,154 # ffffffffc0201478 <etext+0x168>
}
ffffffffc02003e6:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003e8:	b395                	j	ffffffffc020014c <cprintf>
                int name_len = strlen(name);
ffffffffc02003ea:	8556                	mv	a0,s5
ffffffffc02003ec:	699000ef          	jal	ra,ffffffffc0201284 <strlen>
ffffffffc02003f0:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003f2:	4619                	li	a2,6
ffffffffc02003f4:	85a6                	mv	a1,s1
ffffffffc02003f6:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc02003f8:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003fa:	6df000ef          	jal	ra,ffffffffc02012d8 <strncmp>
ffffffffc02003fe:	e111                	bnez	a0,ffffffffc0200402 <dtb_init+0x1e2>
                    in_memory_node = 1;
ffffffffc0200400:	4c85                	li	s9,1
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc0200402:	0a91                	addi	s5,s5,4
ffffffffc0200404:	9ad2                	add	s5,s5,s4
ffffffffc0200406:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc020040a:	8a56                	mv	s4,s5
ffffffffc020040c:	bf2d                	j	ffffffffc0200346 <dtb_init+0x126>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc020040e:	004a2783          	lw	a5,4(s4)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200412:	00ca0693          	addi	a3,s4,12
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200416:	0087d71b          	srliw	a4,a5,0x8
ffffffffc020041a:	01879a9b          	slliw	s5,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020041e:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200422:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200426:	0107d79b          	srliw	a5,a5,0x10
ffffffffc020042a:	00caeab3          	or	s5,s5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020042e:	01877733          	and	a4,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200432:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200436:	00eaeab3          	or	s5,s5,a4
ffffffffc020043a:	00fb77b3          	and	a5,s6,a5
ffffffffc020043e:	00faeab3          	or	s5,s5,a5
ffffffffc0200442:	2a81                	sext.w	s5,s5
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200444:	000c9c63          	bnez	s9,ffffffffc020045c <dtb_init+0x23c>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc0200448:	1a82                	slli	s5,s5,0x20
ffffffffc020044a:	00368793          	addi	a5,a3,3
ffffffffc020044e:	020ada93          	srli	s5,s5,0x20
ffffffffc0200452:	9abe                	add	s5,s5,a5
ffffffffc0200454:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc0200458:	8a56                	mv	s4,s5
ffffffffc020045a:	b5f5                	j	ffffffffc0200346 <dtb_init+0x126>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc020045c:	008a2783          	lw	a5,8(s4)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200460:	85ca                	mv	a1,s2
ffffffffc0200462:	e436                	sd	a3,8(sp)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200464:	0087d51b          	srliw	a0,a5,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200468:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020046c:	0187971b          	slliw	a4,a5,0x18
ffffffffc0200470:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200474:	0107d79b          	srliw	a5,a5,0x10
ffffffffc0200478:	8f51                	or	a4,a4,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020047a:	01857533          	and	a0,a0,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020047e:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200482:	8d59                	or	a0,a0,a4
ffffffffc0200484:	00fb77b3          	and	a5,s6,a5
ffffffffc0200488:	8d5d                	or	a0,a0,a5
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc020048a:	1502                	slli	a0,a0,0x20
ffffffffc020048c:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020048e:	9522                	add	a0,a0,s0
ffffffffc0200490:	62b000ef          	jal	ra,ffffffffc02012ba <strcmp>
ffffffffc0200494:	66a2                	ld	a3,8(sp)
ffffffffc0200496:	f94d                	bnez	a0,ffffffffc0200448 <dtb_init+0x228>
ffffffffc0200498:	fb59f8e3          	bgeu	s3,s5,ffffffffc0200448 <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc020049c:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02004a0:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc02004a4:	00001517          	auipc	a0,0x1
ffffffffc02004a8:	00c50513          	addi	a0,a0,12 # ffffffffc02014b0 <etext+0x1a0>
           fdt32_to_cpu(x >> 32);
ffffffffc02004ac:	4207d613          	srai	a2,a5,0x20
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004b0:	0087d31b          	srliw	t1,a5,0x8
           fdt32_to_cpu(x >> 32);
ffffffffc02004b4:	42075593          	srai	a1,a4,0x20
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004b8:	0187de1b          	srliw	t3,a5,0x18
ffffffffc02004bc:	0186581b          	srliw	a6,a2,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c0:	0187941b          	slliw	s0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004c4:	0107d89b          	srliw	a7,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c8:	0187d693          	srli	a3,a5,0x18
ffffffffc02004cc:	01861f1b          	slliw	t5,a2,0x18
ffffffffc02004d0:	0087579b          	srliw	a5,a4,0x8
ffffffffc02004d4:	0103131b          	slliw	t1,t1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004d8:	0106561b          	srliw	a2,a2,0x10
ffffffffc02004dc:	010f6f33          	or	t5,t5,a6
ffffffffc02004e0:	0187529b          	srliw	t0,a4,0x18
ffffffffc02004e4:	0185df9b          	srliw	t6,a1,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004e8:	01837333          	and	t1,t1,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004ec:	01c46433          	or	s0,s0,t3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004f0:	0186f6b3          	and	a3,a3,s8
ffffffffc02004f4:	01859e1b          	slliw	t3,a1,0x18
ffffffffc02004f8:	01871e9b          	slliw	t4,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004fc:	0107581b          	srliw	a6,a4,0x10
ffffffffc0200500:	0086161b          	slliw	a2,a2,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200504:	8361                	srli	a4,a4,0x18
ffffffffc0200506:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020050a:	0105d59b          	srliw	a1,a1,0x10
ffffffffc020050e:	01e6e6b3          	or	a3,a3,t5
ffffffffc0200512:	00cb7633          	and	a2,s6,a2
ffffffffc0200516:	0088181b          	slliw	a6,a6,0x8
ffffffffc020051a:	0085959b          	slliw	a1,a1,0x8
ffffffffc020051e:	00646433          	or	s0,s0,t1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200522:	0187f7b3          	and	a5,a5,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200526:	01fe6333          	or	t1,t3,t6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020052a:	01877c33          	and	s8,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020052e:	0088989b          	slliw	a7,a7,0x8
ffffffffc0200532:	011b78b3          	and	a7,s6,a7
ffffffffc0200536:	005eeeb3          	or	t4,t4,t0
ffffffffc020053a:	00c6e733          	or	a4,a3,a2
ffffffffc020053e:	006c6c33          	or	s8,s8,t1
ffffffffc0200542:	010b76b3          	and	a3,s6,a6
ffffffffc0200546:	00bb7b33          	and	s6,s6,a1
ffffffffc020054a:	01d7e7b3          	or	a5,a5,t4
ffffffffc020054e:	016c6b33          	or	s6,s8,s6
ffffffffc0200552:	01146433          	or	s0,s0,a7
ffffffffc0200556:	8fd5                	or	a5,a5,a3
           fdt32_to_cpu(x >> 32);
ffffffffc0200558:	1702                	slli	a4,a4,0x20
ffffffffc020055a:	1b02                	slli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc020055c:	1782                	slli	a5,a5,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc020055e:	9301                	srli	a4,a4,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200560:	1402                	slli	s0,s0,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc0200562:	020b5b13          	srli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200566:	0167eb33          	or	s6,a5,s6
ffffffffc020056a:	8c59                	or	s0,s0,a4
        cprintf("Physical Memory from DTB:\n");
ffffffffc020056c:	be1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc0200570:	85a2                	mv	a1,s0
ffffffffc0200572:	00001517          	auipc	a0,0x1
ffffffffc0200576:	f5e50513          	addi	a0,a0,-162 # ffffffffc02014d0 <etext+0x1c0>
ffffffffc020057a:	bd3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc020057e:	014b5613          	srli	a2,s6,0x14
ffffffffc0200582:	85da                	mv	a1,s6
ffffffffc0200584:	00001517          	auipc	a0,0x1
ffffffffc0200588:	f6450513          	addi	a0,a0,-156 # ffffffffc02014e8 <etext+0x1d8>
ffffffffc020058c:	bc1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200590:	008b05b3          	add	a1,s6,s0
ffffffffc0200594:	15fd                	addi	a1,a1,-1
ffffffffc0200596:	00001517          	auipc	a0,0x1
ffffffffc020059a:	f7250513          	addi	a0,a0,-142 # ffffffffc0201508 <etext+0x1f8>
ffffffffc020059e:	bafff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB init completed\n");
ffffffffc02005a2:	00001517          	auipc	a0,0x1
ffffffffc02005a6:	fb650513          	addi	a0,a0,-74 # ffffffffc0201558 <etext+0x248>
        memory_base = mem_base;
ffffffffc02005aa:	00005797          	auipc	a5,0x5
ffffffffc02005ae:	cc87b723          	sd	s0,-818(a5) # ffffffffc0205278 <memory_base>
        memory_size = mem_size;
ffffffffc02005b2:	00005797          	auipc	a5,0x5
ffffffffc02005b6:	cd67b723          	sd	s6,-818(a5) # ffffffffc0205280 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc02005ba:	b3f5                	j	ffffffffc02003a6 <dtb_init+0x186>

ffffffffc02005bc <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc02005bc:	00005517          	auipc	a0,0x5
ffffffffc02005c0:	cbc53503          	ld	a0,-836(a0) # ffffffffc0205278 <memory_base>
ffffffffc02005c4:	8082                	ret

ffffffffc02005c6 <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc02005c6:	00005517          	auipc	a0,0x5
ffffffffc02005ca:	cba53503          	ld	a0,-838(a0) # ffffffffc0205280 <memory_size>
ffffffffc02005ce:	8082                	ret

ffffffffc02005d0 <pmm_init>:

static void check_alloc_page(void);

// init_pmm_manager - initialize a pmm_manager instance
static void init_pmm_manager(void) {
    pmm_manager = &slub_pmm_manager;
ffffffffc02005d0:	00001797          	auipc	a5,0x1
ffffffffc02005d4:	1b078793          	addi	a5,a5,432 # ffffffffc0201780 <slub_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02005d8:	638c                	ld	a1,0(a5)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
    }
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc02005da:	7179                	addi	sp,sp,-48
ffffffffc02005dc:	f022                	sd	s0,32(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02005de:	00001517          	auipc	a0,0x1
ffffffffc02005e2:	f9250513          	addi	a0,a0,-110 # ffffffffc0201570 <etext+0x260>
    pmm_manager = &slub_pmm_manager;
ffffffffc02005e6:	00005417          	auipc	s0,0x5
ffffffffc02005ea:	cb240413          	addi	s0,s0,-846 # ffffffffc0205298 <pmm_manager>
void pmm_init(void) {
ffffffffc02005ee:	f406                	sd	ra,40(sp)
ffffffffc02005f0:	ec26                	sd	s1,24(sp)
ffffffffc02005f2:	e44e                	sd	s3,8(sp)
ffffffffc02005f4:	e84a                	sd	s2,16(sp)
ffffffffc02005f6:	e052                	sd	s4,0(sp)
    pmm_manager = &slub_pmm_manager;
ffffffffc02005f8:	e01c                	sd	a5,0(s0)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02005fa:	b53ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    pmm_manager->init();
ffffffffc02005fe:	601c                	ld	a5,0(s0)
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200600:	00005497          	auipc	s1,0x5
ffffffffc0200604:	cb048493          	addi	s1,s1,-848 # ffffffffc02052b0 <va_pa_offset>
    pmm_manager->init();
ffffffffc0200608:	679c                	ld	a5,8(a5)
ffffffffc020060a:	9782                	jalr	a5
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc020060c:	57f5                	li	a5,-3
ffffffffc020060e:	07fa                	slli	a5,a5,0x1e
ffffffffc0200610:	e09c                	sd	a5,0(s1)
    uint64_t mem_begin = get_memory_base();
ffffffffc0200612:	fabff0ef          	jal	ra,ffffffffc02005bc <get_memory_base>
ffffffffc0200616:	89aa                	mv	s3,a0
    uint64_t mem_size  = get_memory_size();
ffffffffc0200618:	fafff0ef          	jal	ra,ffffffffc02005c6 <get_memory_size>
    if (mem_size == 0) {
ffffffffc020061c:	14050c63          	beqz	a0,ffffffffc0200774 <pmm_init+0x1a4>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc0200620:	892a                	mv	s2,a0
    cprintf("physcial memory map:\n");
ffffffffc0200622:	00001517          	auipc	a0,0x1
ffffffffc0200626:	f9650513          	addi	a0,a0,-106 # ffffffffc02015b8 <etext+0x2a8>
ffffffffc020062a:	b23ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc020062e:	01298a33          	add	s4,s3,s2
    cprintf("  memory: 0x%016lx, [0x%016lx, 0x%016lx].\n", mem_size, mem_begin,
ffffffffc0200632:	864e                	mv	a2,s3
ffffffffc0200634:	fffa0693          	addi	a3,s4,-1
ffffffffc0200638:	85ca                	mv	a1,s2
ffffffffc020063a:	00001517          	auipc	a0,0x1
ffffffffc020063e:	f9650513          	addi	a0,a0,-106 # ffffffffc02015d0 <etext+0x2c0>
ffffffffc0200642:	b0bff0ef          	jal	ra,ffffffffc020014c <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc0200646:	c80007b7          	lui	a5,0xc8000
ffffffffc020064a:	8652                	mv	a2,s4
ffffffffc020064c:	0d47e363          	bltu	a5,s4,ffffffffc0200712 <pmm_init+0x142>
ffffffffc0200650:	00006797          	auipc	a5,0x6
ffffffffc0200654:	c6b78793          	addi	a5,a5,-917 # ffffffffc02062bb <end+0xfff>
ffffffffc0200658:	757d                	lui	a0,0xfffff
ffffffffc020065a:	8d7d                	and	a0,a0,a5
ffffffffc020065c:	8231                	srli	a2,a2,0xc
ffffffffc020065e:	00005797          	auipc	a5,0x5
ffffffffc0200662:	c2c7b523          	sd	a2,-982(a5) # ffffffffc0205288 <npage>
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);
ffffffffc0200666:	00005797          	auipc	a5,0x5
ffffffffc020066a:	c2a7b523          	sd	a0,-982(a5) # ffffffffc0205290 <pages>
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc020066e:	000807b7          	lui	a5,0x80
ffffffffc0200672:	002005b7          	lui	a1,0x200
ffffffffc0200676:	02f60563          	beq	a2,a5,ffffffffc02006a0 <pmm_init+0xd0>
ffffffffc020067a:	00261593          	slli	a1,a2,0x2
ffffffffc020067e:	00c586b3          	add	a3,a1,a2
ffffffffc0200682:	fec007b7          	lui	a5,0xfec00
ffffffffc0200686:	97aa                	add	a5,a5,a0
ffffffffc0200688:	068e                	slli	a3,a3,0x3
ffffffffc020068a:	96be                	add	a3,a3,a5
ffffffffc020068c:	87aa                	mv	a5,a0
        SetPageReserved(pages + i);
ffffffffc020068e:	6798                	ld	a4,8(a5)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc0200690:	02878793          	addi	a5,a5,40 # fffffffffec00028 <end+0x3e9fad6c>
        SetPageReserved(pages + i);
ffffffffc0200694:	00176713          	ori	a4,a4,1
ffffffffc0200698:	fee7b023          	sd	a4,-32(a5)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc020069c:	fef699e3          	bne	a3,a5,ffffffffc020068e <pmm_init+0xbe>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc02006a0:	95b2                	add	a1,a1,a2
ffffffffc02006a2:	fec006b7          	lui	a3,0xfec00
ffffffffc02006a6:	96aa                	add	a3,a3,a0
ffffffffc02006a8:	058e                	slli	a1,a1,0x3
ffffffffc02006aa:	96ae                	add	a3,a3,a1
ffffffffc02006ac:	c02007b7          	lui	a5,0xc0200
ffffffffc02006b0:	0af6e663          	bltu	a3,a5,ffffffffc020075c <pmm_init+0x18c>
ffffffffc02006b4:	6098                	ld	a4,0(s1)
    mem_end = ROUNDDOWN(mem_end, PGSIZE);
ffffffffc02006b6:	77fd                	lui	a5,0xfffff
ffffffffc02006b8:	00fa75b3          	and	a1,s4,a5
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc02006bc:	8e99                	sub	a3,a3,a4
    if (freemem < mem_end) {
ffffffffc02006be:	04b6ed63          	bltu	a3,a1,ffffffffc0200718 <pmm_init+0x148>
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc02006c2:	601c                	ld	a5,0(s0)
ffffffffc02006c4:	7b9c                	ld	a5,48(a5)
ffffffffc02006c6:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc02006c8:	00001517          	auipc	a0,0x1
ffffffffc02006cc:	f9050513          	addi	a0,a0,-112 # ffffffffc0201658 <etext+0x348>
ffffffffc02006d0:	a7dff0ef          	jal	ra,ffffffffc020014c <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc02006d4:	00004597          	auipc	a1,0x4
ffffffffc02006d8:	92c58593          	addi	a1,a1,-1748 # ffffffffc0204000 <boot_page_table_sv39>
ffffffffc02006dc:	00005797          	auipc	a5,0x5
ffffffffc02006e0:	bcb7b623          	sd	a1,-1076(a5) # ffffffffc02052a8 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc02006e4:	c02007b7          	lui	a5,0xc0200
ffffffffc02006e8:	0af5e263          	bltu	a1,a5,ffffffffc020078c <pmm_init+0x1bc>
ffffffffc02006ec:	6090                	ld	a2,0(s1)
}
ffffffffc02006ee:	7402                	ld	s0,32(sp)
ffffffffc02006f0:	70a2                	ld	ra,40(sp)
ffffffffc02006f2:	64e2                	ld	s1,24(sp)
ffffffffc02006f4:	6942                	ld	s2,16(sp)
ffffffffc02006f6:	69a2                	ld	s3,8(sp)
ffffffffc02006f8:	6a02                	ld	s4,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc02006fa:	40c58633          	sub	a2,a1,a2
ffffffffc02006fe:	00005797          	auipc	a5,0x5
ffffffffc0200702:	bac7b123          	sd	a2,-1118(a5) # ffffffffc02052a0 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0200706:	00001517          	auipc	a0,0x1
ffffffffc020070a:	f7250513          	addi	a0,a0,-142 # ffffffffc0201678 <etext+0x368>
}
ffffffffc020070e:	6145                	addi	sp,sp,48
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0200710:	bc35                	j	ffffffffc020014c <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc0200712:	c8000637          	lui	a2,0xc8000
ffffffffc0200716:	bf2d                	j	ffffffffc0200650 <pmm_init+0x80>
    mem_begin = ROUNDUP(freemem, PGSIZE);
ffffffffc0200718:	6705                	lui	a4,0x1
ffffffffc020071a:	177d                	addi	a4,a4,-1
ffffffffc020071c:	96ba                	add	a3,a3,a4
ffffffffc020071e:	8efd                	and	a3,a3,a5
static inline int page_ref_dec(struct Page *page) {
    page->ref -= 1;
    return page->ref;
}
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc0200720:	00c6d793          	srli	a5,a3,0xc
ffffffffc0200724:	02c7f063          	bgeu	a5,a2,ffffffffc0200744 <pmm_init+0x174>
    pmm_manager->init_memmap(base, n);
ffffffffc0200728:	6010                	ld	a2,0(s0)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc020072a:	fff80737          	lui	a4,0xfff80
ffffffffc020072e:	973e                	add	a4,a4,a5
ffffffffc0200730:	00271793          	slli	a5,a4,0x2
ffffffffc0200734:	97ba                	add	a5,a5,a4
ffffffffc0200736:	6a18                	ld	a4,16(a2)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
ffffffffc0200738:	8d95                	sub	a1,a1,a3
ffffffffc020073a:	078e                	slli	a5,a5,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc020073c:	81b1                	srli	a1,a1,0xc
ffffffffc020073e:	953e                	add	a0,a0,a5
ffffffffc0200740:	9702                	jalr	a4
}
ffffffffc0200742:	b741                	j	ffffffffc02006c2 <pmm_init+0xf2>
        panic("pa2page called with invalid pa");
ffffffffc0200744:	00001617          	auipc	a2,0x1
ffffffffc0200748:	ee460613          	addi	a2,a2,-284 # ffffffffc0201628 <etext+0x318>
ffffffffc020074c:	06a00593          	li	a1,106
ffffffffc0200750:	00001517          	auipc	a0,0x1
ffffffffc0200754:	ef850513          	addi	a0,a0,-264 # ffffffffc0201648 <etext+0x338>
ffffffffc0200758:	a6bff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc020075c:	00001617          	auipc	a2,0x1
ffffffffc0200760:	ea460613          	addi	a2,a2,-348 # ffffffffc0201600 <etext+0x2f0>
ffffffffc0200764:	05f00593          	li	a1,95
ffffffffc0200768:	00001517          	auipc	a0,0x1
ffffffffc020076c:	e4050513          	addi	a0,a0,-448 # ffffffffc02015a8 <etext+0x298>
ffffffffc0200770:	a53ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("DTB memory info not available");
ffffffffc0200774:	00001617          	auipc	a2,0x1
ffffffffc0200778:	e1460613          	addi	a2,a2,-492 # ffffffffc0201588 <etext+0x278>
ffffffffc020077c:	04700593          	li	a1,71
ffffffffc0200780:	00001517          	auipc	a0,0x1
ffffffffc0200784:	e2850513          	addi	a0,a0,-472 # ffffffffc02015a8 <etext+0x298>
ffffffffc0200788:	a3bff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc020078c:	86ae                	mv	a3,a1
ffffffffc020078e:	00001617          	auipc	a2,0x1
ffffffffc0200792:	e7260613          	addi	a2,a2,-398 # ffffffffc0201600 <etext+0x2f0>
ffffffffc0200796:	07a00593          	li	a1,122
ffffffffc020079a:	00001517          	auipc	a0,0x1
ffffffffc020079e:	e0e50513          	addi	a0,a0,-498 # ffffffffc02015a8 <etext+0x298>
ffffffffc02007a2:	a21ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc02007a6 <slub_init>:
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc02007a6:	00005797          	auipc	a5,0x5
ffffffffc02007aa:	ab278793          	addi	a5,a5,-1358 # ffffffffc0205258 <slub_free_area>
ffffffffc02007ae:	e79c                	sd	a5,8(a5)
ffffffffc02007b0:	e39c                	sd	a5,0(a5)
#define slub_free_list (slub_free_area.free_list)
#define slub_nr_free   (slub_free_area.nr_free)

static void slub_page_list_init(void) {
    list_init(&slub_free_list);
    slub_nr_free = 0;
ffffffffc02007b2:	00005797          	auipc	a5,0x5
ffffffffc02007b6:	aa07ab23          	sw	zero,-1354(a5) # ffffffffc0205268 <slub_free_area+0x10>

static void slub_init(void) {
    // init page free area list
    slub_page_list_init();
    // init caches
    for (size_t i = 0; i < SLUB_NUM_CLASSES; i++) {
ffffffffc02007ba:	00005797          	auipc	a5,0x5
ffffffffc02007be:	87678793          	addi	a5,a5,-1930 # ffffffffc0205030 <slub_caches+0x18>
ffffffffc02007c2:	00001617          	auipc	a2,0x1
ffffffffc02007c6:	ff660613          	addi	a2,a2,-10 # ffffffffc02017b8 <slub_size_classes>
ffffffffc02007ca:	00005897          	auipc	a7,0x5
ffffffffc02007ce:	aa688893          	addi	a7,a7,-1370 # ffffffffc0205270 <is_panic>
    slub_nr_free = 0;
ffffffffc02007d2:	46c1                	li	a3,16
    c->align = sizeof(void *);
ffffffffc02007d4:	4821                	li	a6,8
ffffffffc02007d6:	a011                	j	ffffffffc02007da <slub_init+0x34>
        cache_init(&slub_caches[i], slub_size_classes[i]);
ffffffffc02007d8:	6214                	ld	a3,0(a2)
static inline size_t align_up(size_t x, size_t a) { return (x + a - 1) & ~(a - 1); }
ffffffffc02007da:	00768713          	addi	a4,a3,7 # fffffffffec00007 <end+0x3e9fad4b>
ffffffffc02007de:	01078513          	addi	a0,a5,16
ffffffffc02007e2:	02078593          	addi	a1,a5,32
ffffffffc02007e6:	9b61                	andi	a4,a4,-8
    c->obj_size = size;
ffffffffc02007e8:	fed7b423          	sd	a3,-24(a5)
    c->align = sizeof(void *);
ffffffffc02007ec:	ff07b823          	sd	a6,-16(a5)
    c->obj_stride = align_up(c->obj_size, c->align);
ffffffffc02007f0:	fee7bc23          	sd	a4,-8(a5)
ffffffffc02007f4:	e79c                	sd	a5,8(a5)
ffffffffc02007f6:	e39c                	sd	a5,0(a5)
ffffffffc02007f8:	ef88                	sd	a0,24(a5)
ffffffffc02007fa:	eb88                	sd	a0,16(a5)
ffffffffc02007fc:	f78c                	sd	a1,40(a5)
ffffffffc02007fe:	f38c                	sd	a1,32(a5)
    for (size_t i = 0; i < SLUB_NUM_CLASSES; i++) {
ffffffffc0200800:	04878793          	addi	a5,a5,72
ffffffffc0200804:	0621                	addi	a2,a2,8
ffffffffc0200806:	fd1799e3          	bne	a5,a7,ffffffffc02007d8 <slub_init+0x32>
    }
    slub_inited = 1;
ffffffffc020080a:	4785                	li	a5,1
ffffffffc020080c:	00005717          	auipc	a4,0x5
ffffffffc0200810:	aaf72623          	sw	a5,-1364(a4) # ffffffffc02052b8 <slub_inited>
}
ffffffffc0200814:	8082                	ret

ffffffffc0200816 <slub_nr_free_pages_iface>:

static void slub_free_pages_iface(struct Page *base, size_t n) {
    slub_page_free_pages(base, n);
}

static size_t slub_nr_free_pages_iface(void) { return slub_page_nr_free_pages(); }
ffffffffc0200816:	00005517          	auipc	a0,0x5
ffffffffc020081a:	a5256503          	lwu	a0,-1454(a0) # ffffffffc0205268 <slub_free_area+0x10>
ffffffffc020081e:	8082                	ret

ffffffffc0200820 <slub_page_alloc_pages>:
    assert(n > 0);
ffffffffc0200820:	cd4d                	beqz	a0,ffffffffc02008da <slub_page_alloc_pages+0xba>
    if (n > slub_nr_free) return NULL;
ffffffffc0200822:	00005697          	auipc	a3,0x5
ffffffffc0200826:	a3668693          	addi	a3,a3,-1482 # ffffffffc0205258 <slub_free_area>
ffffffffc020082a:	0106a803          	lw	a6,16(a3)
ffffffffc020082e:	862a                	mv	a2,a0
ffffffffc0200830:	02081793          	slli	a5,a6,0x20
ffffffffc0200834:	9381                	srli	a5,a5,0x20
ffffffffc0200836:	08a7e963          	bltu	a5,a0,ffffffffc02008c8 <slub_page_alloc_pages+0xa8>
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc020083a:	669c                	ld	a5,8(a3)
    while ((le = list_next(le)) != &slub_free_list) {
ffffffffc020083c:	08d78663          	beq	a5,a3,ffffffffc02008c8 <slub_page_alloc_pages+0xa8>
    size_t best_size = (size_t)-1;
ffffffffc0200840:	55fd                	li	a1,-1
    struct Page *best = NULL;
ffffffffc0200842:	4501                	li	a0,0
        if (PageProperty(p) && p->property >= n && p->property < best_size) {
ffffffffc0200844:	ff07b703          	ld	a4,-16(a5)
ffffffffc0200848:	8b09                	andi	a4,a4,2
ffffffffc020084a:	cf01                	beqz	a4,ffffffffc0200862 <slub_page_alloc_pages+0x42>
ffffffffc020084c:	ff87e703          	lwu	a4,-8(a5)
ffffffffc0200850:	00c76963          	bltu	a4,a2,ffffffffc0200862 <slub_page_alloc_pages+0x42>
ffffffffc0200854:	00b77763          	bgeu	a4,a1,ffffffffc0200862 <slub_page_alloc_pages+0x42>
        struct Page *p = le2page(le, page_link);
ffffffffc0200858:	fe878513          	addi	a0,a5,-24
            if (best_size == n) break; // exact fit
ffffffffc020085c:	06c70863          	beq	a4,a2,ffffffffc02008cc <slub_page_alloc_pages+0xac>
ffffffffc0200860:	85ba                	mv	a1,a4
ffffffffc0200862:	679c                	ld	a5,8(a5)
    while ((le = list_next(le)) != &slub_free_list) {
ffffffffc0200864:	fed790e3          	bne	a5,a3,ffffffffc0200844 <slub_page_alloc_pages+0x24>
    if (best == NULL) return NULL;
ffffffffc0200868:	cd39                	beqz	a0,ffffffffc02008c6 <slub_page_alloc_pages+0xa6>
    __list_del(listelm->prev, listelm->next);
ffffffffc020086a:	01853883          	ld	a7,24(a0)
ffffffffc020086e:	7118                	ld	a4,32(a0)
        rem->property = best_size - n;
ffffffffc0200870:	0006031b          	sext.w	t1,a2
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc0200874:	00e8b423          	sd	a4,8(a7)
    next->prev = prev;
ffffffffc0200878:	01173023          	sd	a7,0(a4)
    if (best_size > n) {
ffffffffc020087c:	02b67d63          	bgeu	a2,a1,ffffffffc02008b6 <slub_page_alloc_pages+0x96>
        struct Page *rem = best + n;
ffffffffc0200880:	00261713          	slli	a4,a2,0x2
ffffffffc0200884:	9732                	add	a4,a4,a2
ffffffffc0200886:	070e                	slli	a4,a4,0x3
ffffffffc0200888:	972a                	add	a4,a4,a0
        SetPageProperty(rem);
ffffffffc020088a:	6710                	ld	a2,8(a4)
        rem->property = best_size - n;
ffffffffc020088c:	406585bb          	subw	a1,a1,t1
ffffffffc0200890:	cb0c                	sw	a1,16(a4)
        SetPageProperty(rem);
ffffffffc0200892:	00266613          	ori	a2,a2,2
ffffffffc0200896:	e710                	sd	a2,8(a4)
        while ((pos = list_next(pos)) != &slub_free_list) {
ffffffffc0200898:	a029                	j	ffffffffc02008a2 <slub_page_alloc_pages+0x82>
            if (le2page(pos, page_link) > rem) break;
ffffffffc020089a:	fe878613          	addi	a2,a5,-24
ffffffffc020089e:	00c76563          	bltu	a4,a2,ffffffffc02008a8 <slub_page_alloc_pages+0x88>
    return listelm->next;
ffffffffc02008a2:	679c                	ld	a5,8(a5)
        while ((pos = list_next(pos)) != &slub_free_list) {
ffffffffc02008a4:	fed79be3          	bne	a5,a3,ffffffffc020089a <slub_page_alloc_pages+0x7a>
    __list_add(elm, listelm->prev, listelm);
ffffffffc02008a8:	6390                	ld	a2,0(a5)
        list_add_before(pos, &(rem->page_link));
ffffffffc02008aa:	01870593          	addi	a1,a4,24
    prev->next = next->prev = elm;
ffffffffc02008ae:	e38c                	sd	a1,0(a5)
ffffffffc02008b0:	e60c                	sd	a1,8(a2)
    elm->next = next;
ffffffffc02008b2:	f31c                	sd	a5,32(a4)
    elm->prev = prev;
ffffffffc02008b4:	ef10                	sd	a2,24(a4)
    ClearPageProperty(best);
ffffffffc02008b6:	651c                	ld	a5,8(a0)
    slub_nr_free -= n;
ffffffffc02008b8:	4068083b          	subw	a6,a6,t1
    ClearPageProperty(best);
ffffffffc02008bc:	9bf5                	andi	a5,a5,-3
ffffffffc02008be:	e51c                	sd	a5,8(a0)
    slub_nr_free -= n;
ffffffffc02008c0:	0106a823          	sw	a6,16(a3)
    return best;
ffffffffc02008c4:	8082                	ret
}
ffffffffc02008c6:	8082                	ret
    if (n > slub_nr_free) return NULL;
ffffffffc02008c8:	4501                	li	a0,0
ffffffffc02008ca:	8082                	ret
    __list_del(listelm->prev, listelm->next);
ffffffffc02008cc:	6398                	ld	a4,0(a5)
ffffffffc02008ce:	679c                	ld	a5,8(a5)
        rem->property = best_size - n;
ffffffffc02008d0:	0006031b          	sext.w	t1,a2
    prev->next = next;
ffffffffc02008d4:	e71c                	sd	a5,8(a4)
    next->prev = prev;
ffffffffc02008d6:	e398                	sd	a4,0(a5)
    if (best_size > n) {
ffffffffc02008d8:	bff9                	j	ffffffffc02008b6 <slub_page_alloc_pages+0x96>
static struct Page *slub_page_alloc_pages(size_t n) {
ffffffffc02008da:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc02008dc:	00001697          	auipc	a3,0x1
ffffffffc02008e0:	ddc68693          	addi	a3,a3,-548 # ffffffffc02016b8 <etext+0x3a8>
ffffffffc02008e4:	00001617          	auipc	a2,0x1
ffffffffc02008e8:	ddc60613          	addi	a2,a2,-548 # ffffffffc02016c0 <etext+0x3b0>
ffffffffc02008ec:	04500593          	li	a1,69
ffffffffc02008f0:	00001517          	auipc	a0,0x1
ffffffffc02008f4:	de850513          	addi	a0,a0,-536 # ffffffffc02016d8 <etext+0x3c8>
static struct Page *slub_page_alloc_pages(size_t n) {
ffffffffc02008f8:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc02008fa:	8c9ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc02008fe <slub_alloc_pages_iface>:
    return slub_page_alloc_pages(n);
ffffffffc02008fe:	b70d                	j	ffffffffc0200820 <slub_page_alloc_pages>

ffffffffc0200900 <slub_init_memmap>:
static void slub_init_memmap(struct Page *base, size_t n) {
ffffffffc0200900:	1141                	addi	sp,sp,-16
ffffffffc0200902:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200904:	cdd1                	beqz	a1,ffffffffc02009a0 <slub_init_memmap+0xa0>
    for (; p != base + n; p++) {
ffffffffc0200906:	00259693          	slli	a3,a1,0x2
ffffffffc020090a:	96ae                	add	a3,a3,a1
ffffffffc020090c:	068e                	slli	a3,a3,0x3
ffffffffc020090e:	96aa                	add	a3,a3,a0
ffffffffc0200910:	87aa                	mv	a5,a0
ffffffffc0200912:	00d50f63          	beq	a0,a3,ffffffffc0200930 <slub_init_memmap+0x30>
        assert(PageReserved(p));
ffffffffc0200916:	6798                	ld	a4,8(a5)
ffffffffc0200918:	8b05                	andi	a4,a4,1
ffffffffc020091a:	c33d                	beqz	a4,ffffffffc0200980 <slub_init_memmap+0x80>
        p->flags = 0;
ffffffffc020091c:	0007b423          	sd	zero,8(a5)
        p->property = 0;
ffffffffc0200920:	0007a823          	sw	zero,16(a5)
static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200924:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p++) {
ffffffffc0200928:	02878793          	addi	a5,a5,40
ffffffffc020092c:	fed795e3          	bne	a5,a3,ffffffffc0200916 <slub_init_memmap+0x16>
    SetPageProperty(base);
ffffffffc0200930:	6510                	ld	a2,8(a0)
    slub_nr_free += n;
ffffffffc0200932:	00005697          	auipc	a3,0x5
ffffffffc0200936:	92668693          	addi	a3,a3,-1754 # ffffffffc0205258 <slub_free_area>
ffffffffc020093a:	4a98                	lw	a4,16(a3)
    base->property = n;
ffffffffc020093c:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc020093e:	00266613          	ori	a2,a2,2
    return list->next == list;
ffffffffc0200942:	669c                	ld	a5,8(a3)
    base->property = n;
ffffffffc0200944:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc0200946:	e510                	sd	a2,8(a0)
    slub_nr_free += n;
ffffffffc0200948:	9db9                	addw	a1,a1,a4
ffffffffc020094a:	ca8c                	sw	a1,16(a3)
        list_add(&slub_free_list, &(base->page_link));
ffffffffc020094c:	01850613          	addi	a2,a0,24
    if (list_empty(&slub_free_list)) {
ffffffffc0200950:	02d78163          	beq	a5,a3,ffffffffc0200972 <slub_init_memmap+0x72>
            if (le2page(le, page_link) > base) {
ffffffffc0200954:	fe878713          	addi	a4,a5,-24
ffffffffc0200958:	00e56563          	bltu	a0,a4,ffffffffc0200962 <slub_init_memmap+0x62>
    return listelm->next;
ffffffffc020095c:	679c                	ld	a5,8(a5)
        while ((le = list_next(le)) != &slub_free_list) {
ffffffffc020095e:	fed79be3          	bne	a5,a3,ffffffffc0200954 <slub_init_memmap+0x54>
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200962:	6398                	ld	a4,0(a5)
}
ffffffffc0200964:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc0200966:	e390                	sd	a2,0(a5)
ffffffffc0200968:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc020096a:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc020096c:	ed18                	sd	a4,24(a0)
ffffffffc020096e:	0141                	addi	sp,sp,16
ffffffffc0200970:	8082                	ret
ffffffffc0200972:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc0200974:	e390                	sd	a2,0(a5)
ffffffffc0200976:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200978:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc020097a:	ed1c                	sd	a5,24(a0)
ffffffffc020097c:	0141                	addi	sp,sp,16
ffffffffc020097e:	8082                	ret
        assert(PageReserved(p));
ffffffffc0200980:	00001697          	auipc	a3,0x1
ffffffffc0200984:	d7068693          	addi	a3,a3,-656 # ffffffffc02016f0 <etext+0x3e0>
ffffffffc0200988:	00001617          	auipc	a2,0x1
ffffffffc020098c:	d3860613          	addi	a2,a2,-712 # ffffffffc02016c0 <etext+0x3b0>
ffffffffc0200990:	02d00593          	li	a1,45
ffffffffc0200994:	00001517          	auipc	a0,0x1
ffffffffc0200998:	d4450513          	addi	a0,a0,-700 # ffffffffc02016d8 <etext+0x3c8>
ffffffffc020099c:	827ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc02009a0:	00001697          	auipc	a3,0x1
ffffffffc02009a4:	d1868693          	addi	a3,a3,-744 # ffffffffc02016b8 <etext+0x3a8>
ffffffffc02009a8:	00001617          	auipc	a2,0x1
ffffffffc02009ac:	d1860613          	addi	a2,a2,-744 # ffffffffc02016c0 <etext+0x3b0>
ffffffffc02009b0:	02a00593          	li	a1,42
ffffffffc02009b4:	00001517          	auipc	a0,0x1
ffffffffc02009b8:	d2450513          	addi	a0,a0,-732 # ffffffffc02016d8 <etext+0x3c8>
ffffffffc02009bc:	807ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc02009c0 <slub_page_free_pages.part.0>:
    for (; p != base + n; p++) {
ffffffffc02009c0:	00259793          	slli	a5,a1,0x2
ffffffffc02009c4:	97ae                	add	a5,a5,a1
ffffffffc02009c6:	078e                	slli	a5,a5,0x3
ffffffffc02009c8:	00f506b3          	add	a3,a0,a5
ffffffffc02009cc:	87aa                	mv	a5,a0
ffffffffc02009ce:	00d50d63          	beq	a0,a3,ffffffffc02009e8 <slub_page_free_pages.part.0+0x28>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc02009d2:	6798                	ld	a4,8(a5)
ffffffffc02009d4:	8b0d                	andi	a4,a4,3
ffffffffc02009d6:	e769                	bnez	a4,ffffffffc0200aa0 <slub_page_free_pages.part.0+0xe0>
        p->flags = 0;
ffffffffc02009d8:	0007b423          	sd	zero,8(a5)
ffffffffc02009dc:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p++) {
ffffffffc02009e0:	02878793          	addi	a5,a5,40
ffffffffc02009e4:	fed797e3          	bne	a5,a3,ffffffffc02009d2 <slub_page_free_pages.part.0+0x12>
    SetPageProperty(base);
ffffffffc02009e8:	6518                	ld	a4,8(a0)
    slub_nr_free += n;
ffffffffc02009ea:	00005697          	auipc	a3,0x5
ffffffffc02009ee:	86e68693          	addi	a3,a3,-1938 # ffffffffc0205258 <slub_free_area>
ffffffffc02009f2:	4a9c                	lw	a5,16(a3)
    base->property = n;
ffffffffc02009f4:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc02009f6:	00276713          	ori	a4,a4,2
    slub_nr_free += n;
ffffffffc02009fa:	9fad                	addw	a5,a5,a1
    base->property = n;
ffffffffc02009fc:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc02009fe:	e518                	sd	a4,8(a0)
    slub_nr_free += n;
ffffffffc0200a00:	ca9c                	sw	a5,16(a3)
    list_entry_t *le = &slub_free_list;
ffffffffc0200a02:	87b6                	mv	a5,a3
    while ((le = list_next(le)) != &slub_free_list) {
ffffffffc0200a04:	a029                	j	ffffffffc0200a0e <slub_page_free_pages.part.0+0x4e>
        if (le2page(le, page_link) > base) break;
ffffffffc0200a06:	fe878713          	addi	a4,a5,-24
ffffffffc0200a0a:	06e56e63          	bltu	a0,a4,ffffffffc0200a86 <slub_page_free_pages.part.0+0xc6>
    return listelm->next;
ffffffffc0200a0e:	679c                	ld	a5,8(a5)
    while ((le = list_next(le)) != &slub_free_list) {
ffffffffc0200a10:	fed79be3          	bne	a5,a3,ffffffffc0200a06 <slub_page_free_pages.part.0+0x46>
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200a14:	6390                	ld	a2,0(a5)
    list_add_before(le, &(base->page_link));
ffffffffc0200a16:	01850713          	addi	a4,a0,24
    prev->next = next->prev = elm;
ffffffffc0200a1a:	e398                	sd	a4,0(a5)
ffffffffc0200a1c:	e618                	sd	a4,8(a2)
    elm->next = next;
ffffffffc0200a1e:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200a20:	ed10                	sd	a2,24(a0)
    if (prev != &slub_free_list) {
ffffffffc0200a22:	06f60e63          	beq	a2,a5,ffffffffc0200a9e <slub_page_free_pages.part.0+0xde>
        if (pp + pp->property == base) {
ffffffffc0200a26:	ff862303          	lw	t1,-8(a2)
        struct Page *pp = le2page(prev, page_link);
ffffffffc0200a2a:	fe860893          	addi	a7,a2,-24
        if (pp + pp->property == base) {
ffffffffc0200a2e:	02031813          	slli	a6,t1,0x20
ffffffffc0200a32:	02085813          	srli	a6,a6,0x20
ffffffffc0200a36:	00281713          	slli	a4,a6,0x2
ffffffffc0200a3a:	9742                	add	a4,a4,a6
ffffffffc0200a3c:	070e                	slli	a4,a4,0x3
ffffffffc0200a3e:	9746                	add	a4,a4,a7
ffffffffc0200a40:	02e50b63          	beq	a0,a4,ffffffffc0200a76 <slub_page_free_pages.part.0+0xb6>
    if (next != &slub_free_list) {
ffffffffc0200a44:	00d78f63          	beq	a5,a3,ffffffffc0200a62 <slub_page_free_pages.part.0+0xa2>
ffffffffc0200a48:	fe878713          	addi	a4,a5,-24
        if (base + base->property == pn) {
ffffffffc0200a4c:	490c                	lw	a1,16(a0)
ffffffffc0200a4e:	02059613          	slli	a2,a1,0x20
ffffffffc0200a52:	9201                	srli	a2,a2,0x20
ffffffffc0200a54:	00261693          	slli	a3,a2,0x2
ffffffffc0200a58:	96b2                	add	a3,a3,a2
ffffffffc0200a5a:	068e                	slli	a3,a3,0x3
ffffffffc0200a5c:	96aa                	add	a3,a3,a0
ffffffffc0200a5e:	00d70363          	beq	a4,a3,ffffffffc0200a64 <slub_page_free_pages.part.0+0xa4>
ffffffffc0200a62:	8082                	ret
            base->property += pn->property;
ffffffffc0200a64:	ff87a703          	lw	a4,-8(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc0200a68:	6394                	ld	a3,0(a5)
ffffffffc0200a6a:	679c                	ld	a5,8(a5)
ffffffffc0200a6c:	9db9                	addw	a1,a1,a4
ffffffffc0200a6e:	c90c                	sw	a1,16(a0)
    prev->next = next;
ffffffffc0200a70:	e69c                	sd	a5,8(a3)
    next->prev = prev;
ffffffffc0200a72:	e394                	sd	a3,0(a5)
}
ffffffffc0200a74:	8082                	ret
            pp->property += base->property;
ffffffffc0200a76:	006585bb          	addw	a1,a1,t1
ffffffffc0200a7a:	feb62c23          	sw	a1,-8(a2)
    prev->next = next;
ffffffffc0200a7e:	e61c                	sd	a5,8(a2)
    next->prev = prev;
ffffffffc0200a80:	e390                	sd	a2,0(a5)
            base = pp;
ffffffffc0200a82:	8546                	mv	a0,a7
ffffffffc0200a84:	b7c1                	j	ffffffffc0200a44 <slub_page_free_pages.part.0+0x84>
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200a86:	6390                	ld	a2,0(a5)
    list_add_before(le, &(base->page_link));
ffffffffc0200a88:	01850813          	addi	a6,a0,24
    prev->next = next->prev = elm;
ffffffffc0200a8c:	0107b023          	sd	a6,0(a5)
ffffffffc0200a90:	01063423          	sd	a6,8(a2)
    elm->next = next;
ffffffffc0200a94:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200a96:	ed10                	sd	a2,24(a0)
    if (prev != &slub_free_list) {
ffffffffc0200a98:	f8d617e3          	bne	a2,a3,ffffffffc0200a26 <slub_page_free_pages.part.0+0x66>
ffffffffc0200a9c:	bf45                	j	ffffffffc0200a4c <slub_page_free_pages.part.0+0x8c>
ffffffffc0200a9e:	8082                	ret
static void slub_page_free_pages(struct Page *base, size_t n) {
ffffffffc0200aa0:	1141                	addi	sp,sp,-16
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200aa2:	00001697          	auipc	a3,0x1
ffffffffc0200aa6:	c5e68693          	addi	a3,a3,-930 # ffffffffc0201700 <etext+0x3f0>
ffffffffc0200aaa:	00001617          	auipc	a2,0x1
ffffffffc0200aae:	c1660613          	addi	a2,a2,-1002 # ffffffffc02016c0 <etext+0x3b0>
ffffffffc0200ab2:	06d00593          	li	a1,109
ffffffffc0200ab6:	00001517          	auipc	a0,0x1
ffffffffc0200aba:	c2250513          	addi	a0,a0,-990 # ffffffffc02016d8 <etext+0x3c8>
static void slub_page_free_pages(struct Page *base, size_t n) {
ffffffffc0200abe:	e406                	sd	ra,8(sp)
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200ac0:	f02ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200ac4 <slub_free_pages_iface>:
    assert(n > 0);
ffffffffc0200ac4:	c191                	beqz	a1,ffffffffc0200ac8 <slub_free_pages_iface+0x4>
ffffffffc0200ac6:	bded                	j	ffffffffc02009c0 <slub_page_free_pages.part.0>
static void slub_free_pages_iface(struct Page *base, size_t n) {
ffffffffc0200ac8:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc0200aca:	00001697          	auipc	a3,0x1
ffffffffc0200ace:	bee68693          	addi	a3,a3,-1042 # ffffffffc02016b8 <etext+0x3a8>
ffffffffc0200ad2:	00001617          	auipc	a2,0x1
ffffffffc0200ad6:	bee60613          	addi	a2,a2,-1042 # ffffffffc02016c0 <etext+0x3b0>
ffffffffc0200ada:	06a00593          	li	a1,106
ffffffffc0200ade:	00001517          	auipc	a0,0x1
ffffffffc0200ae2:	bfa50513          	addi	a0,a0,-1030 # ffffffffc02016d8 <etext+0x3c8>
static void slub_free_pages_iface(struct Page *base, size_t n) {
ffffffffc0200ae6:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200ae8:	edaff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200aec <kmalloc>:
    if (!slub_inited) {
ffffffffc0200aec:	00004e17          	auipc	t3,0x4
ffffffffc0200af0:	7cce0e13          	addi	t3,t3,1996 # ffffffffc02052b8 <slub_inited>
ffffffffc0200af4:	000e2783          	lw	a5,0(t3)
ffffffffc0200af8:	efa9                	bnez	a5,ffffffffc0200b52 <kmalloc+0x66>
ffffffffc0200afa:	00004797          	auipc	a5,0x4
ffffffffc0200afe:	53678793          	addi	a5,a5,1334 # ffffffffc0205030 <slub_caches+0x18>
ffffffffc0200b02:	00001817          	auipc	a6,0x1
ffffffffc0200b06:	cb680813          	addi	a6,a6,-842 # ffffffffc02017b8 <slub_size_classes>
ffffffffc0200b0a:	00004317          	auipc	t1,0x4
ffffffffc0200b0e:	76630313          	addi	t1,t1,1894 # ffffffffc0205270 <is_panic>
ffffffffc0200b12:	45c1                	li	a1,16
    c->align = sizeof(void *);
ffffffffc0200b14:	48a1                	li	a7,8
ffffffffc0200b16:	a019                	j	ffffffffc0200b1c <kmalloc+0x30>
            cache_init(&slub_caches[i], slub_size_classes[i]);
ffffffffc0200b18:	00083583          	ld	a1,0(a6)
static inline size_t align_up(size_t x, size_t a) { return (x + a - 1) & ~(a - 1); }
ffffffffc0200b1c:	00758713          	addi	a4,a1,7
ffffffffc0200b20:	01078613          	addi	a2,a5,16
ffffffffc0200b24:	02078693          	addi	a3,a5,32
ffffffffc0200b28:	9b61                	andi	a4,a4,-8
    c->obj_size = size;
ffffffffc0200b2a:	feb7b423          	sd	a1,-24(a5)
    c->align = sizeof(void *);
ffffffffc0200b2e:	ff17b823          	sd	a7,-16(a5)
    c->obj_stride = align_up(c->obj_size, c->align);
ffffffffc0200b32:	fee7bc23          	sd	a4,-8(a5)
    elm->prev = elm->next = elm;
ffffffffc0200b36:	e79c                	sd	a5,8(a5)
ffffffffc0200b38:	e39c                	sd	a5,0(a5)
ffffffffc0200b3a:	ef90                	sd	a2,24(a5)
ffffffffc0200b3c:	eb90                	sd	a2,16(a5)
ffffffffc0200b3e:	f794                	sd	a3,40(a5)
ffffffffc0200b40:	f394                	sd	a3,32(a5)
        for (size_t i = 0; i < SLUB_NUM_CLASSES; i++) {
ffffffffc0200b42:	04878793          	addi	a5,a5,72
ffffffffc0200b46:	0821                	addi	a6,a6,8
ffffffffc0200b48:	fcf318e3          	bne	t1,a5,ffffffffc0200b18 <kmalloc+0x2c>
        slub_inited = 1;
ffffffffc0200b4c:	4785                	li	a5,1
ffffffffc0200b4e:	00fe2023          	sw	a5,0(t3)
    if (size == 0) return NULL;
ffffffffc0200b52:	c97d                	beqz	a0,ffffffffc0200c48 <kmalloc+0x15c>
void *kmalloc(size_t size) {
ffffffffc0200b54:	7139                	addi	sp,sp,-64
ffffffffc0200b56:	f04a                	sd	s2,32(sp)
ffffffffc0200b58:	00004917          	auipc	s2,0x4
ffffffffc0200b5c:	4c090913          	addi	s2,s2,1216 # ffffffffc0205018 <slub_caches>
ffffffffc0200b60:	fc06                	sd	ra,56(sp)
ffffffffc0200b62:	f822                	sd	s0,48(sp)
ffffffffc0200b64:	f426                	sd	s1,40(sp)
ffffffffc0200b66:	ec4e                	sd	s3,24(sp)
ffffffffc0200b68:	e852                	sd	s4,16(sp)
ffffffffc0200b6a:	e456                	sd	s5,8(sp)
ffffffffc0200b6c:	e05a                	sd	s6,0(sp)
ffffffffc0200b6e:	874a                	mv	a4,s2
    for (size_t i = 0; i < SLUB_NUM_CLASSES; i++) {
ffffffffc0200b70:	4781                	li	a5,0
ffffffffc0200b72:	4621                	li	a2,8
        if (size <= slub_caches[i].obj_size) return &slub_caches[i];
ffffffffc0200b74:	6314                	ld	a3,0(a4)
    for (size_t i = 0; i < SLUB_NUM_CLASSES; i++) {
ffffffffc0200b76:	04870713          	addi	a4,a4,72
        if (size <= slub_caches[i].obj_size) return &slub_caches[i];
ffffffffc0200b7a:	02a6f063          	bgeu	a3,a0,ffffffffc0200b9a <kmalloc+0xae>
    for (size_t i = 0; i < SLUB_NUM_CLASSES; i++) {
ffffffffc0200b7e:	0785                	addi	a5,a5,1
ffffffffc0200b80:	fec79ae3          	bne	a5,a2,ffffffffc0200b74 <kmalloc+0x88>
        if (slab == NULL) return NULL;
ffffffffc0200b84:	4501                	li	a0,0
}
ffffffffc0200b86:	70e2                	ld	ra,56(sp)
ffffffffc0200b88:	7442                	ld	s0,48(sp)
ffffffffc0200b8a:	74a2                	ld	s1,40(sp)
ffffffffc0200b8c:	7902                	ld	s2,32(sp)
ffffffffc0200b8e:	69e2                	ld	s3,24(sp)
ffffffffc0200b90:	6a42                	ld	s4,16(sp)
ffffffffc0200b92:	6aa2                	ld	s5,8(sp)
ffffffffc0200b94:	6b02                	ld	s6,0(sp)
ffffffffc0200b96:	6121                	addi	sp,sp,64
ffffffffc0200b98:	8082                	ret
        if (size <= slub_caches[i].obj_size) return &slub_caches[i];
ffffffffc0200b9a:	00379493          	slli	s1,a5,0x3
ffffffffc0200b9e:	97a6                	add	a5,a5,s1
ffffffffc0200ba0:	00379493          	slli	s1,a5,0x3
ffffffffc0200ba4:	009909b3          	add	s3,s2,s1
    return list->next == list;
ffffffffc0200ba8:	0209ba03          	ld	s4,32(s3)
    if (!list_empty(&c->partial)) {
ffffffffc0200bac:	01848793          	addi	a5,s1,24
ffffffffc0200bb0:	97ca                	add	a5,a5,s2
        slab = to_struct(list_next(&c->partial), slab_t, list_link);
ffffffffc0200bb2:	ff0a0413          	addi	s0,s4,-16
    if (!list_empty(&c->partial)) {
ffffffffc0200bb6:	04fa0f63          	beq	s4,a5,ffffffffc0200c14 <kmalloc+0x128>
    if (slab->free_head == 0xFFFF) return NULL;
ffffffffc0200bba:	00c45503          	lhu	a0,12(s0)
ffffffffc0200bbe:	67c1                	lui	a5,0x10
ffffffffc0200bc0:	17fd                	addi	a5,a5,-1
ffffffffc0200bc2:	fcf501e3          	beq	a0,a5,ffffffffc0200b84 <kmalloc+0x98>
    return (void *)(slab_obj_area(s) + (size_t)idx * s->cache->obj_stride);
ffffffffc0200bc6:	6014                	ld	a3,0(s0)
    slab->inuse++;
ffffffffc0200bc8:	00845783          	lhu	a5,8(s0)
    if (slab->inuse == slab->total) {
ffffffffc0200bcc:	00a45703          	lhu	a4,10(s0)
    return (void *)(slab_obj_area(s) + (size_t)idx * s->cache->obj_stride);
ffffffffc0200bd0:	6a94                	ld	a3,16(a3)
    slab->inuse++;
ffffffffc0200bd2:	2785                	addiw	a5,a5,1
ffffffffc0200bd4:	17c2                	slli	a5,a5,0x30
    return (void *)(slab_obj_area(s) + (size_t)idx * s->cache->obj_stride);
ffffffffc0200bd6:	02d50533          	mul	a0,a0,a3
    slab->inuse++;
ffffffffc0200bda:	93c1                	srli	a5,a5,0x30
    return (void *)(slab_obj_area(s) + (size_t)idx * s->cache->obj_stride);
ffffffffc0200bdc:	02050513          	addi	a0,a0,32
ffffffffc0200be0:	9522                	add	a0,a0,s0
    slab->free_head = *(uint16_t *)obj; // pop next index
ffffffffc0200be2:	00055683          	lhu	a3,0(a0)
    slab->inuse++;
ffffffffc0200be6:	00f41423          	sh	a5,8(s0)
    slab->free_head = *(uint16_t *)obj; // pop next index
ffffffffc0200bea:	00d41623          	sh	a3,12(s0)
    if (slab->inuse == slab->total) {
ffffffffc0200bee:	f8f71ce3          	bne	a4,a5,ffffffffc0200b86 <kmalloc+0x9a>
    __list_del(listelm->prev, listelm->next);
ffffffffc0200bf2:	6810                	ld	a2,16(s0)
ffffffffc0200bf4:	6c14                	ld	a3,24(s0)
        list_add(&c->full, &slab->list_link);
ffffffffc0200bf6:	01040713          	addi	a4,s0,16
ffffffffc0200bfa:	02848493          	addi	s1,s1,40
    prev->next = next;
ffffffffc0200bfe:	e614                	sd	a3,8(a2)
    __list_add(elm, listelm, listelm->next);
ffffffffc0200c00:	0309b783          	ld	a5,48(s3)
    next->prev = prev;
ffffffffc0200c04:	e290                	sd	a2,0(a3)
ffffffffc0200c06:	94ca                	add	s1,s1,s2
    prev->next = next->prev = elm;
ffffffffc0200c08:	e398                	sd	a4,0(a5)
ffffffffc0200c0a:	02e9b823          	sd	a4,48(s3)
    elm->next = next;
ffffffffc0200c0e:	ec1c                	sd	a5,24(s0)
    elm->prev = prev;
ffffffffc0200c10:	e804                	sd	s1,16(s0)
}
ffffffffc0200c12:	bf95                	j	ffffffffc0200b86 <kmalloc+0x9a>
    return list->next == list;
ffffffffc0200c14:	0409ba83          	ld	s5,64(s3)
    } else if (!list_empty(&c->empty)) {
ffffffffc0200c18:	03848793          	addi	a5,s1,56
ffffffffc0200c1c:	97ca                	add	a5,a5,s2
ffffffffc0200c1e:	02fa8763          	beq	s5,a5,ffffffffc0200c4c <kmalloc+0x160>
    __list_del(listelm->prev, listelm->next);
ffffffffc0200c22:	000ab683          	ld	a3,0(s5)
ffffffffc0200c26:	008ab703          	ld	a4,8(s5)
        slab = to_struct(list_next(&c->empty), slab_t, list_link);
ffffffffc0200c2a:	ff0a8413          	addi	s0,s5,-16
    prev->next = next;
ffffffffc0200c2e:	e698                	sd	a4,8(a3)
    __list_add(elm, listelm, listelm->next);
ffffffffc0200c30:	0209b783          	ld	a5,32(s3)
    next->prev = prev;
ffffffffc0200c34:	e314                	sd	a3,0(a4)
    prev->next = next->prev = elm;
ffffffffc0200c36:	0157b023          	sd	s5,0(a5) # 10000 <kern_entry-0xffffffffc01f0000>
ffffffffc0200c3a:	0359b023          	sd	s5,32(s3)
    elm->next = next;
ffffffffc0200c3e:	00fab423          	sd	a5,8(s5)
    elm->prev = prev;
ffffffffc0200c42:	014ab023          	sd	s4,0(s5)
}
ffffffffc0200c46:	bf95                	j	ffffffffc0200bba <kmalloc+0xce>
    if (size == 0) return NULL;
ffffffffc0200c48:	4501                	li	a0,0
}
ffffffffc0200c4a:	8082                	ret
    struct Page *pg = slub_page_alloc_pages(1);
ffffffffc0200c4c:	4505                	li	a0,1
ffffffffc0200c4e:	bd3ff0ef          	jal	ra,ffffffffc0200820 <slub_page_alloc_pages>
ffffffffc0200c52:	8b2a                	mv	s6,a0
    if (pg == NULL) return NULL;
ffffffffc0200c54:	d905                	beqz	a0,ffffffffc0200b84 <kmalloc+0x98>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200c56:	00004417          	auipc	s0,0x4
ffffffffc0200c5a:	63a43403          	ld	s0,1594(s0) # ffffffffc0205290 <pages>
ffffffffc0200c5e:	40850433          	sub	s0,a0,s0
ffffffffc0200c62:	00001797          	auipc	a5,0x1
ffffffffc0200c66:	de67b783          	ld	a5,-538(a5) # ffffffffc0201a48 <nbase+0x8>
ffffffffc0200c6a:	840d                	srai	s0,s0,0x3
ffffffffc0200c6c:	02f40433          	mul	s0,s0,a5
ffffffffc0200c70:	00001797          	auipc	a5,0x1
ffffffffc0200c74:	dd07b783          	ld	a5,-560(a5) # ffffffffc0201a40 <nbase>
    memset(slab, 0, sizeof(*slab));
ffffffffc0200c78:	02000613          	li	a2,32
ffffffffc0200c7c:	4581                	li	a1,0
ffffffffc0200c7e:	943e                	add	s0,s0,a5
    return page2ppn(page) << PGSHIFT;
ffffffffc0200c80:	0432                	slli	s0,s0,0xc
    return (void *)(page2pa(p) + va_pa_offset);
ffffffffc0200c82:	00004797          	auipc	a5,0x4
ffffffffc0200c86:	62e7b783          	ld	a5,1582(a5) # ffffffffc02052b0 <va_pa_offset>
ffffffffc0200c8a:	943e                	add	s0,s0,a5
    memset(slab, 0, sizeof(*slab));
ffffffffc0200c8c:	8522                	mv	a0,s0
ffffffffc0200c8e:	670000ef          	jal	ra,ffffffffc02012fe <memset>
    if (payload < c->obj_stride) return 0;
ffffffffc0200c92:	0109b803          	ld	a6,16(s3)
ffffffffc0200c96:	6785                	lui	a5,0x1
    slab->cache = cache;
ffffffffc0200c98:	01343023          	sd	s3,0(s0)
    if (payload < c->obj_stride) return 0;
ffffffffc0200c9c:	1781                	addi	a5,a5,-32
ffffffffc0200c9e:	0707eb63          	bltu	a5,a6,ffffffffc0200d14 <kmalloc+0x228>
    return payload / c->obj_stride;
ffffffffc0200ca2:	0307d6b3          	divu	a3,a5,a6
    list_init(&slab->list_link);
ffffffffc0200ca6:	01040893          	addi	a7,s0,16
        uint16_t next = (i + 1U < slab->total) ? (uint16_t)(i + 1U) : (uint16_t)0xFFFF;
ffffffffc0200caa:	6541                	lui	a0,0x10
    slab->inuse = 0;
ffffffffc0200cac:	00041423          	sh	zero,8(s0)
    slab->free_head = 0;
ffffffffc0200cb0:	00041623          	sh	zero,12(s0)
    elm->prev = elm->next = elm;
ffffffffc0200cb4:	01143c23          	sd	a7,24(s0)
    for (uint16_t i = 0; i < slab->total; i++) {
ffffffffc0200cb8:	4781                	li	a5,0
        uint16_t next = (i + 1U < slab->total) ? (uint16_t)(i + 1U) : (uint16_t)0xFFFF;
ffffffffc0200cba:	157d                	addi	a0,a0,-1
    slab->total = (uint16_t)slab_calc_capacity(cache);
ffffffffc0200cbc:	16c2                	slli	a3,a3,0x30
ffffffffc0200cbe:	92c1                	srli	a3,a3,0x30
ffffffffc0200cc0:	00d41523          	sh	a3,10(s0)
    for (uint16_t i = 0; i < slab->total; i++) {
ffffffffc0200cc4:	2681                	sext.w	a3,a3
    return (void *)(slab_obj_area(s) + (size_t)idx * s->cache->obj_stride);
ffffffffc0200cc6:	03078733          	mul	a4,a5,a6
ffffffffc0200cca:	2785                	addiw	a5,a5,1
ffffffffc0200ccc:	17c2                	slli	a5,a5,0x30
ffffffffc0200cce:	93c1                	srli	a5,a5,0x30
        uint16_t next = (i + 1U < slab->total) ? (uint16_t)(i + 1U) : (uint16_t)0xFFFF;
ffffffffc0200cd0:	862a                	mv	a2,a0
ffffffffc0200cd2:	0007859b          	sext.w	a1,a5
    return (void *)(slab_obj_area(s) + (size_t)idx * s->cache->obj_stride);
ffffffffc0200cd6:	02070713          	addi	a4,a4,32
ffffffffc0200cda:	9722                	add	a4,a4,s0
        uint16_t next = (i + 1U < slab->total) ? (uint16_t)(i + 1U) : (uint16_t)0xFFFF;
ffffffffc0200cdc:	00d7f363          	bgeu	a5,a3,ffffffffc0200ce2 <kmalloc+0x1f6>
ffffffffc0200ce0:	863e                	mv	a2,a5
        *(uint16_t *)obj = next;
ffffffffc0200ce2:	00c71023          	sh	a2,0(a4)
    for (uint16_t i = 0; i < slab->total; i++) {
ffffffffc0200ce6:	00a45683          	lhu	a3,10(s0)
ffffffffc0200cea:	fcd5eee3          	bltu	a1,a3,ffffffffc0200cc6 <kmalloc+0x1da>
    __list_add(elm, listelm, listelm->next);
ffffffffc0200cee:	0409b783          	ld	a5,64(s3)
    prev->next = next->prev = elm;
ffffffffc0200cf2:	0519b023          	sd	a7,64(s3)
    elm->next = next;
ffffffffc0200cf6:	ec1c                	sd	a5,24(s0)
    prev->next = next;
ffffffffc0200cf8:	00fab423          	sd	a5,8(s5)
    __list_add(elm, listelm, listelm->next);
ffffffffc0200cfc:	0209b703          	ld	a4,32(s3)
    next->prev = prev;
ffffffffc0200d00:	0157b023          	sd	s5,0(a5) # 1000 <kern_entry-0xffffffffc01ff000>
    prev->next = next->prev = elm;
ffffffffc0200d04:	01173023          	sd	a7,0(a4)
ffffffffc0200d08:	0319b023          	sd	a7,32(s3)
    elm->next = next;
ffffffffc0200d0c:	ec18                	sd	a4,24(s0)
    elm->prev = prev;
ffffffffc0200d0e:	01443823          	sd	s4,16(s0)
}
ffffffffc0200d12:	b565                	j	ffffffffc0200bba <kmalloc+0xce>
    slab->total = (uint16_t)slab_calc_capacity(cache);
ffffffffc0200d14:	00041523          	sh	zero,10(s0)
    assert(n > 0);
ffffffffc0200d18:	4585                	li	a1,1
ffffffffc0200d1a:	855a                	mv	a0,s6
ffffffffc0200d1c:	ca5ff0ef          	jal	ra,ffffffffc02009c0 <slub_page_free_pages.part.0>
ffffffffc0200d20:	b595                	j	ffffffffc0200b84 <kmalloc+0x98>

ffffffffc0200d22 <kfree>:
    if (ptr == NULL) return;
ffffffffc0200d22:	c12d                	beqz	a0,ffffffffc0200d84 <kfree+0x62>
    uintptr_t base = ROUNDDOWN((uintptr_t)ptr, PGSIZE);
ffffffffc0200d24:	77fd                	lui	a5,0xfffff
ffffffffc0200d26:	8fe9                	and	a5,a5,a0
    return (char *)s + sizeof(slab_t);
ffffffffc0200d28:	02078713          	addi	a4,a5,32 # fffffffffffff020 <end+0x3fdf9d64>
    uintptr_t off = (uintptr_t)((char *)ptr - area);
ffffffffc0200d2c:	40e50733          	sub	a4,a0,a4
    if (off >= (uintptr_t)PGSIZE || (off % c->obj_stride) != 0) {
ffffffffc0200d30:	6685                	lui	a3,0x1
ffffffffc0200d32:	04d77963          	bgeu	a4,a3,ffffffffc0200d84 <kfree+0x62>
    kmem_cache_t *c = slab->cache;
ffffffffc0200d36:	6390                	ld	a2,0(a5)
    if (off >= (uintptr_t)PGSIZE || (off % c->obj_stride) != 0) {
ffffffffc0200d38:	6a14                	ld	a3,16(a2)
ffffffffc0200d3a:	02d775b3          	remu	a1,a4,a3
ffffffffc0200d3e:	e1b9                	bnez	a1,ffffffffc0200d84 <kfree+0x62>
    return (uint16_t)(((char *)ptr - slab_obj_area(s)) / s->cache->obj_stride);
ffffffffc0200d40:	02d75733          	divu	a4,a4,a3
    *(uint16_t *)ptr = slab->free_head;
ffffffffc0200d44:	00c7d683          	lhu	a3,12(a5)
ffffffffc0200d48:	00d51023          	sh	a3,0(a0) # 10000 <kern_entry-0xffffffffc01f0000>
    slab->inuse--;
ffffffffc0200d4c:	0087d683          	lhu	a3,8(a5)
ffffffffc0200d50:	36fd                	addiw	a3,a3,-1
ffffffffc0200d52:	16c2                	slli	a3,a3,0x30
ffffffffc0200d54:	92c1                	srli	a3,a3,0x30
ffffffffc0200d56:	00d79423          	sh	a3,8(a5)
    return (uint16_t)(((char *)ptr - slab_obj_area(s)) / s->cache->obj_stride);
ffffffffc0200d5a:	00e79623          	sh	a4,12(a5)
    if (slab->inuse == 0) {
ffffffffc0200d5e:	c685                	beqz	a3,ffffffffc0200d86 <kfree+0x64>
    } else if (slab->inuse < slab->total) {
ffffffffc0200d60:	00a7d703          	lhu	a4,10(a5)
ffffffffc0200d64:	02e6f063          	bgeu	a3,a4,ffffffffc0200d84 <kfree+0x62>
    __list_del(listelm->prev, listelm->next);
ffffffffc0200d68:	6b88                	ld	a0,16(a5)
ffffffffc0200d6a:	6f8c                	ld	a1,24(a5)
        list_add(&c->partial, &slab->list_link);
ffffffffc0200d6c:	01078693          	addi	a3,a5,16
ffffffffc0200d70:	01860813          	addi	a6,a2,24
    prev->next = next;
ffffffffc0200d74:	e50c                	sd	a1,8(a0)
    __list_add(elm, listelm, listelm->next);
ffffffffc0200d76:	7218                	ld	a4,32(a2)
    next->prev = prev;
ffffffffc0200d78:	e188                	sd	a0,0(a1)
    prev->next = next->prev = elm;
ffffffffc0200d7a:	e314                	sd	a3,0(a4)
ffffffffc0200d7c:	f214                	sd	a3,32(a2)
    elm->next = next;
ffffffffc0200d7e:	ef98                	sd	a4,24(a5)
    elm->prev = prev;
ffffffffc0200d80:	0107b823          	sd	a6,16(a5)
ffffffffc0200d84:	8082                	ret
    __list_del(listelm->prev, listelm->next);
ffffffffc0200d86:	6f98                	ld	a4,24(a5)
ffffffffc0200d88:	6b94                	ld	a3,16(a5)
    struct Page *pg = pa2page((uintptr_t)slab - va_pa_offset);
ffffffffc0200d8a:	00004617          	auipc	a2,0x4
ffffffffc0200d8e:	52663603          	ld	a2,1318(a2) # ffffffffc02052b0 <va_pa_offset>
ffffffffc0200d92:	8f91                	sub	a5,a5,a2
    prev->next = next;
ffffffffc0200d94:	e698                	sd	a4,8(a3)
    next->prev = prev;
ffffffffc0200d96:	e314                	sd	a3,0(a4)
    if (PPN(pa) >= npage) {
ffffffffc0200d98:	83b1                	srli	a5,a5,0xc
ffffffffc0200d9a:	00004717          	auipc	a4,0x4
ffffffffc0200d9e:	4ee73703          	ld	a4,1262(a4) # ffffffffc0205288 <npage>
ffffffffc0200da2:	02e7f263          	bgeu	a5,a4,ffffffffc0200dc6 <kfree+0xa4>
    return &pages[PPN(pa) - nbase];
ffffffffc0200da6:	00001517          	auipc	a0,0x1
ffffffffc0200daa:	c9a53503          	ld	a0,-870(a0) # ffffffffc0201a40 <nbase>
ffffffffc0200dae:	8f89                	sub	a5,a5,a0
ffffffffc0200db0:	00279513          	slli	a0,a5,0x2
ffffffffc0200db4:	97aa                	add	a5,a5,a0
ffffffffc0200db6:	078e                	slli	a5,a5,0x3
ffffffffc0200db8:	00004517          	auipc	a0,0x4
ffffffffc0200dbc:	4d853503          	ld	a0,1240(a0) # ffffffffc0205290 <pages>
ffffffffc0200dc0:	4585                	li	a1,1
ffffffffc0200dc2:	953e                	add	a0,a0,a5
ffffffffc0200dc4:	bef5                	j	ffffffffc02009c0 <slub_page_free_pages.part.0>
void kfree(void *ptr) {
ffffffffc0200dc6:	1141                	addi	sp,sp,-16
        panic("pa2page called with invalid pa");
ffffffffc0200dc8:	00001617          	auipc	a2,0x1
ffffffffc0200dcc:	86060613          	addi	a2,a2,-1952 # ffffffffc0201628 <etext+0x318>
ffffffffc0200dd0:	06a00593          	li	a1,106
ffffffffc0200dd4:	00001517          	auipc	a0,0x1
ffffffffc0200dd8:	87450513          	addi	a0,a0,-1932 # ffffffffc0201648 <etext+0x338>
ffffffffc0200ddc:	e406                	sd	ra,8(sp)
ffffffffc0200dde:	be4ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200de2 <slub_check>:

static void slub_check(void) {
ffffffffc0200de2:	1101                	addi	sp,sp,-32
    return slub_page_alloc_pages(n);
ffffffffc0200de4:	4505                	li	a0,1
static void slub_check(void) {
ffffffffc0200de6:	e822                	sd	s0,16(sp)
ffffffffc0200de8:	ec06                	sd	ra,24(sp)
ffffffffc0200dea:	e426                	sd	s1,8(sp)
    return slub_page_alloc_pages(n);
ffffffffc0200dec:	a35ff0ef          	jal	ra,ffffffffc0200820 <slub_page_alloc_pages>
ffffffffc0200df0:	842a                	mv	s0,a0
ffffffffc0200df2:	4509                	li	a0,2
ffffffffc0200df4:	a2dff0ef          	jal	ra,ffffffffc0200820 <slub_page_alloc_pages>
    // Basic sanity: allocate and free a few pages
    struct Page *a = slub_alloc_pages_iface(1);
    struct Page *b = slub_alloc_pages_iface(2);
    assert(a != NULL && b != NULL && a != b);
ffffffffc0200df8:	c031                	beqz	s0,ffffffffc0200e3c <slub_check+0x5a>
ffffffffc0200dfa:	84aa                	mv	s1,a0
ffffffffc0200dfc:	c121                	beqz	a0,ffffffffc0200e3c <slub_check+0x5a>
ffffffffc0200dfe:	02850f63          	beq	a0,s0,ffffffffc0200e3c <slub_check+0x5a>
    assert(n > 0);
ffffffffc0200e02:	8522                	mv	a0,s0
ffffffffc0200e04:	4585                	li	a1,1
ffffffffc0200e06:	bbbff0ef          	jal	ra,ffffffffc02009c0 <slub_page_free_pages.part.0>
ffffffffc0200e0a:	4589                	li	a1,2
ffffffffc0200e0c:	8526                	mv	a0,s1
ffffffffc0200e0e:	bb3ff0ef          	jal	ra,ffffffffc02009c0 <slub_page_free_pages.part.0>
    slub_free_pages_iface(a, 1);
    slub_free_pages_iface(b, 2);

    // Optional: quick kmalloc smoke test
    void *p = kmalloc(64);
ffffffffc0200e12:	04000513          	li	a0,64
ffffffffc0200e16:	cd7ff0ef          	jal	ra,ffffffffc0200aec <kmalloc>
ffffffffc0200e1a:	84aa                	mv	s1,a0
    void *q = kmalloc(32);
ffffffffc0200e1c:	02000513          	li	a0,32
ffffffffc0200e20:	ccdff0ef          	jal	ra,ffffffffc0200aec <kmalloc>
ffffffffc0200e24:	842a                	mv	s0,a0
    assert(p != NULL && q != NULL);
ffffffffc0200e26:	c89d                	beqz	s1,ffffffffc0200e5c <slub_check+0x7a>
ffffffffc0200e28:	c915                	beqz	a0,ffffffffc0200e5c <slub_check+0x7a>
    kfree(p);
ffffffffc0200e2a:	8526                	mv	a0,s1
ffffffffc0200e2c:	ef7ff0ef          	jal	ra,ffffffffc0200d22 <kfree>
    kfree(q);
ffffffffc0200e30:	8522                	mv	a0,s0
}
ffffffffc0200e32:	6442                	ld	s0,16(sp)
ffffffffc0200e34:	60e2                	ld	ra,24(sp)
ffffffffc0200e36:	64a2                	ld	s1,8(sp)
ffffffffc0200e38:	6105                	addi	sp,sp,32
    kfree(q);
ffffffffc0200e3a:	b5e5                	j	ffffffffc0200d22 <kfree>
    assert(a != NULL && b != NULL && a != b);
ffffffffc0200e3c:	00001697          	auipc	a3,0x1
ffffffffc0200e40:	8ec68693          	addi	a3,a3,-1812 # ffffffffc0201728 <etext+0x418>
ffffffffc0200e44:	00001617          	auipc	a2,0x1
ffffffffc0200e48:	87c60613          	addi	a2,a2,-1924 # ffffffffc02016c0 <etext+0x3b0>
ffffffffc0200e4c:	17400593          	li	a1,372
ffffffffc0200e50:	00001517          	auipc	a0,0x1
ffffffffc0200e54:	88850513          	addi	a0,a0,-1912 # ffffffffc02016d8 <etext+0x3c8>
ffffffffc0200e58:	b6aff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p != NULL && q != NULL);
ffffffffc0200e5c:	00001697          	auipc	a3,0x1
ffffffffc0200e60:	8f468693          	addi	a3,a3,-1804 # ffffffffc0201750 <etext+0x440>
ffffffffc0200e64:	00001617          	auipc	a2,0x1
ffffffffc0200e68:	85c60613          	addi	a2,a2,-1956 # ffffffffc02016c0 <etext+0x3b0>
ffffffffc0200e6c:	17b00593          	li	a1,379
ffffffffc0200e70:	00001517          	auipc	a0,0x1
ffffffffc0200e74:	86850513          	addi	a0,a0,-1944 # ffffffffc02016d8 <etext+0x3c8>
ffffffffc0200e78:	b4aff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200e7c <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc0200e7c:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0200e80:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc0200e82:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0200e86:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc0200e88:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0200e8c:	f022                	sd	s0,32(sp)
ffffffffc0200e8e:	ec26                	sd	s1,24(sp)
ffffffffc0200e90:	e84a                	sd	s2,16(sp)
ffffffffc0200e92:	f406                	sd	ra,40(sp)
ffffffffc0200e94:	e44e                	sd	s3,8(sp)
ffffffffc0200e96:	84aa                	mv	s1,a0
ffffffffc0200e98:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc0200e9a:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc0200e9e:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc0200ea0:	03067e63          	bgeu	a2,a6,ffffffffc0200edc <printnum+0x60>
ffffffffc0200ea4:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc0200ea6:	00805763          	blez	s0,ffffffffc0200eb4 <printnum+0x38>
ffffffffc0200eaa:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc0200eac:	85ca                	mv	a1,s2
ffffffffc0200eae:	854e                	mv	a0,s3
ffffffffc0200eb0:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc0200eb2:	fc65                	bnez	s0,ffffffffc0200eaa <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0200eb4:	1a02                	slli	s4,s4,0x20
ffffffffc0200eb6:	00001797          	auipc	a5,0x1
ffffffffc0200eba:	94278793          	addi	a5,a5,-1726 # ffffffffc02017f8 <slub_size_classes+0x40>
ffffffffc0200ebe:	020a5a13          	srli	s4,s4,0x20
ffffffffc0200ec2:	9a3e                	add	s4,s4,a5
}
ffffffffc0200ec4:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0200ec6:	000a4503          	lbu	a0,0(s4)
}
ffffffffc0200eca:	70a2                	ld	ra,40(sp)
ffffffffc0200ecc:	69a2                	ld	s3,8(sp)
ffffffffc0200ece:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0200ed0:	85ca                	mv	a1,s2
ffffffffc0200ed2:	87a6                	mv	a5,s1
}
ffffffffc0200ed4:	6942                	ld	s2,16(sp)
ffffffffc0200ed6:	64e2                	ld	s1,24(sp)
ffffffffc0200ed8:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0200eda:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc0200edc:	03065633          	divu	a2,a2,a6
ffffffffc0200ee0:	8722                	mv	a4,s0
ffffffffc0200ee2:	f9bff0ef          	jal	ra,ffffffffc0200e7c <printnum>
ffffffffc0200ee6:	b7f9                	j	ffffffffc0200eb4 <printnum+0x38>

ffffffffc0200ee8 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc0200ee8:	7119                	addi	sp,sp,-128
ffffffffc0200eea:	f4a6                	sd	s1,104(sp)
ffffffffc0200eec:	f0ca                	sd	s2,96(sp)
ffffffffc0200eee:	ecce                	sd	s3,88(sp)
ffffffffc0200ef0:	e8d2                	sd	s4,80(sp)
ffffffffc0200ef2:	e4d6                	sd	s5,72(sp)
ffffffffc0200ef4:	e0da                	sd	s6,64(sp)
ffffffffc0200ef6:	fc5e                	sd	s7,56(sp)
ffffffffc0200ef8:	f06a                	sd	s10,32(sp)
ffffffffc0200efa:	fc86                	sd	ra,120(sp)
ffffffffc0200efc:	f8a2                	sd	s0,112(sp)
ffffffffc0200efe:	f862                	sd	s8,48(sp)
ffffffffc0200f00:	f466                	sd	s9,40(sp)
ffffffffc0200f02:	ec6e                	sd	s11,24(sp)
ffffffffc0200f04:	892a                	mv	s2,a0
ffffffffc0200f06:	84ae                	mv	s1,a1
ffffffffc0200f08:	8d32                	mv	s10,a2
ffffffffc0200f0a:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0200f0c:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc0200f10:	5b7d                	li	s6,-1
ffffffffc0200f12:	00001a97          	auipc	s5,0x1
ffffffffc0200f16:	91aa8a93          	addi	s5,s5,-1766 # ffffffffc020182c <slub_size_classes+0x74>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0200f1a:	00001b97          	auipc	s7,0x1
ffffffffc0200f1e:	aeeb8b93          	addi	s7,s7,-1298 # ffffffffc0201a08 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0200f22:	000d4503          	lbu	a0,0(s10)
ffffffffc0200f26:	001d0413          	addi	s0,s10,1
ffffffffc0200f2a:	01350a63          	beq	a0,s3,ffffffffc0200f3e <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc0200f2e:	c121                	beqz	a0,ffffffffc0200f6e <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc0200f30:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0200f32:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc0200f34:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0200f36:	fff44503          	lbu	a0,-1(s0)
ffffffffc0200f3a:	ff351ae3          	bne	a0,s3,ffffffffc0200f2e <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200f3e:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc0200f42:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc0200f46:	4c81                	li	s9,0
ffffffffc0200f48:	4881                	li	a7,0
        width = precision = -1;
ffffffffc0200f4a:	5c7d                	li	s8,-1
ffffffffc0200f4c:	5dfd                	li	s11,-1
ffffffffc0200f4e:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc0200f52:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200f54:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0200f58:	0ff5f593          	zext.b	a1,a1
ffffffffc0200f5c:	00140d13          	addi	s10,s0,1
ffffffffc0200f60:	04b56263          	bltu	a0,a1,ffffffffc0200fa4 <vprintfmt+0xbc>
ffffffffc0200f64:	058a                	slli	a1,a1,0x2
ffffffffc0200f66:	95d6                	add	a1,a1,s5
ffffffffc0200f68:	4194                	lw	a3,0(a1)
ffffffffc0200f6a:	96d6                	add	a3,a3,s5
ffffffffc0200f6c:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc0200f6e:	70e6                	ld	ra,120(sp)
ffffffffc0200f70:	7446                	ld	s0,112(sp)
ffffffffc0200f72:	74a6                	ld	s1,104(sp)
ffffffffc0200f74:	7906                	ld	s2,96(sp)
ffffffffc0200f76:	69e6                	ld	s3,88(sp)
ffffffffc0200f78:	6a46                	ld	s4,80(sp)
ffffffffc0200f7a:	6aa6                	ld	s5,72(sp)
ffffffffc0200f7c:	6b06                	ld	s6,64(sp)
ffffffffc0200f7e:	7be2                	ld	s7,56(sp)
ffffffffc0200f80:	7c42                	ld	s8,48(sp)
ffffffffc0200f82:	7ca2                	ld	s9,40(sp)
ffffffffc0200f84:	7d02                	ld	s10,32(sp)
ffffffffc0200f86:	6de2                	ld	s11,24(sp)
ffffffffc0200f88:	6109                	addi	sp,sp,128
ffffffffc0200f8a:	8082                	ret
            padc = '0';
ffffffffc0200f8c:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc0200f8e:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200f92:	846a                	mv	s0,s10
ffffffffc0200f94:	00140d13          	addi	s10,s0,1
ffffffffc0200f98:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0200f9c:	0ff5f593          	zext.b	a1,a1
ffffffffc0200fa0:	fcb572e3          	bgeu	a0,a1,ffffffffc0200f64 <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc0200fa4:	85a6                	mv	a1,s1
ffffffffc0200fa6:	02500513          	li	a0,37
ffffffffc0200faa:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc0200fac:	fff44783          	lbu	a5,-1(s0)
ffffffffc0200fb0:	8d22                	mv	s10,s0
ffffffffc0200fb2:	f73788e3          	beq	a5,s3,ffffffffc0200f22 <vprintfmt+0x3a>
ffffffffc0200fb6:	ffed4783          	lbu	a5,-2(s10)
ffffffffc0200fba:	1d7d                	addi	s10,s10,-1
ffffffffc0200fbc:	ff379de3          	bne	a5,s3,ffffffffc0200fb6 <vprintfmt+0xce>
ffffffffc0200fc0:	b78d                	j	ffffffffc0200f22 <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc0200fc2:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc0200fc6:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200fca:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc0200fcc:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc0200fd0:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0200fd4:	02d86463          	bltu	a6,a3,ffffffffc0200ffc <vprintfmt+0x114>
                ch = *fmt;
ffffffffc0200fd8:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc0200fdc:	002c169b          	slliw	a3,s8,0x2
ffffffffc0200fe0:	0186873b          	addw	a4,a3,s8
ffffffffc0200fe4:	0017171b          	slliw	a4,a4,0x1
ffffffffc0200fe8:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc0200fea:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc0200fee:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc0200ff0:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc0200ff4:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0200ff8:	fed870e3          	bgeu	a6,a3,ffffffffc0200fd8 <vprintfmt+0xf0>
            if (width < 0)
ffffffffc0200ffc:	f40ddce3          	bgez	s11,ffffffffc0200f54 <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc0201000:	8de2                	mv	s11,s8
ffffffffc0201002:	5c7d                	li	s8,-1
ffffffffc0201004:	bf81                	j	ffffffffc0200f54 <vprintfmt+0x6c>
            if (width < 0)
ffffffffc0201006:	fffdc693          	not	a3,s11
ffffffffc020100a:	96fd                	srai	a3,a3,0x3f
ffffffffc020100c:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201010:	00144603          	lbu	a2,1(s0)
ffffffffc0201014:	2d81                	sext.w	s11,s11
ffffffffc0201016:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201018:	bf35                	j	ffffffffc0200f54 <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc020101a:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020101e:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc0201022:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201024:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc0201026:	bfd9                	j	ffffffffc0200ffc <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc0201028:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc020102a:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc020102e:	01174463          	blt	a4,a7,ffffffffc0201036 <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc0201032:	1a088e63          	beqz	a7,ffffffffc02011ee <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc0201036:	000a3603          	ld	a2,0(s4)
ffffffffc020103a:	46c1                	li	a3,16
ffffffffc020103c:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc020103e:	2781                	sext.w	a5,a5
ffffffffc0201040:	876e                	mv	a4,s11
ffffffffc0201042:	85a6                	mv	a1,s1
ffffffffc0201044:	854a                	mv	a0,s2
ffffffffc0201046:	e37ff0ef          	jal	ra,ffffffffc0200e7c <printnum>
            break;
ffffffffc020104a:	bde1                	j	ffffffffc0200f22 <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc020104c:	000a2503          	lw	a0,0(s4)
ffffffffc0201050:	85a6                	mv	a1,s1
ffffffffc0201052:	0a21                	addi	s4,s4,8
ffffffffc0201054:	9902                	jalr	s2
            break;
ffffffffc0201056:	b5f1                	j	ffffffffc0200f22 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201058:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc020105a:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc020105e:	01174463          	blt	a4,a7,ffffffffc0201066 <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc0201062:	18088163          	beqz	a7,ffffffffc02011e4 <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc0201066:	000a3603          	ld	a2,0(s4)
ffffffffc020106a:	46a9                	li	a3,10
ffffffffc020106c:	8a2e                	mv	s4,a1
ffffffffc020106e:	bfc1                	j	ffffffffc020103e <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201070:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc0201074:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201076:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201078:	bdf1                	j	ffffffffc0200f54 <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc020107a:	85a6                	mv	a1,s1
ffffffffc020107c:	02500513          	li	a0,37
ffffffffc0201080:	9902                	jalr	s2
            break;
ffffffffc0201082:	b545                	j	ffffffffc0200f22 <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201084:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc0201088:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020108a:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc020108c:	b5e1                	j	ffffffffc0200f54 <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc020108e:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201090:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201094:	01174463          	blt	a4,a7,ffffffffc020109c <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc0201098:	14088163          	beqz	a7,ffffffffc02011da <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc020109c:	000a3603          	ld	a2,0(s4)
ffffffffc02010a0:	46a1                	li	a3,8
ffffffffc02010a2:	8a2e                	mv	s4,a1
ffffffffc02010a4:	bf69                	j	ffffffffc020103e <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc02010a6:	03000513          	li	a0,48
ffffffffc02010aa:	85a6                	mv	a1,s1
ffffffffc02010ac:	e03e                	sd	a5,0(sp)
ffffffffc02010ae:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc02010b0:	85a6                	mv	a1,s1
ffffffffc02010b2:	07800513          	li	a0,120
ffffffffc02010b6:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02010b8:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc02010ba:	6782                	ld	a5,0(sp)
ffffffffc02010bc:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02010be:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc02010c2:	bfb5                	j	ffffffffc020103e <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc02010c4:	000a3403          	ld	s0,0(s4)
ffffffffc02010c8:	008a0713          	addi	a4,s4,8
ffffffffc02010cc:	e03a                	sd	a4,0(sp)
ffffffffc02010ce:	14040263          	beqz	s0,ffffffffc0201212 <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc02010d2:	0fb05763          	blez	s11,ffffffffc02011c0 <vprintfmt+0x2d8>
ffffffffc02010d6:	02d00693          	li	a3,45
ffffffffc02010da:	0cd79163          	bne	a5,a3,ffffffffc020119c <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02010de:	00044783          	lbu	a5,0(s0)
ffffffffc02010e2:	0007851b          	sext.w	a0,a5
ffffffffc02010e6:	cf85                	beqz	a5,ffffffffc020111e <vprintfmt+0x236>
ffffffffc02010e8:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02010ec:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02010f0:	000c4563          	bltz	s8,ffffffffc02010fa <vprintfmt+0x212>
ffffffffc02010f4:	3c7d                	addiw	s8,s8,-1
ffffffffc02010f6:	036c0263          	beq	s8,s6,ffffffffc020111a <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc02010fa:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02010fc:	0e0c8e63          	beqz	s9,ffffffffc02011f8 <vprintfmt+0x310>
ffffffffc0201100:	3781                	addiw	a5,a5,-32
ffffffffc0201102:	0ef47b63          	bgeu	s0,a5,ffffffffc02011f8 <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc0201106:	03f00513          	li	a0,63
ffffffffc020110a:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc020110c:	000a4783          	lbu	a5,0(s4)
ffffffffc0201110:	3dfd                	addiw	s11,s11,-1
ffffffffc0201112:	0a05                	addi	s4,s4,1
ffffffffc0201114:	0007851b          	sext.w	a0,a5
ffffffffc0201118:	ffe1                	bnez	a5,ffffffffc02010f0 <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc020111a:	01b05963          	blez	s11,ffffffffc020112c <vprintfmt+0x244>
ffffffffc020111e:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc0201120:	85a6                	mv	a1,s1
ffffffffc0201122:	02000513          	li	a0,32
ffffffffc0201126:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc0201128:	fe0d9be3          	bnez	s11,ffffffffc020111e <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc020112c:	6a02                	ld	s4,0(sp)
ffffffffc020112e:	bbd5                	j	ffffffffc0200f22 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201130:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201132:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc0201136:	01174463          	blt	a4,a7,ffffffffc020113e <vprintfmt+0x256>
    else if (lflag) {
ffffffffc020113a:	08088d63          	beqz	a7,ffffffffc02011d4 <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc020113e:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc0201142:	0a044d63          	bltz	s0,ffffffffc02011fc <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc0201146:	8622                	mv	a2,s0
ffffffffc0201148:	8a66                	mv	s4,s9
ffffffffc020114a:	46a9                	li	a3,10
ffffffffc020114c:	bdcd                	j	ffffffffc020103e <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc020114e:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201152:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc0201154:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc0201156:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc020115a:	8fb5                	xor	a5,a5,a3
ffffffffc020115c:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201160:	02d74163          	blt	a4,a3,ffffffffc0201182 <vprintfmt+0x29a>
ffffffffc0201164:	00369793          	slli	a5,a3,0x3
ffffffffc0201168:	97de                	add	a5,a5,s7
ffffffffc020116a:	639c                	ld	a5,0(a5)
ffffffffc020116c:	cb99                	beqz	a5,ffffffffc0201182 <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc020116e:	86be                	mv	a3,a5
ffffffffc0201170:	00000617          	auipc	a2,0x0
ffffffffc0201174:	6b860613          	addi	a2,a2,1720 # ffffffffc0201828 <slub_size_classes+0x70>
ffffffffc0201178:	85a6                	mv	a1,s1
ffffffffc020117a:	854a                	mv	a0,s2
ffffffffc020117c:	0ce000ef          	jal	ra,ffffffffc020124a <printfmt>
ffffffffc0201180:	b34d                	j	ffffffffc0200f22 <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc0201182:	00000617          	auipc	a2,0x0
ffffffffc0201186:	69660613          	addi	a2,a2,1686 # ffffffffc0201818 <slub_size_classes+0x60>
ffffffffc020118a:	85a6                	mv	a1,s1
ffffffffc020118c:	854a                	mv	a0,s2
ffffffffc020118e:	0bc000ef          	jal	ra,ffffffffc020124a <printfmt>
ffffffffc0201192:	bb41                	j	ffffffffc0200f22 <vprintfmt+0x3a>
                p = "(null)";
ffffffffc0201194:	00000417          	auipc	s0,0x0
ffffffffc0201198:	67c40413          	addi	s0,s0,1660 # ffffffffc0201810 <slub_size_classes+0x58>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc020119c:	85e2                	mv	a1,s8
ffffffffc020119e:	8522                	mv	a0,s0
ffffffffc02011a0:	e43e                	sd	a5,8(sp)
ffffffffc02011a2:	0fc000ef          	jal	ra,ffffffffc020129e <strnlen>
ffffffffc02011a6:	40ad8dbb          	subw	s11,s11,a0
ffffffffc02011aa:	01b05b63          	blez	s11,ffffffffc02011c0 <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc02011ae:	67a2                	ld	a5,8(sp)
ffffffffc02011b0:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02011b4:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc02011b6:	85a6                	mv	a1,s1
ffffffffc02011b8:	8552                	mv	a0,s4
ffffffffc02011ba:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02011bc:	fe0d9ce3          	bnez	s11,ffffffffc02011b4 <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02011c0:	00044783          	lbu	a5,0(s0)
ffffffffc02011c4:	00140a13          	addi	s4,s0,1
ffffffffc02011c8:	0007851b          	sext.w	a0,a5
ffffffffc02011cc:	d3a5                	beqz	a5,ffffffffc020112c <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02011ce:	05e00413          	li	s0,94
ffffffffc02011d2:	bf39                	j	ffffffffc02010f0 <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc02011d4:	000a2403          	lw	s0,0(s4)
ffffffffc02011d8:	b7ad                	j	ffffffffc0201142 <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc02011da:	000a6603          	lwu	a2,0(s4)
ffffffffc02011de:	46a1                	li	a3,8
ffffffffc02011e0:	8a2e                	mv	s4,a1
ffffffffc02011e2:	bdb1                	j	ffffffffc020103e <vprintfmt+0x156>
ffffffffc02011e4:	000a6603          	lwu	a2,0(s4)
ffffffffc02011e8:	46a9                	li	a3,10
ffffffffc02011ea:	8a2e                	mv	s4,a1
ffffffffc02011ec:	bd89                	j	ffffffffc020103e <vprintfmt+0x156>
ffffffffc02011ee:	000a6603          	lwu	a2,0(s4)
ffffffffc02011f2:	46c1                	li	a3,16
ffffffffc02011f4:	8a2e                	mv	s4,a1
ffffffffc02011f6:	b5a1                	j	ffffffffc020103e <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc02011f8:	9902                	jalr	s2
ffffffffc02011fa:	bf09                	j	ffffffffc020110c <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc02011fc:	85a6                	mv	a1,s1
ffffffffc02011fe:	02d00513          	li	a0,45
ffffffffc0201202:	e03e                	sd	a5,0(sp)
ffffffffc0201204:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc0201206:	6782                	ld	a5,0(sp)
ffffffffc0201208:	8a66                	mv	s4,s9
ffffffffc020120a:	40800633          	neg	a2,s0
ffffffffc020120e:	46a9                	li	a3,10
ffffffffc0201210:	b53d                	j	ffffffffc020103e <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc0201212:	03b05163          	blez	s11,ffffffffc0201234 <vprintfmt+0x34c>
ffffffffc0201216:	02d00693          	li	a3,45
ffffffffc020121a:	f6d79de3          	bne	a5,a3,ffffffffc0201194 <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc020121e:	00000417          	auipc	s0,0x0
ffffffffc0201222:	5f240413          	addi	s0,s0,1522 # ffffffffc0201810 <slub_size_classes+0x58>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201226:	02800793          	li	a5,40
ffffffffc020122a:	02800513          	li	a0,40
ffffffffc020122e:	00140a13          	addi	s4,s0,1
ffffffffc0201232:	bd6d                	j	ffffffffc02010ec <vprintfmt+0x204>
ffffffffc0201234:	00000a17          	auipc	s4,0x0
ffffffffc0201238:	5dda0a13          	addi	s4,s4,1501 # ffffffffc0201811 <slub_size_classes+0x59>
ffffffffc020123c:	02800513          	li	a0,40
ffffffffc0201240:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201244:	05e00413          	li	s0,94
ffffffffc0201248:	b565                	j	ffffffffc02010f0 <vprintfmt+0x208>

ffffffffc020124a <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc020124a:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc020124c:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201250:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201252:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201254:	ec06                	sd	ra,24(sp)
ffffffffc0201256:	f83a                	sd	a4,48(sp)
ffffffffc0201258:	fc3e                	sd	a5,56(sp)
ffffffffc020125a:	e0c2                	sd	a6,64(sp)
ffffffffc020125c:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc020125e:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201260:	c89ff0ef          	jal	ra,ffffffffc0200ee8 <vprintfmt>
}
ffffffffc0201264:	60e2                	ld	ra,24(sp)
ffffffffc0201266:	6161                	addi	sp,sp,80
ffffffffc0201268:	8082                	ret

ffffffffc020126a <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc020126a:	4781                	li	a5,0
ffffffffc020126c:	00004717          	auipc	a4,0x4
ffffffffc0201270:	da473703          	ld	a4,-604(a4) # ffffffffc0205010 <SBI_CONSOLE_PUTCHAR>
ffffffffc0201274:	88ba                	mv	a7,a4
ffffffffc0201276:	852a                	mv	a0,a0
ffffffffc0201278:	85be                	mv	a1,a5
ffffffffc020127a:	863e                	mv	a2,a5
ffffffffc020127c:	00000073          	ecall
ffffffffc0201280:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc0201282:	8082                	ret

ffffffffc0201284 <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc0201284:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc0201288:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc020128a:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc020128c:	cb81                	beqz	a5,ffffffffc020129c <strlen+0x18>
        cnt ++;
ffffffffc020128e:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc0201290:	00a707b3          	add	a5,a4,a0
ffffffffc0201294:	0007c783          	lbu	a5,0(a5)
ffffffffc0201298:	fbfd                	bnez	a5,ffffffffc020128e <strlen+0xa>
ffffffffc020129a:	8082                	ret
    }
    return cnt;
}
ffffffffc020129c:	8082                	ret

ffffffffc020129e <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc020129e:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc02012a0:	e589                	bnez	a1,ffffffffc02012aa <strnlen+0xc>
ffffffffc02012a2:	a811                	j	ffffffffc02012b6 <strnlen+0x18>
        cnt ++;
ffffffffc02012a4:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc02012a6:	00f58863          	beq	a1,a5,ffffffffc02012b6 <strnlen+0x18>
ffffffffc02012aa:	00f50733          	add	a4,a0,a5
ffffffffc02012ae:	00074703          	lbu	a4,0(a4)
ffffffffc02012b2:	fb6d                	bnez	a4,ffffffffc02012a4 <strnlen+0x6>
ffffffffc02012b4:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc02012b6:	852e                	mv	a0,a1
ffffffffc02012b8:	8082                	ret

ffffffffc02012ba <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc02012ba:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02012be:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc02012c2:	cb89                	beqz	a5,ffffffffc02012d4 <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc02012c4:	0505                	addi	a0,a0,1
ffffffffc02012c6:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc02012c8:	fee789e3          	beq	a5,a4,ffffffffc02012ba <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02012cc:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc02012d0:	9d19                	subw	a0,a0,a4
ffffffffc02012d2:	8082                	ret
ffffffffc02012d4:	4501                	li	a0,0
ffffffffc02012d6:	bfed                	j	ffffffffc02012d0 <strcmp+0x16>

ffffffffc02012d8 <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc02012d8:	c20d                	beqz	a2,ffffffffc02012fa <strncmp+0x22>
ffffffffc02012da:	962e                	add	a2,a2,a1
ffffffffc02012dc:	a031                	j	ffffffffc02012e8 <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc02012de:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc02012e0:	00e79a63          	bne	a5,a4,ffffffffc02012f4 <strncmp+0x1c>
ffffffffc02012e4:	00b60b63          	beq	a2,a1,ffffffffc02012fa <strncmp+0x22>
ffffffffc02012e8:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc02012ec:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc02012ee:	fff5c703          	lbu	a4,-1(a1)
ffffffffc02012f2:	f7f5                	bnez	a5,ffffffffc02012de <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02012f4:	40e7853b          	subw	a0,a5,a4
}
ffffffffc02012f8:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02012fa:	4501                	li	a0,0
ffffffffc02012fc:	8082                	ret

ffffffffc02012fe <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc02012fe:	ca01                	beqz	a2,ffffffffc020130e <memset+0x10>
ffffffffc0201300:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc0201302:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc0201304:	0785                	addi	a5,a5,1
ffffffffc0201306:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc020130a:	fec79de3          	bne	a5,a2,ffffffffc0201304 <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc020130e:	8082                	ret
