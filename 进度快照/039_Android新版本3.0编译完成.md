# 039 Android新版本3.0编译完成

## 时间
- 2026-06-10

## 本次目标
- 基于当前 Android 精简后的代码，编译一个新的 Android 发布版本。
- 让 APK 安装包版本号与应用内显示版本保持一致。

## 本次已完成

### 1. 已修正关于页硬编码版本号
- 修改：
  - `lib/pages/about_page.dart`
- 处理内容：
  - 移除硬编码的 `1.2.17`
  - 改为直接读取 `AppVersion.displayVersion`
- 结果：
  - 本次编出的 Android 包在应用内显示版本与构建版本一致

### 2. 已成功编译 Android `3.0` release APK
- 构建参数：
  - `VNT_USE_PREBUILT_RUST_ANDROID=1`
  - `--build-name=3.0`
  - `--build-number=300`
  - `--dart-define=APP_BUILD_VERSION=3.0`
  - `--dart-define=APP_DISPLAY_VERSION=v3.0`
  - `--dart-define=APP_PRODUCT_NAME=VNTC APP2.0`
  - `--dart-define=APP_WINDOW_TITLE=VNTC APP2.0 v3.0`
- 结果：
  - 成功产出 Android release APK
  - `output-metadata.json` 已确认：
    - `versionName = 3.0`
    - `versionCode = 300`

### 3. 已生成带版本号的分发副本
- 原始产物：
  - `build/app/outputs/flutter-apk/app-release.apk`
- 分发副本：
  - `dist/android/VNT_App_3.0_Android_Release.apk`
- 校验文件：
  - `dist/android/VNT_App_3.0_Android_Release.sha256`

### 4. 已将下一次待编译版本推进到 `3.1`
- 修改：
  - `scripts/build_version.txt`
- 结果：
  - 当前已成功产出 `3.0`
  - 下一轮开始时的待编译版本号已推进为 `3.1`

## 本次验证

### 代码检查
- `dart analyze lib/pages/about_page.dart lib/app_version.dart`
  - 通过
  - 仍有仓库原有 `withOpacity` info，未在本轮顺手清理

### Android 构建验证
- `VNT_USE_PREBUILT_RUST_ANDROID=1 flutter build apk --release --build-name=3.0 --build-number=300 ...`
  - 通过

### 版本结果验证
- `build/app/outputs/apk/release/output-metadata.json`
  - `versionName: 3.0`
  - `versionCode: 300`

## 当前修改位置
- `lib/pages/about_page.dart:2`
  - 已接入 `AppVersion`
- `lib/pages/about_page.dart:183`
  - 关于页版本展示改为 `AppVersion.displayVersion`
- `scripts/build_version.txt:1`
  - 已从 `3.0` 推进到 `3.1`

## 产物
- 发布 APK：
  - `build/app/outputs/flutter-apk/app-release.apk`
- 版本化分发包：
  - `dist/android/VNT_App_3.0_Android_Release.apk`
- SHA256：
  - `0cb4f8211f2c676339d7097f3f6adc322d391d73274301d3e2386c94054d0137`

## 待办清单
- 如需继续发下一版，起始版本号已是 `3.1`
- 如需更彻底收口 Android 侧无用源码，可继续删除已失效的聊天室/远程协助实现文件

## 下一步要做什么
- 如果你下一步要“继续瘦身代码”或“再编一个 AAB / 多 ABI 拆分包”，可以直接从这份快照继续。
