/* macOS 專用的 pyconfig.h。
 *
 * 以 64 位元 Unix 的設定為基底，再覆寫 macOS 特有的幾個定義。
 * minipython 裡被編譯的模組集合不含 selectmodule / posixmodule，
 * 因此 select 相關的 HAVE_EPOLL / HAVE_KQUEUE 影響有限，但仍要修正，
 * 否則會留下「宣告了卻不存在」的定義。
 *
 * 差異清單：
 *   - macOS 沒有 epoll
 *   - macOS 沒有 <linux/netlink.h> 與 <linux/tipc.h>
 *   - macOS 沒有 <asm/types.h>
 *   - arm64 沒有 x87 浮點暫存器，不能走 GCC_ASM_FOR_X87 的 long double 路徑
 *   - macOS 沒有 fstatvfs()（只有 statvfs() / fstatfs()）
 *   - macOS 有 kqueue
 */

/* pyconfig-64.h 自帶 Py_PYCONFIG_H 的保護，所以這裡不再另外包一層。 */
#include "pyconfig-64.h"

#undef HAVE_EPOLL
#undef HAVE_LINUX_NETLINK_H
#undef HAVE_LINUX_TIPC_H
#undef HAVE_ASM_TYPES_H
#undef HAVE_GCC_ASM_FOR_X87
#undef HAVE_FSTATVFS

#ifndef HAVE_KQUEUE
#define HAVE_KQUEUE 1
#endif
