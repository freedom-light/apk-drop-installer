#!/bin/bash
# 一键安装「APK拖放安装」：
#   curl -fsSL https://raw.githubusercontent.com/freedom-light/apk-drop-installer/main/setup.sh | bash
# 下载本仓库和 Google 官方的 adb、aapt2（固定版本，校验 SHA-256），在本机打包后装进「应用程序」。
# 不需要 sudo，也不需要 Xcode 命令行工具。
set -euo pipefail

APP_NAME="APK拖放安装"
REPO_TARBALL=${REPO_TARBALL:-https://codeload.github.com/freedom-light/apk-drop-installer/tar.gz/refs/heads/main}
PT_URL=${PT_URL:-https://dl.google.com/android/repository/platform-tools_r36.0.2-darwin.zip}
PT_SHA256=106a5d31fad8c1c0c5a180d06f5779767d129d7d5edbe629005c11a85eec5b4b
AAPT2_URL=${AAPT2_URL:-https://dl.google.com/dl/android/maven2/com/android/tools/build/aapt2/9.5.1-16666295/aapt2-9.5.1-16666295-osx.jar}
AAPT2_SHA256=a43df4c45549e8a877a8d61b130ee255669eec8a36064f2fc8cd58206457f2a3
SRC_DIR=${SRC_DIR:-}         # 用本地源码代替下载（测试用）
INSTALL_DIR=${INSTALL_DIR:-} # 默认「应用程序」，没写权限时用个人的「应用程序」
OPEN_AFTER=${OPEN_AFTER:-1}  # 装完打开一次

die() { echo "安装失败：$*" >&2; exit 1; }

[ "$(uname)" = Darwin ] || die "只支持 macOS"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 下载并校验：指纹不符就停止，不换地址、不跳过
fetch() {
  local url=$1 sha=$2 out=$3 actual
  echo "下载 $url"
  curl -fL --retry 3 --connect-timeout 20 -s -o "$out" "$url" || die "下载失败，请检查网络：$url"
  actual=$(shasum -a 256 "$out" | cut -d' ' -f1)
  [ "$actual" = "$sha" ] || die "文件校验不通过，已停止（期望 ${sha}，实际 ${actual}）：$url"
}

if [ -z "$SRC_DIR" ]; then
  echo "下载 $REPO_TARBALL"
  mkdir "$TMP/src"
  curl -fL --retry 3 --connect-timeout 20 -s "$REPO_TARBALL" | tar -xz -C "$TMP/src" --strip-components 1 \
    || die "下载源码失败，请检查能否访问 GitHub"
  SRC_DIR="$TMP/src"
fi

fetch "$PT_URL" "$PT_SHA256" "$TMP/platform-tools.zip"
fetch "$AAPT2_URL" "$AAPT2_SHA256" "$TMP/aapt2.jar"
unzip -q "$TMP/platform-tools.zip" platform-tools/adb -d "$TMP"
unzip -q "$TMP/aapt2.jar" aapt2 -d "$TMP"
chmod +x "$TMP/platform-tools/adb" "$TMP/aapt2"

# 在临时目录里打包，不改动源码目录
cp -R "$SRC_DIR" "$TMP/build-src"
ADB="$TMP/platform-tools/adb" AAPT2="$TMP/aapt2" bash "$TMP/build-src/build.sh" >/dev/null \
  || die "打包失败"

if [ -z "$INSTALL_DIR" ]; then
  if [ -w /Applications ]; then INSTALL_DIR=/Applications; else INSTALL_DIR="$HOME/Applications"; fi
fi
mkdir -p "$INSTALL_DIR"
DEST="$INSTALL_DIR/$APP_NAME.app"
rm -rf "$DEST"
ditto "$TMP/build-src/build/$APP_NAME.app" "$DEST"
codesign --verify --strict "$DEST" || die "安装后的 App 校验失败：$DEST"

[ "$OPEN_AFTER" = 1 ] && open "$DEST"

echo "已安装：$DEST"
echo "用法：把 APK 拖到「${APP_NAME}」图标上（可以把它拖到程序坞），或双击后选择 APK。"
[ "$OPEN_AFTER" = 1 ] && echo "刚才已打开一次并弹出选择文件窗口，确认能用后点「取消」即可。"
exit 0
