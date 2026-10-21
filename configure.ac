#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)
AC_INIT([madedit-mod], [0.4.18], [minggang.li@gmail.com])
AC_CONFIG_SRCDIR([src/MadEditApp.cpp])
AC_CONFIG_HEADER([config.h])
AC_PREFIX_DEFAULT([/usr])

AM_INIT_AUTOMAKE([subdir-objects])

AC_USE_SYSTEM_EXTENSIONS
ALL_LINGUAS="it_IT ja_JP zh_CN zh_TW ru_RU es el de_DE pl_PL"
AM_GNU_GETTEXT([external])
AC_SUBST(ALL_LINGUAS)

# Checks for programs.
AC_PROG_CXX
AC_PROG_INSTALL
AC_LANG(C++)

# Debug / Release 組態。
# 預設是 release：最佳化並定義 NDEBUG（關掉 wxWidgets 的 assert 與
# minipython 的 assert）。需要除錯時用 --enable-debug。
AC_ARG_ENABLE([debug],
    [  --enable-debug          build with debug info and assertions (default: no)],
    [], [enable_debug=no])

# AM_INIT_AUTOMAKE 會呼叫 AC_PROG_CC，把 CFLAGS 預設成 "-g -O2"。
# 使用者沒有另外指定時，release 組態不需要除錯資訊，改回 "-O2"。
if test "x$ac_cv_env_CFLAGS_set" != xset && test "x$CFLAGS" = "x-g -O2"; then
    CFLAGS="-O2"
fi
if test "x$ac_cv_env_CXXFLAGS_set" != xset && test "x$CXXFLAGS" = "x-g -O2"; then
    CXXFLAGS="-O2"
fi

if test "x$enable_debug" = xyes; then
    CXXFLAGS="$CXXFLAGS -g -O0 -D_DEBUG -DDEBUG"
    CFLAGS="$CFLAGS -g -O0"
else
    CXXFLAGS="$CXXFLAGS -DNDEBUG"
    CFLAGS="$CFLAGS -DNDEBUG"
fi

CXXFLAGS="$CXXFLAGS -Wno-write-strings -fno-strict-aliasing -fPIC"

# Checks for MacOS
IS_MACOS=
case "${host}" in
    *-*-darwin* | powerpc-apple-macos* )
        IS_MACOS=1
    ;;
esac

# 判斷目標平台是不是 Windows。
# minipython 裡 Modules/getpath.c 與 PC/getpathp.c 是同一個功能在
# Unix 與 Windows 各自的實作，必須依平台二選一，
# 否則會出現 getpath 等符號重複定義而無法連結。
build_windows=no
case "${host}" in
    *-*-mingw* | *-*-cygwin* | *-*-msys* )
        build_windows=yes
    ;;
esac
AM_CONDITIONAL([BUILD_WINDOWS], [test "x$build_windows" = xyes])

# 選用的 GTK+ 版本。
# 只有在使用 wxGTK port 時才有意義；Windows 的 wxMSW 與 macOS 的 wxCocoa
# 都不依賴 GTK，因此這個選項在那兩個平台會被忽略。
want_GTK=
AC_ARG_WITH(gtk,
[  --with-gtk=version    use specified GTK+,
                otherwise try to find GTK+2 then try GTK+3],
[want_GTK="$withval"],
[want_GTK=0])

#if test "x$IS_MACOS" == "x"; then
#    PKG_CHECK_MODULES(python, [
#            python >= 2.7
#    ])
#    CXXFLAGS="$CXXFLAGS $python_CFLAGS"
#    LIBS="$LIBS $python_LIBS"
#fi

# option for additional Xpressive lib
AC_ARG_WITH(xpressive,
    [  --with-xpressive=PATH   use additional Boost.Xpressive library path,
                          otherwise use default path "$(top_srcdir)/xpressive"],
    [CXXFLAGS="$CXXFLAGS -I$withval"],
    [CXXFLAGS="$CXXFLAGS -I\$(top_srcdir)/xpressive"])

# option for additional Boost lib
AC_ARG_WITH(boost,
    [  --with-boost=PATH       use additional Boost library path,
                          otherwise use system include path],
    [CXXFLAGS="$CXXFLAGS -I$withval"])
#    [LIBS="$LIBS $withval/stage/lib/libboost_python.a"])

# Checks for wxWidgets library
WX_LIBS_set="0"
if test "x$WX_LIBS" != "x"; then
    WX_LIBS_set="1"
fi

AM_OPTIONS_WXCONFIG
with_wxdir_set="0"
AC_ARG_WITH(wxdir,
    [ --with-wxdir=PATH    Use uninstalled version of wxWidgets in PATH,
                          otherwise use installed version of wxWidgets],
    [with_wxdir_set="1"])

if test "$with_wxdir_set" != 1; then
    AM_PATH_WXCONFIG(2.8.0, wxWin=1, , [std,net,aui,html], )
else
    AM_PATH_WXCONFIG(2.8.0, wxWin=1, , [std,net,aui,html], [--static])
fi

#AM_PATH_WXCONFIG(2.8.0, wxWin=1, , [std,net,aui,html], [--static])
if test "$wxWin" != 1; then
   AC_MSG_ERROR([
           wxWidgets must be installed on your system
           but wx-config script couldn't be found.

           Please check that wx-config is in path, the directory
           where wxWidgets libraries are installed (returned by
           'wx-config --libs' command) is in LD_LIBRARY_PATH or
           equivalent variable and wxWidgets version is 2.8.0 or above.
   ])
fi
CPPFLAGS="$CPPFLAGS $WX_CPPFLAGS"
CXXFLAGS="$CXXFLAGS $WX_CXXFLAGS_ONLY"
#CFLAGS="$CFLAGS $WX_CFLAGS_ONLY"
if test "$WX_LIBS_set" != 1; then
    LIBS="$LIBS $WX_LIBS"
fi

# Windows 專用設定。必須放在 AM_PATH_WXCONFIG 之後，
# 因為要用到 wx-config 提供的資訊。
if test "x$build_windows" = xyes; then
    # GDI32 提供文字繪製（ExtTextOutW、SetTextColor 等），
    # IMM32 提供輸入法組字（ImmGetContext 等）。Unix/macOS 不需要這兩個。
    LIBS="$LIBS -lgdi32 -limm32"

    # 把 wxWidgets 的資源檔（wx.rc）編進執行檔。
    # wx.rc 內含 Common Controls v6 的 manifest 與 DPI 感知設定，
    # 少了它 wxWidgets 啟動時會跳警告視窗，控制項也會用舊樣式。
    AC_CHECK_TOOL([WINDRES], [windres])

    # wx.rc 裡以 "wx/msw/xxx" 的方式參照游標與 manifest 檔案，
    # 所以要把 wx-config 給的 include 路徑一併傳給 windres。
    WX_RC_INCLUDE_FLAGS=`$WX_CONFIG_WITH_ARGS --cxxflags | tr ' ' '\n' | grep '^-I' | tr '\n' ' '`
    AC_SUBST([WX_RC_INCLUDE_FLAGS])

    # 與 msw/vc17 的 Visual Studio 專案一致，採用 Per-Monitor V2 的 DPI 感知。
    CXXFLAGS="$CXXFLAGS -DwxUSE_DPI_AWARE_MANIFEST=2"
fi

# 判斷 wxWidgets 實際使用的是哪一個 port。
# 只有 GTK port 需要 GTK+/glib 與 libX11；
# Windows 的 wxMSW 與 macOS 的 wxCocoa 都不依賴它們。
WX_IS_GTK=0
if echo "$WX_LIBS" | grep -qi 'gtk'; then
    WX_IS_GTK=1
fi
AC_MSG_CHECKING([whether wxWidgets is built against GTK])
AC_MSG_RESULT([$WX_IS_GTK])

# Checks for glib2, gtk2 libraries
#AM_PATH_GLIB_2_0(2.6.0)
#AM_PATH_GTK_2_0(2.6.0)
if test "$WX_IS_GTK" = 1; then
    case "$want_GTK" in
        3)     ;;
        2)     ;;
        0)     ;;
        *)      AC_MSG_ERROR([
Unsupported GTK+ version $want_GTK specified. Only GTK+2 and GTK+3
are supported. 0 is auto.
                        ])
                ;;
    esac

    have_GTK=
    PKG_CHECK_MODULES(glib_gtk2, [
            glib-2.0 >= 2.6.0
            gtk+-2.0 >= 2.6.0
    ], have_GTK=2, have_GTK=0)

    if test "$have_GTK" -ne 0; then
        if test "$want_GTK" -eq 0; then
            CXXFLAGS="$CXXFLAGS $glib_gtk2_CFLAGS"
            LIBS="$LIBS $glib_gtk2_LIBS"
        else
            if test "$want_GTK" -eq "$have_GTK"; then
                CXXFLAGS="$CXXFLAGS $glib_gtk2_CFLAGS"
                LIBS="$LIBS $glib_gtk2_LIBS"
            else
                PKG_CHECK_MODULES(glib_gtk3, [
                    glib-2.0 >= 2.6.0
                    gtk+-3.0
                ])
                CXXFLAGS="$CXXFLAGS $glib_gtk3_CFLAGS"
                LIBS="$LIBS $glib_gtk3_LIBS"
            fi
        fi
    else
        if test "$want_GTK" -eq 2; then
            AC_MSG_ERROR([
Package gtk+-2.0 was not found in the pkg-config search path.
Perhaps you should add the directory containing `gtk+-2.0.pc' to your PKG_CONFIG_PATH environment variable
No package 'gtk+-2.0' found
            ])
        fi
        PKG_CHECK_MODULES(glib_gtk3, [
            glib-2.0 >= 2.6.0
            gtk+-3.0
        ])
        CXXFLAGS="$CXXFLAGS $glib_gtk3_CFLAGS"
        LIBS="$LIBS $glib_gtk3_LIBS"
    fi

    # Make sure we have X11, and also have it added to LIBS
    #AC_CHECK_LIB([X11], [main],[ac_X11="yes"],[ac_X11="no"])
    #if test "x$ac_X11" = "xno"; then
    #   AC_MSG_ERROR([Could not find XOpenDisplay in X11.])
    #else
    #   LIBS="$LIBS -lX11"
    #fi
    # libX11 只存在於 X11 平台的 GTK 版 wxWidgets；
    # Windows(wxMSW) 與 macOS(wxCocoa) 沒有這個函式庫。
    LIBS="$LIBS -lX11"
fi

UNICODE_FLAG=$(test ! $($WX_CONFIG_WITH_ARGS - -unicode >/dev/null 2>&1))

AC_MSG_CHECKING([if wxWidgets was built with UNICODE enabled])
if test "$UNICODE_FLAG" != "0"; then
    AC_MSG_RESULT([yes])
else
    AC_MSG_RESULT([no])
    AC_MSG_ERROR([wxWidgets must be built with UNICODE enabled.])
fi

# Make sure we have hunspell, and also have it added to LIBS
# Checks for header files.
#AC_CHECK_HEADERS([hunspell/hunspell.hxx])
#LIBS="$LIBS -lhunspell"
#if test "x$IS_MACOS" == "x"; then
#    PKG_CHECK_MODULES(hunspell, [
#            hunspell >= 1.3
#    ])
#    CXXFLAGS="$CXXFLAGS $hunspell_CFLAGS"
#    LIBS="$LIBS $hunspell_LIBS"
#fi

# Checks for header files.
AC_CHECK_HEADERS([boost/config.hpp])

# Checks for typedefs, structures, and compiler characteristics.
#AC_HEADER_STDBOOL
AC_C_CONST
AC_C_INLINE
AC_TYPE_SIZE_T

# Checks for library functions.
#AC_FUNC_MALLOC
#AC_HEADER_STDC
AC_CHECK_FUNCS([dup2])

AC_CONFIG_FILES([Makefile syntax/Makefile scripts/Makefile po/Makefile.in])

AC_OUTPUT
