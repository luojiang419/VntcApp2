# 034 LinuxSDK接管与Android双APK编译完成

## 时间
- 2026-06-06

## 本次目标
- 在当前 WSL 终端内把 Android 构建链真正跑通。
- 解决此前 `flutter build apk` 因 Windows 版 SDK / Build Tools 在 Linux 终端下不可用而失败的问题。
- 在不重编 Rust Android so 的前提下，使用仓库内现有预编译库完成 APK 构建。

## 本次已完成

### 1. 已为当前终端安装并接管 Linux 版 Android SDK
- 安装位置：
  - `/home/luo/android-sdk`
- 已安装组件：
  - `cmdline-tools;latest`
  - `platform-tools`
  - `platforms;android-36`
  - `build-tools;36.0.0`
- 构建过程中 Gradle 还自动补装了：
  - `ndk;28.2.13676358`
  - `build-tools;35.0.0`
  - `platforms;android-31`
  - `platforms;android-32`
  - `platforms;android-33`
  - `platforms;android-34`
  - `platforms;android-35`
  - `cmake;3.22.1`
- 结果：
  - 当前 WSL 终端不再依赖 `/mnt/c/...` 的 Windows 版 Android SDK
  - Flutter Android toolchain 已能在 Linux 环境下正常工作

### 2. 已为 CargoKit 增加“显式跳过 Android Rust 重编”开关
- `rust_builder/cargokit/gradle/plugin.gradle`
  - 新增：
    - Gradle 属性 `vnt.usePrebuiltRustAndroid`
    - 环境变量 `VNT_USE_PREBUILT_RUST_ANDROID`
  - 当其中任一为真时：
    - CargoKit 不再为 Android 变体创建 Rust 重编任务
    - 直接使用仓库中已有的预编译 `jniLibs`
- 结果：
  - 本轮 Android 构建成功绕过了 Rust Android 交叉编译链
  - 适用于“本轮只修改 Dart / Java / 页面 / Android 宿主逻辑，未修改 Rust 核心”的场景

### 3. 已修复 APK 编译期间暴露的 Java 编译错误
- `android/app/src/main/java/top/wherewego/vnt_app/FlutterMethodChannel.java`
  - 补充 `MyVpnService` import
- 结果：
  - `protectVpnSocketFd` 新增通道已可通过 Java 编译

### 4. Android Debug / Release APK 均已成功构建
- Debug 产物：
  - `build/app/outputs/flutter-apk/app-debug.apk`
- Release 产物：
  - `build/app/outputs/flutter-apk/app-release.apk`
- 当前文件大小：
  - `app-debug.apk` 约 `267MB`
  - `app-release.apk` 约 `131MB`

## 本次验证

### Android SDK 验证
- `flutter config --android-sdk /home/luo/android-sdk`
  - 通过
- `flutter doctor --android-licenses`
  - 通过
  - `All SDK package licenses accepted.`

### APK 构建验证
- `VNT_USE_PREBUILT_RUST_ANDROID=1 flutter build apk --debug`
  - 通过
- `VNT_USE_PREBUILT_RUST_ANDROID=1 flutter build apk --release`
  - 通过

## 当前修改位置
- CargoKit Android 跳过构建开关：
  - `rust_builder/cargokit/gradle/plugin.gradle`
- Android VPN 方法通道编译修复：
  - `android/app/src/main/java/top/wherewego/vnt_app/FlutterMethodChannel.java`
- 当前终端 Android SDK 路径已切换到：
  - `android/local.properties`
  - `sdk.dir=/home/luo/android-sdk`

## 本轮构建结论
- Android APK 现在已经可以在当前 WSL 终端内编译成功。
- 这次成功构建依赖“Linux 版 SDK + CargoKit 显式跳过 Android Rust 重编 + 仓库内现有预编译 `librust_lib_vnt_app.so`”。
- 由于本轮未修改 Rust 业务核心，这种做法对当前修复任务是成立的。

## 当前剩余边界
1. 现在的 APK 构建成功，不代表 Android Rust 交叉编译链已经完全恢复。
2. 若后续修改了 `rust/` 目录代码，仍应继续补齐“真实 Android Rust 重编链”，而不是长期依赖预编译 so。
3. Android 远控受控端真实能力仍未接完，本轮只是完成了 APK 编译、状态收口和聊天室/VPN 宿主链路修复。

## 备份
- 本轮修改前备份：
  - `backup/034_APK编译环境与预编译Rust库接管前备份_20260606_075526`

## 下次建议
1. 如果下一轮继续做 Android 真机联调，直接使用：
   - `build/app/outputs/flutter-apk/app-debug.apk`
2. 如果下一轮要继续发包或测试正式包，直接使用：
   - `build/app/outputs/flutter-apk/app-release.apk`
3. 如果下一轮要动 `rust/` 代码，优先补 Android Rust 真正可重编链，再决定是否保留当前“预编译 so 接管”开关。
