#!/bin/bash
# 装包逻辑，由 App 的界面脚本调用；每个子命令只往标准输出写结果，永远以 0 退出。
#   devices                 每台手机一行：序列号<TAB>状态<TAB>机型名
#   install   <序列号> <apk> 一行：OK<TAB>秒数 或 FAIL<TAB>代码<TAB>中文提示
#   reinstall <序列号> <apk> 先卸载手机上的同包名 App 再装，输出同 install
# 代码 NEED_UNINSTALL 表示签名不一致或版本比手机上低，要卸载旧版才能装。

HERE=$(cd "$(dirname "$0")" && pwd)
ADB=${ADB:-$HERE/adb}
AAPT2=${AAPT2:-$HERE/aapt2}

# 把 adb install 的失败输出翻成「代码<TAB>中文提示」
explain() {
  local out=$1
  case $out in
    *INSTALL_FAILED_UPDATE_INCOMPATIBLE*)
      printf 'NEED_UNINSTALL\t手机上已装的版本和这个包签名不同，要先卸载旧版才能装。' ;;
    *INSTALL_FAILED_VERSION_DOWNGRADE*)
      printf 'NEED_UNINSTALL\t手机上已装的版本比这个包新，要先卸载旧版才能装。' ;;
    *INSUFFICIENT_STORAGE*)
      printf 'STORAGE\t手机存储空间不足，清理一些空间后再试。' ;;
    *INSTALL_FAILED_USER_RESTRICTED*|*INSTALL_FAILED_ABORTED*|*"canceled by user"*)
      printf 'BLOCKED\t手机拦下了这次安装。先看手机上有没有确认弹窗；华为：开发人员选项里关闭「监控 ADB 安装应用」；小米：开发者选项里打开「USB 安装」。' ;;
    *INSTALL_PARSE_FAILED*|*INSTALL_FAILED_INVALID_APK*)
      printf 'BAD_APK\tAPK 文件损坏或不完整，请重新下载。' ;;
    *INSTALL_FAILED_OLDER_SDK*)
      printf 'OLD_PHONE\t手机的安卓版本太低，装不了这个包。' ;;
    *INSTALL_FAILED_NO_MATCHING_ABIS*)
      printf 'ABI\t这个包不支持这台手机的处理器。' ;;
    *device*"not found"*|*"device offline"*|*"no devices"*|*"device unauthorized"*)
      printf 'DISCONNECTED\t手机连接断开了，重新插好数据线后再试。' ;;
    *)
      local last
      last=$(printf '%s\n' "$out" | grep -E 'Failure|failed|error' | tail -1)
      [ -n "$last" ] || last=$(printf '%s\n' "$out" | tail -1)
      printf 'OTHER\t安装失败：%s' "$(printf '%s' "$last" | tr '\t' ' ')" ;;
  esac
}

device_name() {
  local props name
  props=$("$ADB" -s "$1" shell 'getprop ro.config.marketing_name; getprop ro.product.marketname; getprop ro.product.brand; getprop ro.product.model' </dev/null 2>/dev/null | tr -d '\r')
  name=$(printf '%s\n' "$props" | sed -n 1p)
  [ -n "$name" ] || name=$(printf '%s\n' "$props" | sed -n 2p)
  [ -n "$name" ] || name=$(printf '%s %s' "$(printf '%s\n' "$props" | sed -n 3p)" "$(printf '%s\n' "$props" | sed -n 4p)" | sed 's/^ *//; s/ *$//')
  [ -n "$name" ] || name="未知机型"
  printf '%s' "$name"
}

cmd_devices() {
  "$ADB" start-server >/dev/null 2>&1
  "$ADB" devices 2>/dev/null | tr -d '\r' | while IFS=$'\t' read -r serial state; do
    [ -n "$serial" ] && [ -n "$state" ] || continue
    name=""
    [ "$state" = device ] && name=$(device_name "$serial")
    printf '%s\t%s\t%s\n' "$serial" "$state" "$name"
  done
}

cmd_install() {
  local serial=$1 apk=$2 start out
  start=$(date +%s)
  out=$("$ADB" -s "$serial" install -r "$apk" 2>&1)
  if printf '%s\n' "$out" | grep -q '^Success'; then
    printf 'OK\t%s\n' $(($(date +%s) - start))
  else
    printf 'FAIL\t%s\n' "$(explain "$out")"
  fi
}

cmd_reinstall() {
  local serial=$1 apk=$2 pkg
  pkg=$("$AAPT2" dump packagename "$apk" 2>/dev/null | head -1 | tr -d '\r')
  if [ -z "$pkg" ]; then
    printf 'FAIL\tBAD_APK\t读不出这个 APK 的包名，文件可能损坏，请重新下载。\n'
    return
  fi
  "$ADB" -s "$serial" uninstall "$pkg" >/dev/null 2>&1
  cmd_install "$serial" "$apk"
}

case $1 in
  devices) cmd_devices ;;
  install) cmd_install "$2" "$3" ;;
  reinstall) cmd_reinstall "$2" "$3" ;;
  *) printf 'FAIL\tOTHER\t未知命令：%s\n' "$1" ;;
esac
exit 0
