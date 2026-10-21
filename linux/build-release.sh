#!/bin/sh
# 產生可發布的 Linux 版壓縮檔（格式與 Windows 版的 .zip 一致）。
#
# 用法：
#   sh linux/build-release.sh [選項]
#
# 選項：
#   --version=VER      產物名稱用的版本號（預設取 git 的最新 tag）
#   --jobs=N           同時編譯的行程數（預設 nproc）
#   --output=DIR       產物輸出目錄（預設 dist/）
#   --upload           建置完成後用 gh 上傳到該 tag 的 GitHub Release
#
# 產物：
#   $OUTPUT/MadEdit-Mod-<版本>-linux-x86_64.tar.gz
#
# 產物結構與 Windows 版相同：
#   MadEdit-Mod-<版本>-linux-x86_64/
#       madedit          執行檔（靜態連結 wxWidgets，只需系統的 GTK3）
#       README.md        專案說明
#       gpl-3.0.txt      授權條款
#       madedit.desktop  桌面項目（Linux 專用）
#       madedit.xpm      圖示（Linux 專用）
#       Dictionaries/    拼字檢查字典
#       locale/          翻譯檔
#       scripts/         MadPython 巨集腳本
#       syntax/          語法高亮定義
#
# 注意 locale 的位置：翻譯檔放在執行檔旁邊的 locale/ 目錄，
# 與 Windows 版一致。MadEdit 會把這個目錄交給
# wxLocale::AddCatalogLookupPathPrefix()，wxWidgets 3.3 會在底下尋找
# <語言>/LC_MESSAGES/madedit-mod.mo。
# 詳細規則見「How to build MadEdit-Mod.txt」。
#
# 為什麼要靜態連結 wxWidgets？
#   各發行版的 wxWidgets 套件庫多半只有 3.2，而本專案需要 3.3 以上，
#   所以把 wxWidgets 靜態連結進執行檔，使用者就不必自己安裝 wxWidgets。

set -e

cd "$(dirname "$0")/.." || exit 1

VERSION=""
JOBS=$(nproc 2>/dev/null || echo 4)
OUTPUT=dist
UPLOAD=0
WX_VERSION=3.3.4
WX_PREFIX="$HOME/.local/opt/wxwidgets-$WX_VERSION-static"
WX_SRC="$HOME/.local/src/wxWidgets-$WX_VERSION"
BOOST_INCLUDE="$HOME/.local/include"

for arg in "$@"; do
    case "$arg" in
        --version=*) VERSION="${arg#*=}" ;;
        --jobs=*)    JOBS="${arg#*=}" ;;
        --output=*)  OUTPUT="${arg#*=}" ;;
        --upload)    UPLOAD=1 ;;
        -h|--help)
            sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            echo "未知選項：$arg" >&2
            exit 1 ;;
    esac
done

if [ -z "$VERSION" ]; then
    VERSION=$(git describe --tags --abbrev=0 2>/dev/null || cat VERSION.txt)
fi
PKG="MadEdit-Mod-$VERSION-linux-x86_64"

# 輸出目錄相對於專案根目錄（後面會 cd 到別的建置目錄）
case "$OUTPUT" in
    /*) ;;
    *) OUTPUT="$(pwd)/$OUTPUT" ;;
esac

# --- 1. 靜態 wxWidgets ---------------------------------------------------
if [ ! -x "$WX_PREFIX/bin/wx-config" ]; then
    echo "== 建立靜態 wxWidgets $WX_VERSION =="
    mkdir -p "$HOME/.local/src" "$HOME/.local/opt"
    if [ ! -d "$WX_SRC" ]; then
        tarball="$HOME/.local/src/wxWidgets-$WX_VERSION.tar.bz2"
        url="https://github.com/wxWidgets/wxWidgets/releases/download/v$WX_VERSION/wxWidgets-$WX_VERSION.tar.bz2"
        curl -fL -o "$tarball" "$url" || { echo "下載失敗：$url" >&2; exit 1; }
        tar xf "$tarball" -C "$HOME/.local/src"
    fi
    mkdir -p "$WX_SRC/build"
    ( cd "$WX_SRC/build" &&
      ../configure --prefix="$WX_PREFIX" \
          --with-gtk=3 \
          --disable-shared \
          --disable-debug_flag \
          --disable-precomp-headers \
          > configure.log 2>&1 &&
      make -j"$JOBS" > make.log 2>&1 &&
      make install > install.log 2>&1 ) \
      || { echo "wxWidgets 建置失敗，詳見 $WX_SRC/build/*.log" >&2; exit 1; }
fi
echo "== wxWidgets =="
"$WX_PREFIX/bin/wx-config" --version

# --- 2. Boost 標頭檔 ----------------------------------------------------
if [ ! -f "$BOOST_INCLUDE/boost/config.hpp" ]; then
    if [ -f /usr/include/boost/config.hpp ]; then
        BOOST_INCLUDE=/usr/include
    else
        echo "錯誤：找不到 Boost 標頭檔。" >&2
        echo "  Arch:   sudo pacman -S boost" >&2
        echo "  Debian: sudo apt install libboost-dev" >&2
        exit 1
    fi
fi

# --- 3. 用獨立的前綴建置，避免污染開發用的建置目錄 -----------------------
BUILD_DIR="$HOME/.local/src/madedit-build-$VERSION"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/src-tree"

# 只複製版本控制追蹤的檔案，避免把開發目錄裡的 .o 與舊的 config.status 帶進來
git ls-files -z | tar --null -T - -cf - | tar xf - -C "$BUILD_DIR/src-tree"
# linux/ 是新加入、還沒進版控的建置腳本，一併帶過去
if [ -d linux ]; then
    cp -r linux "$BUILD_DIR/src-tree/linux"
fi

cd "$BUILD_DIR/src-tree" || exit 1

echo "== 產生 configure =="
sh ./autogen.sh

echo "== configure（靜態連結 wxWidgets）=="
# 把靜態 wxWidgets 的 bin 放在 PATH 最前面。這份 wxWidgets 只建了靜態函式庫，
# 所以 wx-config --libs 本身就會回傳 .a 與所需的系統函式庫，
# 不需要另外指定 --with-wxdir（那會讓 wx-config 依賴建置目錄）。
PATH="$WX_PREFIX/bin:$PATH" \
LD_LIBRARY_PATH="$WX_PREFIX/lib:${LD_LIBRARY_PATH:-}" \
./configure \
    --prefix="$BUILD_DIR/install" \
    --with-boost="$BOOST_INCLUDE" \
    CPPFLAGS="-I$BOOST_INCLUDE" \
    CXXFLAGS="-O2 -DNDEBUG" \
    > configure.log 2>&1 || { echo "configure 失敗："; tail -30 configure.log; exit 1; }

grep -E "^WX_LIBS = " configure.log || true

echo "== make =="
PATH="$WX_PREFIX/bin:$PATH" \
LD_LIBRARY_PATH="$WX_PREFIX/lib:${LD_LIBRARY_PATH:-}" \
make -j"$JOBS" > make.log 2>&1 || { echo "編譯失敗："; grep -nE "error:" make.log | head -20; tail -20 make.log; exit 1; }

# 確認真的靜態連結了 wxWidgets：執行檔不該再相依 wx 的 .so
if ldd ./madedit 2>/dev/null | grep -q "libwx_"; then
    echo "錯誤：執行檔仍然動態連結 wxWidgets，並非預期的靜態連結。" >&2
    exit 1
fi

# --- 4. 組裝產品資料夾 ---------------------------------------------------
echo "== 組裝 $PKG =="
STAGE="$BUILD_DIR/$PKG"
rm -rf "$STAGE"
mkdir -p "$STAGE"

cp madedit "$STAGE/madedit"
chmod 755 "$STAGE/madedit"
strip "$STAGE/madedit" 2>/dev/null || true

cp README.md "$STAGE/README.md"
cp gpl-3.0.txt "$STAGE/gpl-3.0.txt"
cp madedit.desktop "$STAGE/madedit.desktop"
cp madedit.xpm "$STAGE/madedit.xpm"

cp -r syntax "$STAGE/syntax"
cp -r scripts "$STAGE/scripts"
cp -r Dictionaries "$STAGE/Dictionaries"

# 語系檔：po/<lang>.gmo -> locale/<lang>/LC_MESSAGES/madedit-mod.mo
#
# 位置是執行檔旁邊的 locale/：MadEdit 會把這個目錄交給
# wxLocale::AddCatalogLookupPathPrefix()（見 src/MadEditApp.cpp 的
# ScanForLocales()/InitLocale()），wxWidgets 3.3 會在底下尋找
# <語言>/LC_MESSAGES/madedit-mod.mo。
# 這個位置在 Windows、Linux、macOS 都有效，與 Windows 版一致。
for gmo in po/*.gmo; do
    [ -f "$gmo" ] || continue
    lang=$(basename "$gmo" .gmo)
    mkdir -p "$STAGE/locale/$lang/LC_MESSAGES"
    cp "$gmo" "$STAGE/locale/$lang/LC_MESSAGES/madedit-mod.mo"
done

# --- 5. 打包 -------------------------------------------------------------
mkdir -p "$OUTPUT"
ARCHIVE="$OUTPUT/$PKG.tar.gz"
rm -f "$ARCHIVE"
tar czf "$ARCHIVE" -C "$BUILD_DIR" "$PKG"

echo
echo "產物： $ARCHIVE"
ls -lh "$ARCHIVE"

# --- 6. 上傳到 GitHub Release（選用）-------------------------------------
if [ "$UPLOAD" -eq 1 ]; then
    echo
    echo "== 上傳到 GitHub Release $VERSION =="
    command -v gh >/dev/null 2>&1 || { echo "錯誤：找不到 gh。" >&2; exit 1; }
    gh auth status >/dev/null 2>&1 || { echo "錯誤：gh 尚未登入，請先執行 gh auth login。" >&2; exit 1; }
    gh release upload "$VERSION" "$ARCHIVE" --clobber
    echo "已上傳： $ARCHIVE"
fi
