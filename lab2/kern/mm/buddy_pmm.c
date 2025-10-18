#include <pmm.h>
#include <list.h>
#include <string.h>
#include <stdio.h>
#include <memlayout.h>
#include <best_fit_pmm.h>

/* Page index conversion functions */
static inline size_t page2idx(struct Page *page) {
    return (page2pa(page) - DRAM_BASE) / PGSIZE;
}

static inline struct Page *idx2page(size_t idx) {
    return pa2page(DRAM_BASE + idx * PGSIZE);
}

/* Buddy system configuration */
#define MAX_ORDER 8
#define MIN_BLOCK_SIZE 1
#define BLOCK_SIZE(order) (1 << (order))
#define GET_ORDER(prop) ((prop) >> 24)
#define GET_SIZE(prop) ((prop) & 0x00FFFFFF)
#define MAKE_PROPERTY(order, size) (((order) << 24) | (size))

static free_area_t buddy_free_areas[MAX_ORDER + 1];
static size_t buddy_nr_free = 0;

/* Helper functions */
static inline int get_min_order(size_t n) {
    if (n == 0) return -1;
    int order = 0;
    while (BLOCK_SIZE(order) < n && order < MAX_ORDER) {
        order++;
    }
    return (order > MAX_ORDER) ? -1 : order;
}

static inline struct Page *get_buddy(struct Page *page, int order) {
    if (order < 0 || order > MAX_ORDER) return NULL;
    size_t page_idx = page2idx(page);
    size_t block_size = BLOCK_SIZE(order);
    size_t buddy_idx = page_idx ^ block_size;
    return (buddy_idx < npage) ? idx2page(buddy_idx) : NULL;
}

static inline bool is_block_head(struct Page *page) {
    if (!PageProperty(page)) return 0;
    int order = GET_ORDER(page->property);
    return (order >= 0 && order <= MAX_ORDER);
}

static inline int get_page_order(struct Page *page) {
    return GET_ORDER(page->property);
}

static inline size_t get_page_size(struct Page *page) {
    return GET_SIZE(page->property);
}

/* Initialize buddy system */
static void buddy_init(void) {
    for (int i = 0; i <= MAX_ORDER; i++) {
        list_init(&buddy_free_areas[i].free_list);
        buddy_free_areas[i].nr_free = 0;
    }
    buddy_nr_free = 0;
    cprintf("memory management: best_fit_pmm_manager\n");
}

static void buddy_init_memmap(struct Page *base, size_t n) {
    assert(n > 0 && base != NULL);
    struct Page *p = base;

    for (; p != base + n; p++) {
        assert(PageReserved(p));
        p->flags = 0;
        p->property = 0;
        set_page_ref(p, 0);
    }

    size_t remaining = n;
    p = base;
    while (remaining > 0) {
        int block_order = 0;
        while (BLOCK_SIZE(block_order + 1) <= remaining && (block_order + 1) <= MAX_ORDER) {
            block_order++;
        }
        size_t block_size = BLOCK_SIZE(block_order);

        struct Page *block_head = p;
        block_head->property = MAKE_PROPERTY(block_order, block_size);
        SetPageProperty(block_head);

        list_entry_t *le = &buddy_free_areas[block_order].free_list;
        while ((le = list_next(le)) != &buddy_free_areas[block_order].free_list) {
            if (le2page(le, page_link) > block_head) break;
        }
        list_add_before(le, &block_head->page_link);

        buddy_free_areas[block_order].nr_free++;
        buddy_nr_free += block_size;

        remaining -= block_size;
        p += block_size;
    }
}

/* Allocate continuous pages */
static struct Page *buddy_alloc_pages(size_t n) {
    assert(n > 0);
    if (n > buddy_nr_free) return NULL;

    int target_order = get_min_order(n);
    if (target_order == -1) return NULL;

    int found_order = -1;
    for (int i = target_order; i <= MAX_ORDER; i++) {
        if (buddy_free_areas[i].nr_free > 0) {
            found_order = i;
            break;
        }
    }
    if (found_order == -1) return NULL;

    free_area_t *curr_area = &buddy_free_areas[found_order];
    list_entry_t *le = list_next(&curr_area->free_list);
    struct Page *alloc_block = le2page(le, page_link);
    list_del(le);
    ClearPageProperty(alloc_block);
    curr_area->nr_free--;
    size_t found_size = BLOCK_SIZE(found_order);
    buddy_nr_free -= found_size;

    size_t current_size = found_size;
    int current_order = found_order;
    while (current_order > target_order) {
        current_order--;
        size_t half_size = BLOCK_SIZE(current_order);
        free_area_t *half_area = &buddy_free_areas[current_order];

        struct Page *buddy_block = alloc_block + half_size;
        buddy_block->property = MAKE_PROPERTY(current_order, half_size);
        SetPageProperty(buddy_block);

        list_entry_t *ins_le = &half_area->free_list;
        while ((ins_le = list_next(ins_le)) != &half_area->free_list) {
            if (le2page(ins_le, page_link) > buddy_block) break;
        }
        list_add_before(ins_le, &buddy_block->page_link);
        half_area->nr_free++;
        buddy_nr_free += half_size;

        current_size = half_size;
    }

    alloc_block->property = current_size;
    return alloc_block;
}

/* Free continuous pages */
static void buddy_free_pages(struct Page *base, size_t n) {
    assert(n > 0 && base != NULL);
    if (PageReserved(base)) return;

    int block_order = get_min_order(n);
    assert(BLOCK_SIZE(block_order) == n);
    struct Page *p = base;

    for (; p != base + n; p++) {
        assert(!PageProperty(p));
        p->flags = 0;
        p->property = 0;
        set_page_ref(p, 0);
    }

    base->property = MAKE_PROPERTY(block_order, n);
    SetPageProperty(base);
    buddy_nr_free += n;

    free_area_t *curr_area = &buddy_free_areas[block_order];
    list_entry_t *le = &curr_area->free_list;
    while ((le = list_next(le)) != &curr_area->free_list) {
        if (le2page(le, page_link) > base) break;
    }
    list_add_before(le, &base->page_link);
    curr_area->nr_free++;

    struct Page *current_block = base;
    int current_order = block_order;
    while (current_order < MAX_ORDER) {
        struct Page *buddy = get_buddy(current_block, current_order);
        if (buddy == NULL || !is_block_head(buddy) || get_page_order(buddy) != current_order) {
            break;
        }

        free_area_t *merge_area = &buddy_free_areas[current_order];
        list_del(&current_block->page_link);
        list_del(&buddy->page_link);
        ClearPageProperty(current_block);
        ClearPageProperty(buddy);
        merge_area->nr_free -= 2;
        buddy_nr_free -= BLOCK_SIZE(current_order) * 2;

        struct Page *merged_block = (current_block < buddy) ? current_block : buddy;
        int merged_order = current_order + 1;
        size_t merged_size = BLOCK_SIZE(merged_order);
        merged_block->property = MAKE_PROPERTY(merged_order, merged_size);
        SetPageProperty(merged_block);

        free_area_t *merged_area = &buddy_free_areas[merged_order];
        list_entry_t *ins_le = &merged_area->free_list;
        while ((ins_le = list_next(ins_le)) != &merged_area->free_list) {
            if (le2page(ins_le, page_link) > merged_block) break;
        }
        list_add_before(ins_le, &merged_block->page_link);
        merged_area->nr_free++;
        buddy_nr_free += merged_size;

        current_block = merged_block;
        current_order = merged_order;
    }
}

static size_t buddy_nr_free_pages(void) {
    return buddy_nr_free;
}

static void basic_check(void) {
    struct Page *p0 = buddy_alloc_pages(1);
    struct Page *p1 = buddy_alloc_pages(1);
    struct Page *p2 = buddy_alloc_pages(1);
    assert(p0 != NULL && p1 != NULL && p2 != NULL);
    assert(p0 != p1 && p0 != p2 && p1 != p2);

    buddy_free_pages(p0, 1);
    buddy_free_pages(p1, 1);
    buddy_free_pages(p2, 1);
    assert(buddy_nr_free_pages() == 3);

    assert(buddy_alloc_pages(2) != NULL);
    assert(buddy_nr_free_pages() == 1);
}

static void buddy_check(void) {
    int score = 0, sumscore = 6;
    size_t free0 = buddy_nr_free_pages();

    int total = 0;
    for (int i = 0; i <= MAX_ORDER; i++) {
        list_entry_t *le = &buddy_free_areas[i].free_list;
        while ((le = list_next(le)) != &buddy_free_areas[i].free_list) {
            struct Page *p = le2page(le, page_link);
            assert(PageProperty(p));
            total += get_page_size(p);
        }
    }
    assert(total == buddy_nr_free_pages());

    basic_check();
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif

    struct Page *p0 = buddy_alloc_pages(5);
    assert(p0 != NULL && !PageProperty(p0));
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif

    buddy_free_pages(p0 + 1, 2);
    buddy_free_pages(p0 + 4, 1);
    assert(buddy_alloc_pages(4) == NULL);
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif

    struct Page *p1 = buddy_alloc_pages(1);
    assert(p1 == p0 + 4);
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif

    buddy_free_pages(p0, 8);
    assert(buddy_alloc_pages(8) != NULL);
    assert(buddy_nr_free_pages() == free0 - 8);
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif

    buddy_free_pages(p0, 8);
    assert(buddy_nr_free_pages() == free0);
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif

    extern char boot_page_table_sv39[];
    uintptr_t *satp_virtual = (pte_t*)boot_page_table_sv39;
    uintptr_t satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
    cprintf("check_alloc_page() succeeded!\n");
}

const struct pmm_manager buddy_pmm_manager = {
    .name = "buddy_pmm_manager",
    .init = buddy_init,
    .init_memmap = buddy_init_memmap,
    .alloc_pages = buddy_alloc_pages,
    .free_pages = buddy_free_pages,
    .nr_free_pages = buddy_nr_free_pages,
    .check = buddy_check,
};