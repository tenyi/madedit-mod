#!/bin/sh
# 在 MSYS2 (ucrt64) 環境下建置 MadEdit-Mod。
#
# 用法：
#   1) 先在 MSYS2 的「MSYS2 UCRT64」終端機開一個新的視窗
#   2) cd <此專案目錄>
#   3) sh msw/build-msys2.sh
#
# 產物：
#   ./madedit.exe        可執行檔
#   ./dist/              可直接攜帶的產品資料夾（執行檔 + DLL + 資料檔）
#
# 這個腳本會做四件事：
#   1. 檢查 wxWidgets / Boost 是否齊備
#   2. 必要的話用 autoconf/automake 重新產生 configure 與 Makefile.in
#   3. 執行 configure 與 make
#   4. 把執行檔與執行期需要的檔案組裝到 dist/
#
# 選項：
#   --enable-debug       產生含除錯資訊與 assert 的版本（預設為 release）

set -e

cd "$(dirname "$0")/.." || exit 1

# --- 1. 檢查相依套件 -----------------------------------------------------
if ! command -v wx-config >/dev/null 2>&1; then
    echo "找不到 wx-config，請先安裝："
    echo "  pacman -S mingw-w64-ucrt-x86_64-wxwidgets3.3-msw mingw-w64-ucrt-x86_64-boost"
    exit 1
fi

echo "== wxWidgets =="
wx-config --version
wx-config --selected-config

echo "== Boost =="
if [ -f /ucrt64/include/boost/version.hpp ]; then
    grep BOOST_LIB_VERSION /ucrt64/include/boost/version.hpp | head -1
else
    echo "找不到 /ucrt64/include/boost/version.hpp，請安裝 mingw-w64-ucrt-x86_64-boost"
    exit 1
fi

# --- 2. 需要時重新產生建置腳本 -------------------------------------------
# 從 git 取出時 configure.ac / Makefile.am 的時間戳會比產生的檔案新，
# make 會嘗試自動重新產生；這一步讓它用正確的 m4 巨集目錄完成。
if command -v aclocal-1.16 >/dev/null 2>&1 && command -v automake-1.16 >/dev/null 2>&1; then
    export WANT_AUTOCONF=2.69
    export WANT_AUTOMAKE=1.16
    echo "== 重新產生 configure / Makefile.in =="
    aclocal-1.16 -I m4
    autoheader-2.69
    automake-1.16 --foreign --add-missing --copy
    autoconf-2.69
else
    echo "== 略過重新產生（找不到 autoconf/automake）=="
    # 沒有 autotools 時，把產生的檔案時間戳更新，避免 make 嘗試重新產生
    touch aclocal.m4
    sleep 1
    touch config.h.in Makefile.in syntax/Makefile.in scripts/Makefile.in
    sleep 1
    touch configure
    sleep 1
fi

# --- 3. configure 與 make -------------------------------------------------
echo "== configure =="
./configure --prefix=/ucrt64 "$@"

echo "== make =="
make -j"$(nproc 2>/dev/null || echo 4)"

# --- 4. 組裝產品資料夾 ---------------------------------------------------
# Windows 版的所有資料（syntax/、scripts/、Dictionaries/、locale/）都是
# 以執行檔所在目錄為基準尋找，所以把執行檔與這些資料放在一起，
# 整個資料夾就可以隨意搬移。
echo "== 組裝 dist/ =="
rm -rf dist
mkdir -p dist/locale

cp madedit.exe dist/

# wxWidgets 與 MinGW 執行期 DLL：直接用 ldd 的結果最準確
# ldd 的輸出格式是 "  <dll> => <path> (0x...)"，所以不能用 $ 結尾錨點。
# 只取 /ucrt64/ 底下的（Windows 系統 DLL 已經在系統裡，不該隨程式散布）。
for dll in $(ldd madedit.exe | sed -n 's/.*=> \(\/[^ ]*\.dll\).*/\1/p' | grep -i '^/ucrt64/'); do
    cp "$dll" dist/ 2>/dev/null || true
done
# 上面抓不到的部分（例如 libintl、libiconv）用已知清單補上
for dll in libintl-8.dll libiconv-2.dll libwinpthread-1.dll; do
    [ -f "/ucrt64/bin/$dll" ] && cp "/ucrt64/bin/$dll" dist/
done

cp -r syntax dist/syntax
cp -r scripts dist/scripts
cp -r Dictionaries dist/Dictionaries

# 語系檔：po/<lang>.gmo -> dist/locale/<lang>/LC_MESSAGES/madedit-mod.mo
for gmo in po/*.gmo; do
    [ -f "$gmo" ] || continue
    lang=$(basename "$gmo" .gmo)
    mkdir -p "dist/locale/$lang/LC_MESSAGES"
    cp "$gmo" "dist/locale/$lang/LC_MESSAGES/madedit-mod.mo"
done

echo
echo "建置完成： $(pwd)/madedit.exe"
echo "產品資料夾： $(pwd)/dist"
echo "整個 dist/ 可以直接複製到其他 Windows 機器執行。"
