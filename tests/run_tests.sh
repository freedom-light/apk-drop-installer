#!/bin/bash
# 用假的 adb / aapt2 测 install.sh，不需要手机。用法：tests/run_tests.sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FAKE=$(mktemp -d)
trap 'rm -rf "$FAKE"' EXIT
export FAKE

# 假 adb：devices 读 $FAKE/devices；shell 读 $FAKE/props_<序列号>；install 依次读 $FAKE/install_1、install_2…；每次调用记进 $FAKE/calls
cat >"$FAKE/adb" <<'EOF'
#!/bin/bash
echo "$*" >>"$FAKE/calls"
[ "$1" = -s ] && { serial=$2; shift 2; }
case $1 in
  start-server) ;;
  devices) echo "List of devices attached"; cat "$FAKE/devices"; echo ;;
  shell) cat >/dev/null; cat "$FAKE/props_$serial" 2>/dev/null ;; # 真 adb shell 会读走标准输入
  install)
    n=$(($(cat "$FAKE/n" 2>/dev/null || echo 0) + 1)); echo $n >"$FAKE/n"
    cat "$FAKE/install_$n" ;;
  uninstall) echo Success ;;
esac
EOF
printf '#!/bin/bash\necho "aapt2 $*" >>"$FAKE/calls"\ncat "$FAKE/pkg"\n' >"$FAKE/aapt2"
chmod +x "$FAKE/adb" "$FAKE/aapt2"
export ADB="$FAKE/adb" AAPT2="$FAKE/aapt2"
RUN="$ROOT/src/install.sh"

pass=0 fail=0
check() { # 名称 实际 期望
  if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); printf '不通过：%s\n  实际：%s\n  期望：%s\n' "$1" "$2" "$3"; fi
}
reset() { rm -f "$FAKE"/devices "$FAKE"/props_* "$FAKE"/install_* "$FAKE"/n "$FAKE"/calls "$FAKE"/pkg; touch "$FAKE/devices"; }
T=$'\t'

# devices
reset
check "没有手机" "$(bash "$RUN" devices)" ""

reset
printf 'AAA\tunauthorized\n' >"$FAKE/devices"
check "未授权不查机型" "$(bash "$RUN" devices)" "AAA${T}unauthorized${T}"

reset
printf 'AAA\tdevice\r\nBBB\tdevice\n' >"$FAKE/devices"
printf 'HUAWEI Mate X5\r\n\r\nHUAWEI\r\nALT-AL10\r\n' >"$FAKE/props_AAA"
printf '\n\nrealme\nRMX3562\n' >"$FAKE/props_BBB"
check "两台：华为用营销名，其余用品牌+型号" "$(bash "$RUN" devices)" "AAA${T}device${T}HUAWEI Mate X5
BBB${T}device${T}realme RMX3562"

reset
printf 'CCC\tdevice\n' >"$FAKE/devices"
printf '\nOPPO Find N3\nOPPO\nPKB110\n' >"$FAKE/props_CCC"
check "用 ro.product.marketname" "$(bash "$RUN" devices)" "CCC${T}device${T}OPPO Find N3"

# install
install_case() { # 名称 adb输出 期望代码
  reset
  printf '%s\n' "$2" >"$FAKE/install_1"
  check "$1" "$(bash "$RUN" install AAA /x/a.apk | cut -f1-2)" "$3"
}
reset
printf 'Performing Streamed Install\nSuccess\n' >"$FAKE/install_1"
check "成功" "$(bash "$RUN" install AAA '/x/带 空格.apk' | cut -f1)" "OK"
check "install 参数" "$(grep install "$FAKE/calls")" "-s AAA install -r /x/带 空格.apk"
install_case "签名不一致" "adb: failed to install a.apk: Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE: Existing package x signatures do not match newer version; ignoring!]" "FAIL${T}NEED_UNINSTALL"
install_case "降级" "Failure [INSTALL_FAILED_VERSION_DOWNGRADE: Downgrade detected]" "FAIL${T}NEED_UNINSTALL"
install_case "空间不足" "Failure [INSTALL_FAILED_INSUFFICIENT_STORAGE]" "FAIL${T}STORAGE"
install_case "手机拦截" "Failure [INSTALL_FAILED_USER_RESTRICTED: Install canceled by user]" "FAIL${T}BLOCKED"
install_case "包损坏" "Failure [INSTALL_PARSE_FAILED_NOT_APK: Failed to parse]" "FAIL${T}BAD_APK"
install_case "系统太低" "Failure [INSTALL_FAILED_OLDER_SDK: Requires newer sdk version]" "FAIL${T}OLD_PHONE"
install_case "CPU 不支持" "Failure [INSTALL_FAILED_NO_MATCHING_ABIS]" "FAIL${T}ABI"
install_case "断开" "adb: device 'AAA' not found" "FAIL${T}DISCONNECTED"
install_case "未知错误" "Failure [INSTALL_FAILED_WEIRD]" "FAIL${T}OTHER"
rm -f "$FAKE/n"
check "未知错误带原文" "$(bash "$RUN" install AAA /x/a.apk | cut -f3)" "安装失败：Failure [INSTALL_FAILED_WEIRD]"

# reinstall
reset
echo com.example.app >"$FAKE/pkg"
printf 'Success\n' >"$FAKE/install_1"
check "卸载后重装成功" "$(bash "$RUN" reinstall AAA /x/a.apk | cut -f1)" "OK"
check "先卸载同包名再装" "$(grep -v aapt2 "$FAKE/calls")" "-s AAA uninstall com.example.app
-s AAA install -r /x/a.apk"

reset
: >"$FAKE/pkg"
check "读不出包名不卸载" "$(bash "$RUN" reinstall AAA /x/a.apk | cut -f1-2)" "FAIL${T}BAD_APK"
check "读不出包名时没调 adb" "$(grep -c -- '-s AAA' "$FAKE/calls")" "0"

# setup.sh：下载的文件指纹不符时停止，不安装（不联网：源码用本地，adb 包用假文件）
INST=$(mktemp -d)
echo fake >"$FAKE/fake.zip"
out=$(SRC_DIR="$ROOT" PT_URL="file://$FAKE/fake.zip" INSTALL_DIR="$INST" OPEN_AFTER=0 bash "$ROOT/setup.sh" 2>&1)
code=$?
check "指纹不符时退出码非 0" "$([ $code -ne 0 ] && echo yes)" "yes"
check "指纹不符时提示校验不通过" "$(printf '%s' "$out" | grep -c '校验不通过')" "1"
check "指纹不符时没有安装" "$(ls "$INST" | wc -l | tr -d ' ')" "0"
rm -rf "$INST"

printf '通过 %d，不通过 %d\n' $pass $fail
[ $fail -eq 0 ]
