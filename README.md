# APK拖放安装

Mac 上的小工具：把 APK 拖到图标上，就装进用数据线连着电脑的安卓手机。不用命令行，电脑上也不用另外装任何东西。

## 安装

### 让 Codex（或其他 AI 助手）帮你装

把下面这段话原样发给它：

```text
请帮我在这台 Mac 上安装「APK拖放安装」小工具。在终端运行下面这行命令（它会联网下载，并写入「应用程序」文件夹，请用允许联网和写文件的权限运行；不需要 sudo）：

curl -fsSL https://raw.githubusercontent.com/freedom-light/apk-drop-installer/main/setup.sh | bash

运行结束后把最后几行输出告诉我。如果看到「安装失败」，把完整报错告诉我。
```

它会：从 GitHub 下载这个仓库，从 Google 官方地址下载固定版本的 adb 和 aapt2 并校验文件指纹，在你的 Mac 上打包，装进「应用程序」，最后打开一次（弹出选文件窗口，点「取消」即可）。整个过程大约半分钟到一分钟。

AI 请求联网或写文件的权限时，同意即可。

### 自己在「终端」里装

打开「终端」，粘贴上面那行 `curl … | bash` 命令回车。

### 连不上 GitHub 时

请会打包的同事在他的电脑上运行 `./build.sh`，把生成的 `APK拖放安装.zip` 发给你，按下面「用 zip 安装」操作。

## 第一次使用前：手机设置（每台手机做一次）

1. 打开「开发者选项」：设置 → 关于手机 → 连点「版本号」7 次（华为在「设置 → 关于手机 → 版本号」）。
2. 在「开发者选项」里打开「USB 调试」。
3. 华为：同一页里关闭「监控 ADB 安装应用」，否则每次安装都要在手机上确认。
   小米：同一页里打开「USB 安装」。
4. 用数据线连上电脑，手机弹出「允许 USB 调试吗？」时点「允许」，建议勾选「始终允许使用这台计算机进行调试」。

## 用 zip 安装（备用）

用上面的一键安装就不需要这一节。zip 是从聊天工具或浏览器下载的，系统会拦一次：

1. 解压收到的 `APK拖放安装.zip`，把 `APK拖放安装.app` 拖进「应用程序」文件夹。
2. 双击打开。系统会提示「无法验证开发者」，点「完成」或「取消」。
3. 打开「系统设置 → 隐私与安全性」，拉到最下面，在「已阻止打开 APK拖放安装」旁点「仍要打开」，输入电脑密码。
4. 以后就能正常打开了。建议把它拖到程序坞，方便拖 APK 上去。

如果第 3 步找不到「仍要打开」，在「终端」里执行下面这行再双击：

```sh
xattr -dr com.apple.quarantine /Applications/APK拖放安装.app
```

## 怎么用

- 把 APK 拖到 `APK拖放安装` 图标上（程序坞里的也行）。也可以双击图标，再选 APK。
- 可以一次拖多个 APK，会依次安装。
- 只连了一台手机就直接装；连了多台会列出机型让你选，可以多选。
- 装的时候有进度窗口，装完弹窗告诉你结果和用时。

## 常见提示

| 提示 | 怎么办 |
| --- | --- |
| 没检测到手机 | 检查数据线、手机解锁、「USB 调试」已打开，插线后连接方式选「传输文件」，再点「重试」 |
| 请点「允许」 | 看手机屏幕，点「允许 USB 调试」，再点「重试」 |
| 手机上已装的版本比这个包新 / 签名不同 | 要先卸载旧版才能装。点「卸载并安装」会清空这个 App 在手机上的数据；不想清就点「取消」 |
| 手机拦下了这次安装 | 看手机上有没有确认弹窗；华为关闭「监控 ADB 安装应用」，小米打开「USB 安装」 |
| 手机存储空间不足 | 清理手机空间后再拖一次 |
| APK 文件损坏或不完整 | 重新下载 APK |
| 手机连接断开了 | 重新插好数据线再拖一次 |

装得慢时：时间主要花在数据线传输上。约 750MB 的包用 USB 2.0 的线大约要 25 秒；换成 USB 3 的线、插 Mac 的雷电口会快很多（手机也要支持 USB 3）。

电脑上如果同时开着 Android Studio 等也在用 adb 的软件，偶尔会互相抢连接，安装失败时关掉它再试。

---

## 维护说明

### 打包

```sh
./build.sh          # 生成 build/APK拖放安装.app 和 build/APK拖放安装.zip（备用分发方式）
tests/run_tests.sh  # 用假的 adb/aapt2 测装包脚本和安装脚本，不需要手机、不联网
```

一键安装 `setup.sh` 不依赖本机 SDK：它下载固定版本的 platform-tools 和 aapt2（地址和 SHA-256 写在脚本开头），校验通过才打包。升级版本时改脚本开头的地址和指纹，并确认新文件仍是 Intel+M 芯片通用版、不依赖外部库（`build.sh` 会检查）。测试用的环境变量：`SRC_DIR`（用本地源码）、`INSTALL_DIR`（装到别处）、`OPEN_AFTER=0`（装完不打开）、`PT_URL`/`AAPT2_URL`（换下载地址，指纹不能改）。

本地打包需要本机装有 Android SDK：`adb`（platform-tools）和 `aapt2`（build-tools）会被复制进 App。默认找 `PATH` 里的 adb 和 `$ANDROID_HOME`（缺省 `~/Library/Android/sdk`）下最新的 aapt2，也可以用 `ADB=… AAPT2=… ./build.sh` 指定。这两个文件和打包产物都不入库（`build/` 已忽略）。

### 结构

- `src/main.applescript`：界面（拖放、选手机、确认、结果弹窗），由 `osacompile` 编成 App。
- `src/install.sh`：装包逻辑，子命令 `devices`、`install`、`reinstall`，每次只输出一行结果，界面按 tab 拆开显示。环境变量 `ADB`、`AAPT2` 可替换成测试替身（`open --env ADB=… -a APK拖放安装.app` 也能用来模拟没手机、未授权）。
- `build.sh`：检查工具 → 编译 → 复制 → 签名 → 打 zip。
- `setup.sh`：一键安装，下载源码和工具 → 校验 → 调 `build.sh` 打包 → 装进「应用程序」。

### 踩过的坑

- **循环里调 `adb shell` 要加 `</dev/null`**：`adb shell` 会读走标准输入。`adb devices | while read …` 循环里不加的话，第一台手机之后的行全被吃掉，多台手机只显示一台。测试里的假 adb 也会读标准输入，用来防回归。
- **不能调用 lipo、otool**：没装 Xcode 命令行工具的 Mac 上它们只是空壳，一调用就弹「安装开发者工具」。`build.sh` 只用系统自带的 `file -b` 判断架构、`grep -a '@rpath/'` 判断外部库依赖。验证方法：`DEVELOPER_DIR=/nonexistent` 下跑一遍安装，调到空壳就会报错。
- **脚本里变量紧挨中文要加花括号**：macOS 自带 bash 3.2 会把 `$sha，` 里的中文标点当成变量名的一部分，`set -u` 下直接报「unbound variable」。写成 `${sha}，`。
- **自己下载、就地打包的 App 不带隔离标记**：`curl` 下载不加 quarantine，所以一键安装不用去「系统设置」放行；从聊天工具或浏览器下载的 zip 才需要。
- **Maven 上的 aapt2 jar 解压后没有执行权限**，要 `chmod +x`。
- **用 aapt2，不用 aapt**：build-tools 里的 `aapt` 依赖同目录的 `lib64/libc++.dylib`，单独拷出来跑不了；`aapt2` 只依赖系统库。`build.sh` 用 `grep -a '@rpath/'` 检查有没有外部库依赖。
- **adb、aapt2 要同时支持 Intel 和 M 芯片**：`build.sh` 用 `file -b` 检查同时含 x86_64 和 arm64，不是通用版就拒绝打包。
- **复制来的 adb 可能带下载隔离标记**（如 Homebrew 安装的），会被打进 zip。`build.sh` 签名前 `xattr -cr`，打 zip 用 `--norsrc --noextattr`。
- **签名不加 `--deep`**：只给 App 本身做本机临时签名，adb、aapt2 保留 Google 原签名。没有 Developer ID 证书就无法公证，从 zip 安装的使用者第一次要手动放行。
- **`osacompile` 生成的 Info.plist 没有 `CFBundleIdentifier`**，要用 `PlistBuddy Add`，不能用 `Set`。
- **只在需要卸载时才读包名**：`aapt2 dump packagename` 约 0.2 秒，正常安装不调用。
- `adb install` 的「降级」报错里没有包名，所以卸载前必须从 APK 本身读包名，不能靠解析报错。
