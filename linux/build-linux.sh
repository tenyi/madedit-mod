#!/bin/sh
# 在 Linux 上建置 MadEdit-Mod，並安裝到 user-local 前綴（不需要 root）。
#
# 用法：
#   sh linux/build-linux.sh [選項]
#
# 選項：
#   --prefix=PATH     安裝前綴（預設 ~/.local）
#   --jobs=N          同時編譯的行程數（預設 nproc）
#   --debug           產生含除錯資訊與 assert 的版本（預設為 release）
#   --no-wx           不要自動建置 wxWidgets，只用系統已有的 wx-config
#   --wx-version=VER  要建置的 wxWidgets 版本（預設 3.3.4）
#
# 產物：
#   $PREFIX/bin/madedit            可執行檔
#   $PREFIX/share/madedit-mod/     syntax/ 與 scripts/ 資料檔
#   $PREFIX/share/locale/          翻譯檔
#
# 這個腳本會做四件事：
#   1. 檢查 wxWidgets（需 3.3 以上）與 Boost 標頭檔是否齊備，缺的話就地補上
#   2. 產生 configure 與 Makefile.in
#   3. 執行 configure 與 make
#   4. make install 安裝到前綴
#
# 為什麼需要 wxWidgets 3.3 以上？
#   MadEdit 用到 wxList::compatibility_iterator 與 wxAuiNotebookPageArray，
#   這兩個 API 在 wxWidgets 3.3 之後才提供。發行版的套件庫通常只有 3.2，
#   所以這支腳本會在 ~/.local/opt/ 下自建一份 wxWidgets。

set -e

cd "$(dirname "$0")/.." || exit 1

PREFIX="$HOME/.local"
JOBS=$(nproc 2>/dev/null || echo 4)
BUILD_TYPE=release
WX_VERSION=3.3.4
AUTO_WX=1

for arg in "$@"; do
    case "$arg" in
        --prefix=*)     PREFIX="${arg#*=}" ;;
        --jobs=*)       JOBS="${arg#*=}" ;;
        --wx-version=*) WX_VERSION="${arg#*=}" ;;
        --debug)        BUILD_TYPE=debug ;;
        --no-wx)        AUTO_WX=0 ;;
        -h|--help)
            sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            echo "未知選項：$arg（用 --help 看說明）" >&2
            exit 1 ;;
    esac
done

WX_PREFIX="$HOME/.local/opt/wxwidgets-$WX_VERSION"
WX_SRC="$HOME/.local/src/wxWidgets-$WX_VERSION"
BOOST_INCLUDE="$HOME/.local/include"

# --- 1. wxWidgets --------------------------------------------------------
# 系統的 wx-config 若已是 3.3 以上就直接用。
need_wx=1
if command -v wx-config >/dev/null 2>&1; then
    have=$(wx-config --version 2>/dev/null || echo 0)
    major=$(echo "$have" | cut -d. -f1)
    minor=$(echo "$have" | cut -d. -f2)
    if [ "$major" -gt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -ge 3 ]; }; then
        echo "使用系統的 wxWidgets $have"
        need_wx=0
    fi
fi

if [ "$need_wx" -eq 1 ]; then
    if [ -x "$WX_PREFIX/bin/wx-config" ]; then
        echo "使用已建好的 wxWidgets $WX_PREFIX"
    else
        if [ "$AUTO_WX" -eq 0 ]; then
            echo "錯誤：找不到 wxWidgets 3.3 以上，且指定了 --no-wx。" >&2
            echo "請先安裝（Debian/Ubuntu）：" >&2
            echo "  apt install libwxgtk3.2-dev   # 注意：3.2 不符合本專案需求" >&2
            echo "或直接執行本腳本（不加 --no-wx）來自建 wxWidgets $WX_VERSION。" >&2
            exit 1
        fi
        echo "開始建置 wxWidgets $WX_VERSION（會花一些時間）..."
        mkdir -p "$HOME/.local/src" "$HOME/.local/opt"
        if [ ! -d "$WX_SRC" ]; then
            echo "下載 wxWidgets $WX_VERSION..."
            tarball="$HOME/.local/src/wxWidgets-$WX_VERSION.tar.bz2"
            url="https://github.com/wxWidgets/wxWidgets/releases/download/v$WX_VERSION/wxWidgets-$WX_VERSION.tar.bz2"
            curl -fL -o "$tarball" "$url" || { echo "下載失敗：$url" >&2; exit 1; }
            tar xf "$tarball" -C "$HOME/.local/src"
        fi
        mkdir -p "$WX_SRC/build"
        cd "$WX_SRC/build"
        ../configure --prefix="$WX_PREFIX" \
            --with-gtk=3 \
            --enable-shared \
            --disable-debug_flag \
            --disable-precomp-headers \
            > configure.log 2>&1 || { echo "wxWidgets configure 失敗，詳見 configure.log" >&2; exit 1; }
        make -j"$JOBS" > make.log 2>&1 || { echo "wxWidgets 編譯失敗，詳見 make.log" >&2; exit 1; }
        make install > install.log 2>&1 || { echo "wxWidgets 安裝失敗" >&2; exit 1; }
        cd - >/dev/null
        echo "wxWidgets $WX_VERSION 已安裝到 $WX_PREFIX"
    fi
    PATH="$WX_PREFIX/bin:$PATH"
    export PATH
    LD_LIBRARY_PATH="$WX_PREFIX/lib:${LD_LIBRARY_PATH:-}"
    export LD_LIBRARY_PATH
fi

echo "wxWidgets 版本：$(wx-config --version)"

# --- 2. Boost 標頭檔 ----------------------------------------------------
# Boost.Xpressive 與 Boost.Python 的標頭檔是必要的（不需要 Boost 的函式庫）。
if [ ! -f "$BOOST_INCLUDE/boost/config.hpp" ]; then
    if [ ! -f /usr/include/boost/config.hpp ]; then
        echo "錯誤：找不到 Boost 標頭檔。" >&2
        echo "  Arch:   sudo pacman -S boost" >&2
        echo "  Debian: sudo apt install libboost-dev" >&2
        echo "或把 Boost 標頭檔放到 $BOOST_INCLUDE/boost/。" >&2
        exit 1
    fi
    BOOST_INCLUDE=/usr/include
fi
echo "Boost 標頭檔：$BOOST_INCLUDE"

# --- 3. 產生 configure 與 Makefile.in -----------------------------------
if [ ! -f configure ] || [ configure.ac -nt configure ]; then
    echo "產生 configure..."
    sh ./autogen.sh
fi

# --- 4. configure 與 make ------------------------------------------------
if [ "$BUILD_TYPE" = debug ]; then
    EXTRA_CXXFLAGS="-O0 -g"
    EXTRA_LDFLAGS=""
else
    EXTRA_CXXFLAGS="-O2 -DNDEBUG"
    EXTRA_LDFLAGS="-DNDEBUG"
fi

echo "執行 configure..."
./configure \
    --prefix="$PREFIX" \
    --with-boost="$BOOST_INCLUDE" \
    CPPFLAGS="-I$BOOST_INCLUDE" \
    CXXFLAGS="$EXTRA_CXXFLAGS" \
    LDFLAGS="-Wl,-rpath,$WX_PREFIX/lib $EXTRA_LDFLAGS"

echo "編譯（-j$JOBS）..."
make -j"$JOBS"

# --- 5. 安裝 -------------------------------------------------------------
echo "安裝到 $PREFIX ..."
make install

# 拼字檢查用的字典預設放在 ~/.madedit/Dictionaries
MADEDIT_HOME="$HOME/.madedit"
if [ -d Dictionaries ] && [ ! -d "$MADEDIT_HOME/Dictionaries" ]; then
    mkdir -p "$MADEDIT_HOME/Dictionaries"
    cp -f Dictionaries/* "$MADEDIT_HOME/Dictionaries/"
    echo "已安裝拼字檢查字典到 $MADEDIT_HOME/Dictionaries"
fi

# 桌面項目與圖示的快取
[ -d "$PREFIX/share/pixmaps" ] && gtk-update-icon-cache -f -t "$PREFIX/share/pixmaps" 2>/dev/null || true
[ -d "$PREFIX/share/applications" ] && update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true

echo
echo "完成。執行檔：$PREFIX/bin/madedit"
