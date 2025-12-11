#include <stdio.h>
#include <ulib.h>

volatile int zero = 0;

int main(void) {
    int val;
    // 使用内联汇编强制生成除法指令，防止编译器优化成奇怪的逻辑
    asm volatile("divw %0, %1, %2" : "=r"(val) : "r"(1), "r"(zero));
    cprintf("value is %d.\n", val);
    panic("FAIL: T.T\n");
}
