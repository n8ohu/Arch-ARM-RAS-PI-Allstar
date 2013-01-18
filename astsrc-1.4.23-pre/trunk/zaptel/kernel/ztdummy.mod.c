#include <linux/module.h>
#include <linux/vermagic.h>
#include <linux/compiler.h>

MODULE_INFO(vermagic, VERMAGIC_STRING);

struct module __this_module
__attribute__((section(".gnu.linkonce.this_module"))) = {
 .name = KBUILD_MODNAME,
 .init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
 .exit = cleanup_module,
#endif
 .arch = MODULE_ARCH_INIT,
};

static const struct modversion_info ____versions[]
__used
__attribute__((section("__versions"))) = {
	{ 0xc54e0a01, "module_layout" },
	{ 0x3ec8886f, "param_ops_int" },
	{ 0x1ccddfd7, "zt_unregister" },
	{ 0x9804a5aa, "hrtimer_cancel" },
	{ 0xc5ae0182, "malloc_sizes" },
	{ 0x37a0cba, "kfree" },
	{ 0x7e277415, "hrtimer_start" },
	{ 0x2c8a5e3, "hrtimer_init" },
	{ 0x72226691, "zt_register" },
	{ 0xf6288e02, "__init_waitqueue_head" },
	{ 0x91715312, "sprintf" },
	{ 0xb81960ca, "snprintf" },
	{ 0xfa2a45e, "__memzero" },
	{ 0x8836fca7, "kmem_cache_alloc" },
	{ 0xefd6cf06, "__aeabi_unwind_cpp_pr0" },
	{ 0x27e1a049, "printk" },
	{ 0x6128b5fc, "__printk_ratelimit" },
	{ 0x30d514aa, "hrtimer_forward" },
	{ 0x2fa3c81a, "zt_transmit" },
	{ 0xfaf4a7cc, "zt_receive" },
};

static const char __module_depends[]
__used
__attribute__((section(".modinfo"))) =
"depends=zaptel";


MODULE_INFO(srcversion, "6F151CB6533BBE31F834731");
