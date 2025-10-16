#include <defs.h>
#include <list.h>
#include <string.h>
#include <stdio.h>
#include <pmm.h>
#include <memlayout.h>
#include <slub_pmm.h>

/*
 Minimal, educational SLUB allocator built on top of a simple page allocator.
 - Size classes: 16, 32, 64, 128, 256, 512, 1024, 2048 bytes (<= 1 page)
 - For each class, keep three lists: partial, full, empty
 - Each slab occupies exactly one page; slab header lives at the beginning
 - Free objects are managed by a singly-linked freelist embedded in the object
 - When a slab becomes empty, we return its page to the page allocator

 Also provides a page allocator implementing the pmm_manager interface using
 a simple best-fit free-list over struct Page blocks, so this module is
 drop-in replaceable for best_fit in pmm.c if desired.
*/

/* -----------------------------
 * Internal page allocator (best-fit style)
 * ----------------------------- */

typedef struct {
    list_entry_t free_list;     // head of free block list (blocks are head pages)
    unsigned int nr_free;       // number of free pages in total
} slub_free_area_t;

static slub_free_area_t slub_free_area;

#define slub_free_list (slub_free_area.free_list)
#define slub_nr_free   (slub_free_area.nr_free)

static void slub_page_list_init(void) {
    list_init(&slub_free_list);
    slub_nr_free = 0;
}

static void slub_page_init_memmap(struct Page *base, size_t n) {
    assert(n > 0);
    struct Page *p = base;
    for (; p != base + n; p++) {
        assert(PageReserved(p));
        p->flags = 0;
        p->property = 0;
        set_page_ref(p, 0);
    }
    base->property = n;
    SetPageProperty(base);
    slub_nr_free += n;

    // insert ordered by address
    if (list_empty(&slub_free_list)) {
        list_add(&slub_free_list, &(base->page_link));
    } else {
        list_entry_t *le = &slub_free_list;
        while ((le = list_next(le)) != &slub_free_list) {
            if (le2page(le, page_link) > base) {
                break;
            }
        }
        list_add_before(le, &(base->page_link));
    }
}

static struct Page *slub_page_alloc_pages(size_t n) {
    assert(n > 0);
    if (n > slub_nr_free) return NULL;
    list_entry_t *le = &slub_free_list;
    struct Page *best = NULL;
    size_t best_size = (size_t)-1;

    // best-fit search
    while ((le = list_next(le)) != &slub_free_list) {
        struct Page *p = le2page(le, page_link);
        if (PageProperty(p) && p->property >= n && p->property < best_size) {
            best = p;
            best_size = p->property;
            if (best_size == n) break; // exact fit
        }
    }
    if (best == NULL) return NULL;

    // detach head page of the chosen block
    list_del(&(best->page_link));
    if (best_size > n) {
        // split remaining to a new head
        struct Page *rem = best + n;
        rem->property = best_size - n;
        SetPageProperty(rem);
        // insert rem back keeping order
        list_entry_t *pos = &slub_free_list;
        while ((pos = list_next(pos)) != &slub_free_list) {
            if (le2page(pos, page_link) > rem) break;
        }
        list_add_before(pos, &(rem->page_link));
    }
    ClearPageProperty(best);
    slub_nr_free -= n;
    return best;
}

static void slub_page_free_pages(struct Page *base, size_t n) {
    assert(n > 0);
    struct Page *p = base;
    for (; p != base + n; p++) {
        assert(!PageReserved(p) && !PageProperty(p));
        p->flags = 0;
        set_page_ref(p, 0);
    }
    base->property = n;
    SetPageProperty(base);
    slub_nr_free += n;

    // insert ordered
    list_entry_t *le = &slub_free_list;
    while ((le = list_next(le)) != &slub_free_list) {
        if (le2page(le, page_link) > base) break;
    }
    list_add_before(le, &(base->page_link));

    // try merge with prev
    list_entry_t *prev = list_prev(&(base->page_link));
    if (prev != &slub_free_list) {
        struct Page *pp = le2page(prev, page_link);
        if (pp + pp->property == base) {
            pp->property += base->property;
            list_del(&(base->page_link));
            base = pp;
        }
    }
    // try merge with next
    list_entry_t *next = list_next(&(base->page_link));
    if (next != &slub_free_list) {
        struct Page *pn = le2page(next, page_link);
        if (base + base->property == pn) {
            base->property += pn->property;
            list_del(&(pn->page_link));
        }
    }
}

static size_t slub_page_nr_free_pages(void) { return slub_nr_free; }

/* -----------------------------
 * SLUB structures & helpers
 * ----------------------------- */

typedef struct kmem_cache kmem_cache_t;
typedef struct slab slab_t;

struct slab {
    kmem_cache_t *cache;      // back reference
    uint16_t inuse;           // allocated objects
    uint16_t total;           // total objects
    uint16_t free_head;       // index of first free object, 0xFFFF if none
    list_entry_t list_link;   // in cache list
};

struct kmem_cache {
    size_t obj_size;          // requested object size
    size_t align;             // alignment (>= sizeof(void*))
    size_t obj_stride;        // size per object after alignment
    list_entry_t partial;     // slabs with free objects
    list_entry_t full;        // full slabs
    list_entry_t empty;       // empty slabs (fresh or fully freed)
};

static const size_t slub_size_classes[] = {16, 32, 64, 128, 256, 512, 1024, 2048};
#define SLUB_NUM_CLASSES (sizeof(slub_size_classes)/sizeof(slub_size_classes[0]))
static kmem_cache_t slub_caches[SLUB_NUM_CLASSES];
static int slub_inited = 0;

static inline size_t align_up(size_t x, size_t a) { return (x + a - 1) & ~(a - 1); }

static inline void *page2kva(struct Page *p) {
    return (void *)(page2pa(p) + va_pa_offset);
}

static inline char *slab_obj_area(slab_t *s) {
    return (char *)s + sizeof(slab_t);
}

static inline void *slab_idx_to_ptr(slab_t *s, uint16_t idx) {
    return (void *)(slab_obj_area(s) + (size_t)idx * s->cache->obj_stride);
}

static inline uint16_t slab_ptr_to_idx(slab_t *s, void *ptr) {
    return (uint16_t)(((char *)ptr - slab_obj_area(s)) / s->cache->obj_stride);
}

static slab_t *slab_from_ptr(void *ptr) {
    // slab header placed at the start of the page
    uintptr_t base = ROUNDDOWN((uintptr_t)ptr, PGSIZE);
    return (slab_t *)base;
}

static size_t slab_calc_capacity(kmem_cache_t *c) {
    size_t payload = PGSIZE - sizeof(slab_t);
    if (payload < c->obj_stride) return 0;
    return payload / c->obj_stride;
}

static slab_t *slab_create(kmem_cache_t *cache) {
    struct Page *pg = slub_page_alloc_pages(1);
    if (pg == NULL) return NULL;
    slab_t *slab = (slab_t *)page2kva(pg);
    memset(slab, 0, sizeof(*slab));
    slab->cache = cache;
    slab->total = (uint16_t)slab_calc_capacity(cache);
    if (slab->total == 0) {
        // no room for any object, give back the page
        slub_page_free_pages(pg, 1);
        return NULL;
    }
    slab->inuse = 0;
    slab->free_head = 0;
    list_init(&slab->list_link);

    // initialize embedded freelist: store next index in first 2 bytes of each object slot
    for (uint16_t i = 0; i < slab->total; i++) {
        void *obj = slab_idx_to_ptr(slab, i);
        uint16_t next = (i + 1U < slab->total) ? (uint16_t)(i + 1U) : (uint16_t)0xFFFF;
        *(uint16_t *)obj = next;
    }
    // newly created slab is empty (all free)
    list_add(&cache->empty, &slab->list_link);
    return slab;
}

static void slab_destroy(slab_t *slab) {
    // return the page
    struct Page *pg = pa2page((uintptr_t)slab - va_pa_offset);
    slub_page_free_pages(pg, 1);
}

static void cache_init(kmem_cache_t *c, size_t size) {
    c->obj_size = size;
    c->align = sizeof(void *);
    c->obj_stride = align_up(c->obj_size, c->align);
    list_init(&c->partial);
    list_init(&c->full);
    list_init(&c->empty);
}

static kmem_cache_t *slub_pick_cache(size_t size) {
    for (size_t i = 0; i < SLUB_NUM_CLASSES; i++) {
        if (size <= slub_caches[i].obj_size) return &slub_caches[i];
    }
    return NULL;
}

static void *slub_alloc_from_slab(kmem_cache_t *c, slab_t *slab) {
    if (slab->free_head == 0xFFFF) return NULL;
    uint16_t idx = slab->free_head;
    void *obj = slab_idx_to_ptr(slab, idx);
    slab->free_head = *(uint16_t *)obj; // pop next index
    slab->inuse++;
    // move list if necessary
    if (slab->inuse == slab->total) {
        // move to full
        list_del(&slab->list_link);
        list_add(&c->full, &slab->list_link);
    } else {
        // remain/ensure in partial: the caller should have placed slab in partial
    }
    return obj;
}

// Public API: kmalloc/kfree (optional use)
void *kmalloc(size_t size) {
    if (!slub_inited) {
        // Initialize once lazily if not yet
        // Note: page lists should already be inited by pmm init
        for (size_t i = 0; i < SLUB_NUM_CLASSES; i++) {
            cache_init(&slub_caches[i], slub_size_classes[i]);
        }
        slub_inited = 1;
    }
    if (size == 0) return NULL;
    kmem_cache_t *c = slub_pick_cache(size);
    if (c == NULL) {
        // not supported size (too large). For simplicity, return NULL
        return NULL;
    }

    // choose a slab: partial > empty > create
    slab_t *slab = NULL;
    if (!list_empty(&c->partial)) {
        slab = to_struct(list_next(&c->partial), slab_t, list_link);
    } else if (!list_empty(&c->empty)) {
        slab = to_struct(list_next(&c->empty), slab_t, list_link);
        // move to partial for allocation
        list_del(&slab->list_link);
        list_add(&c->partial, &slab->list_link);
    } else {
        slab = slab_create(c);
        if (slab == NULL) return NULL;
        // move to partial immediately
        list_del(&slab->list_link);
        list_add(&c->partial, &slab->list_link);
    }

    void *obj = slub_alloc_from_slab(c, slab);
    if (obj == NULL) return NULL; // should not happen
    return obj;
}

void kfree(void *ptr) {
    if (ptr == NULL) return;
    slab_t *slab = slab_from_ptr(ptr);
    kmem_cache_t *c = slab->cache;
    // sanity: within object area and aligned
    char *area = slab_obj_area(slab);
    uintptr_t off = (uintptr_t)((char *)ptr - area);
    if (off >= (uintptr_t)PGSIZE || (off % c->obj_stride) != 0) {
        // invalid pointer, ignore in minimal version
        return;
    }
    uint16_t idx = slab_ptr_to_idx(slab, ptr);
    // push back to freelist (store next index into object)
    *(uint16_t *)ptr = slab->free_head;
    slab->free_head = idx;
    slab->inuse--;

    // move between lists
    if (slab->inuse == 0) {
        // became empty: return the page back immediately (keep it minimal)
        list_del(&slab->list_link);
        slab_destroy(slab);
    } else if (slab->inuse < slab->total) {
        // ensure it sits in partial list (relink unconditionally for simplicity)
        list_del(&slab->list_link);
        list_add(&c->partial, &slab->list_link);
    }
}

/* -----------------------------
 * pmm_manager implementation (page-level)
 * ----------------------------- */

static void slub_init(void) {
    // init page free area list
    slub_page_list_init();
    // init caches
    for (size_t i = 0; i < SLUB_NUM_CLASSES; i++) {
        cache_init(&slub_caches[i], slub_size_classes[i]);
    }
    slub_inited = 1;
}

static void slub_init_memmap(struct Page *base, size_t n) {
    slub_page_init_memmap(base, n);
}

static struct Page *slub_alloc_pages_iface(size_t n) {
    return slub_page_alloc_pages(n);
}

static void slub_free_pages_iface(struct Page *base, size_t n) {
    slub_page_free_pages(base, n);
}

static size_t slub_nr_free_pages_iface(void) { return slub_page_nr_free_pages(); }

static void slub_check(void) {
    // Basic sanity: allocate and free a few pages
    struct Page *a = slub_alloc_pages_iface(1);
    struct Page *b = slub_alloc_pages_iface(2);
    assert(a != NULL && b != NULL && a != b);
    slub_free_pages_iface(a, 1);
    slub_free_pages_iface(b, 2);

    // Optional: quick kmalloc smoke test
    void *p = kmalloc(64);
    void *q = kmalloc(32);
    assert(p != NULL && q != NULL);
    kfree(p);
    kfree(q);
}

const struct pmm_manager slub_pmm_manager = {
    .name = "slub_pmm_manager",
    .init = slub_init,
    .init_memmap = slub_init_memmap,
    .alloc_pages = slub_alloc_pages_iface,
    .free_pages = slub_free_pages_iface,
    .nr_free_pages = slub_nr_free_pages_iface,
    .check = slub_check,
};
