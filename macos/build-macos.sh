#!/bin/sh
# 在 macOS 上建置 MadEdit-Mod，並組出可雙擊執行��� MadEdit.app。
#
# 用法：
#   sh macos/build-macos.sh [選項]
#
# 選項：
#   --relocatable     把 wxWidgets / gettext 的動態函式庫打包進
#                     MadEdit.app/Contents/Frameworks，讓 .app 可以複製到
#                     別台機器執行（預設是連結到 Homebrew 的版本）
#   --debug           產生含除錯資訊與 assert 的版本（預設為 release）
#   --prefix=PATH     安裝前綴（預設 /opt/local/madedit）
#   --build-dir=PATH  建置目錄（預設 /opt/local/madedit-build，
#                     沒有 /opt/local 就改用 ~/local/madedit-build）
#
# 產物：
#   $BUILD_DIR/MadEdit.app   可直接拖進 Applications 的 app bundle

set -e

# Homebrew 在 Apple Silicon 上是 /opt/homebrew，在 Intel 上是 /usr/local。
# 非登入 shell 不一定會把 brew 放進 PATH，所以先補上。
for d in /opt/homebrew/bin /usr/local/bin; do
    [ -d "$d" ] && PATH="$d:$PATH"
done
export PATH

SRC_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR=""
PREFIX="/opt/local/madedit"
RELOCATABLE=no
DEBUG=no

for arg in "$@"; do
    case "$arg" in
        --relocatable)   RELOCATABLE=yes ;;
        --debug)         DEBUG=yes ;;
        --prefix=*)      PREFIX="${arg#--prefix=}" ;;
        --build-dir=*)   BUILD_DIR="${arg#--build-dir=}" ;;
        *) echo "不明的選項： $arg"; exit 1 ;;
    esac
done

# --- 1. 檢查相依套件 -----------------------------------------------------
if ! command -v wx-config >/dev/null 2>&1; then
    echo "找不到 wx-config，請先安裝："
    echo "  brew install wxwidgets boost gettext"
    exit 1
fi

BOOST_PREFIX=$(brew --prefix boost 2>/dev/null || echo "")
if [ -z "$BOOST_PREFIX" ] || [ ! -f "$BOOST_PREFIX/include/boost/config.hpp" ]; then
    echo "找不到 Boost 標頭檔，請安裝： brew install boost"
    exit 1
fi

GETTEXT_PREFIX=$(brew --prefix gettext 2>/dev/null || echo "")
if [ -z "$GETTEXT_PREFIX" ] || [ ! -f "$GETTEXT_PREFIX/include/libintl.h" ]; then
    echo "找不到 gettext，請安裝： brew install gettext"
    exit 1
fi

if [ -z "$BUILD_DIR" ]; then
    if mkdir -p /opt/local 2>/dev/null; then
        BUILD_DIR="/opt/local/madedit-build"
    else
        BUILD_DIR="$HOME/local/madedit-build"
    fi
fi

echo "== wxWidgets =="
wx-config --version
wx-config --selected-config
echo "== Boost =="
grep BOOST_LIB_VERSION "$BOOST_PREFIX/include/boost/version.hpp" | head -1

# --- 2. 產生 configure（需要的話）與設定檔 -------------------------------
# autoconf 產生的檔案必須比 configure.ac 新，否則 make 會想重新產生
# configure 並寫回 source 目錄。out-of-tree 建置時更要先把時間戳排好。
mkdir -p "$BUILD_DIR"
cd "$SRC_DIR"
touch aclocal.m4
sleep 1
touch config.h.in Makefile.in syntax/Makefile.in scripts/Makefile.in po/Makefile.in
sleep 1
touch configure

echo "== configure（$BUILD_DIR）=="
cd "$BUILD_DIR"
if [ "$DEBUG" = yes ]; then
    "$SRC_DIR/configure" \
        --prefix="$PREFIX" \
        --with-boost="$BOOST_PREFIX/include" \
        --enable-debug \
        CPPFLAGS="-I$GETTEXT_PREFIX/include" \
        LIBS="-L$GETTEXT_PREFIX/lib -lintl"
else
    "$SRC_DIR/configure" \
        --prefix="$PREFIX" \
        --with-boost="$BOOST_PREFIX/include" \
        CPPFLAGS="-I$GETTEXT_PREFIX/include" \
        LIBS="-L$GETTEXT_PREFIX/lib -lintl"
fi

echo "== make =="
# gettext 的 po/Makefile 會在 madedit-mod.pot 比 .po 新的時候用 msgmerge
# 改寫 .po。.pot 又會因為原始碼變動而重新產生，於是任何一次建置都可能
# 改動 source 目錄裡被追蹤的翻譯檔。先把時間戳排好避免這件事。
touch "$SRC_DIR/po/madedit-mod.pot" 2>/dev/null || true
sleep 1
touch "$SRC_DIR"/po/*.po 2>/dev/null || true

make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"

# --- 3. 組裝 MadEdit.app --------------------------------------------------
APP="$BUILD_DIR/MadEdit.app"
CONTENTS="$APP/Contents"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp "$BUILD_DIR/madedit" "$CONTENTS/MacOS/MadEdit"
cp -R "$SRC_DIR/syntax" "$CONTENTS/Resources/syntax"
cp -R "$SRC_DIR/scripts" "$CONTENTS/Resources/scripts"
cp -R "$SRC_DIR/Dictionaries" "$CONTENTS/Resources/Dictionaries"

# 語系檔：po/<lang>.gmo -> Resources/locale/<lang>/LC_MESSAGES/madedit-mod.mo
#
# out-of-tree 建置時 gettext 的 Makefile 會因為 VPATH 在 source 目錄找到
# 既有的 .gmo 而判定「不需要重編」，所以在這裡明確用 msgfmt 重新產生，
# 確保翻譯內容跟 .po 一致。
if command -v msgfmt >/dev/null 2>&1; then
    for po in "$SRC_DIR"/po/*.po; do
        [ -f "$po" ] || continue
        lang=$(basename "$po" .po)
        msgfmt -o "$BUILD_DIR/po/$lang.gmo" "$po" 2>/dev/null || true
    done
fi

for gmo in "$BUILD_DIR"/po/*.gmo "$SRC_DIR"/po/*.gmo; do
    [ -f "$gmo" ] || continue
    lang=$(basename "$gmo" .gmo)
    mkdir -p "$CONTENTS/Resources/locale/$lang/LC_MESSAGES"
    cp "$gmo" "$CONTENTS/Resources/locale/$lang/LC_MESSAGES/madedit-mod.mo"
done

# --- 4. Info.plist --------------------------------------------------------
VERSION=$(cat "$SRC_DIR/VERSION.txt" 2>/dev/null || echo "0.0.0")
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MadEdit</string>
    <key>CFBundleDisplayName</key>
    <string>MadEdit-Mod</string>
    <key>CFBundleExecutable</key>
    <string>MadEdit</string>
    <key>CFBundleIdentifier</key>
    <string>org.madedit.madedit-mod</string>
    <key>CFBundleIconFile</key>
    <string>MadEdit.icns</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundlePackageTypeName</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>MadEdit-Mod, GPL</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS/PkgInfo"

# --- 5. 圖示 --------------------------------------------------------------
# 用 sips 產生各種尺寸，再由 iconutil 組成 .icns
ICON_SRC="$SRC_DIR/madedit-mod.png"
if [ -f "$ICON_SRC" ]; then
    ICONSET="$BUILD_DIR/MadEdit.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size "$ICON_SRC" \
            --out "$ICONSET/icon_${size}x${size}.png" >/dev/null 2>&1 || true
    done
    cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_512x512@2x.png" 2>/dev/null || true
    if iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/MadEdit.icns" 2>/dev/null; then
        rm -rf "$ICONSET"
    else
        echo "（圖示轉換失敗，不影響執行）"
        rm -rf "$ICONSET"
    fi
fi

# --- 6. 可攜式打包（選用）------------------------------------------------
if [ "$RELOCATABLE" = yes ]; then
    echo "== 打包動態函式庫 =="
    mkdir -p "$CONTENTS/Frameworks"

    # 收集這個執行檔實際用到的非系統動態函式庫（含相依鏈）。
    # wxWidgets 的 dylib 之間是以 Homebrew 的絕對路徑互相參照的，而且參照
    # 的是帶版號的檔名（libwx_..._core-3.3.4.0.0.dylib），所以要用
    # realpath 解析後的檔名來對應，否則會同時載入兩份 wxWidgets。
    python3 - "$CONTENTS" <<'PY'
import os, subprocess, sys, glob

contents = sys.argv[1]
frameworks = os.path.join(contents, "Frameworks")
exe = os.path.join(contents, "MacOS", "MadEdit")
exe_dir = os.path.dirname(exe)

def deps(path):
    out = subprocess.run(["otool", "-L", path], capture_output=True, text=True).stdout
    result = []
    for line in out.splitlines()[1:]:
        line = line.strip()
        if not line or " (" not in line:
            continue
        p = line.split(" (")[0]
        if p.startswith("/System/") or p.startswith("/usr/lib/"):
            continue
        if ".dylib" not in p and ".framework" not in p:
            continue
        result.append(p)
    return result

def rpaths_of(path):
    out = subprocess.run(["otool", "-l", path], capture_output=True, text=True).stdout
    lines = out.splitlines()
    result = []
    for i, l in enumerate(lines):
        if "cmd LC_RPATH" in l:
            for j in range(i, min(i + 4, len(lines))):
                if "path " in lines[j]:
                    result.append(lines[j].split("path ")[1].split("(offset")[0].strip())
                    break
    return result

def expand(p, referrer):
    if p.startswith("@executable_path/"):
        return os.path.join(exe_dir, p[len("@executable_path/"):])
    if p.startswith("@loader_path/"):
        return os.path.join(os.path.dirname(os.path.abspath(referrer)),
                            p[len("@loader_path/"):])
    return p

def resolve(dep, referrer):
    # @rpath / @loader_path / @executable_path 形式的參照要先找出實際檔案
    if dep.startswith("@rpath/"):
        name = dep[len("@rpath/"):]
        for rp in rpaths_of(referrer):
            cand = os.path.join(expand(rp, referrer), name)
            if os.path.exists(cand):
                return os.path.realpath(cand)
        hits = glob.glob("/opt/homebrew/opt/*/lib/" + name)
        if hits:
            return os.path.realpath(hits[0])
        return None
    if dep.startswith("@executable_path/") or dep.startswith("@loader_path/"):
        cand = expand(dep, referrer)
        return os.path.realpath(cand) if os.path.exists(cand) else None
    return os.path.realpath(dep) if os.path.exists(dep) else None

needed = {}
def collect(path):
    for d in deps(path):
        r = resolve(d, path)
        if r is None or r in needed:
            continue
        needed[r] = d
        collect(r)

collect(exe)

for r in needed:
    name = os.path.basename(r)
    dst = os.path.join(frameworks, name)
    subprocess.run(["cp", "-L", r, dst], check=True)
    subprocess.run(["install_name_tool", "-id",
                    "@executable_path/../Frameworks/" + name, dst],
                   stderr=subprocess.DEVNULL)

targets = [exe] + [os.path.join(frameworks, n) for n in sorted(os.listdir(frameworks))]
for t in targets:
    if not os.path.isfile(t):
        continue
    for d in deps(t):
        r = resolve(d, t)
        if r is None:
            continue
        name = os.path.basename(r)
        if os.path.exists(os.path.join(frameworks, name)):
            subprocess.run(["install_name_tool", "-change", d,
                            "@executable_path/../Frameworks/" + name, t],
                           stderr=subprocess.DEVNULL)
print("   打包了 %d 個函式庫" % len(needed))
PY
fi

# --- 7. 簽章 --------------------------------------------------------------
# Apple Silicon 上未簽章的執行檔會被系統直接殺掉，ad-hoc 簽章就足以在本機執行。
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || \
    echo "（簽章失敗，仍可嘗試執行）"

echo
echo "建置完成： $APP"
echo "把整個 MadEdit.app 拖進 Applications 資料夾即可使用。"
