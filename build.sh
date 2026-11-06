#!/bin/bash
# 打包：./build.sh → build/APK拖放安装.app 和 build/APK拖放安装.zip（发 zip 给使用者）
# adb、aapt2 从本机 Android SDK 复制进 App；可用环境变量 ADB=… AAPT2=… 指定。
set -euo pipefail
cd "$(dirname "$0")"

NAME="APK拖放安装"
APP="build/$NAME.app"
SDK=${ANDROID_HOME:-$HOME/Library/Android/sdk}
ADB=${ADB:-$(command -v adb || echo "$SDK/platform-tools/adb")}
AAPT2=${AAPT2:-$(ls "$SDK"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1)}

die() { echo "打包失败：$*" >&2; exit 1; }

# 两个工具都要同时支持 Intel 和 M 芯片，且只依赖系统库，才能单独放进 App。
# 只用系统自带命令检查：lipo、otool 在没装 Xcode 命令行工具的 Mac 上会弹安装提示。
check_tool() {
  local name=$1 path=$2 kind
  [ -x "$path" ] || die "找不到 ${name}（${path}），请安装 Android SDK 或用环境变量 $name=… 指定"
  kind=$(file -b "$path")
  [[ $kind == *x86_64* && $kind == *arm64* ]] || die "$name 不是 Intel+M 芯片通用版（${kind}）：$path"
  if grep -a -q '@rpath/' "$path"; then die "$name 依赖外部库，不能单独分发：$path"; fi
}
check_tool ADB "$ADB"
check_tool AAPT2 "$AAPT2"

rm -rf "$APP" "build/$NAME.zip"
mkdir -p build
osacompile -o "$APP" src/main.applescript

RES="$APP/Contents/Resources"
cp src/install.sh "$RES/install.sh"
cp -L "$ADB" "$RES/adb"
cp -L "$AAPT2" "$RES/aapt2"
chmod +x "$RES/install.sh" "$RES/adb" "$RES/aapt2"

/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string local.apk-drop-installer" "$APP/Contents/Info.plist"

# 复制来的 adb 可能带下载隔离标记，签名前清掉
xattr -cr "$APP"

# 本机临时签名，不带开发者证书信息；不加 --deep，adb、aapt2 保留 Google 原签名
codesign --force -s - "$APP"
codesign --verify --strict "$APP"

ditto -c -k --norsrc --noextattr --keepParent "$APP" "build/$NAME.zip"

echo "adb:   $("$ADB" version | sed -n 2p)"
echo "aapt2: $("$AAPT2" version 2>&1 | head -1)"
echo "已生成：$APP"
echo "发给使用者：build/$NAME.zip（$(du -h "build/$NAME.zip" | cut -f1)）"
