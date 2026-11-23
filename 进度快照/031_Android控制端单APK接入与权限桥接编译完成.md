# 031 Android控制端单APK接入与权限桥接编译完成

## 时间
- 2026-06-05

## 本轮目标
- 在当前 `VNT App` 安卓版内补齐“控制别人”的远程协助能力。
- 保持“同一个 APK 完成虚拟组网、聊天室、远程协助”。
- 不再依赖额外安装第二个 Android 远控 App。

## 本轮完成

### 1. 单 APK 内置控制端已接入当前主工程
- 新增 `lib/app_navigation.dart`，为主工程提供全局导航入口。
- 新增 `lib/remote_assist/controller_mobile/embedded_remote_assist_launcher.dart`。
- Android 端发起控制时，现已直接在当前 APK 内打开嵌入式 `RustDesk RemotePage`。
- 连接目标统一为 `virtualIp:49999`，支持密码透传。

### 2. Android 远程协助页面与状态已收口
- `remote_assist_page.dart` 已改为单 APK 文案，不再提示“请先使用 Windows 端发起控制”。
- `link_status_page.dart` 已改为显示“控制端可用 / 控制端不可用”。
- `RemoteAssistAndroidAdapter.launchController()` 已从“未集成”改为打开内置控制会话。
- `RemoteAssistAndroidBridge.connectByVirtualIp()` 已改为内置控制端可用时返回成功。

### 3. 宿主桥接已补齐基础控制能力
- `MainActivity.java` 已新增 `mChannel` 宿主桥接，支持：
  - `enable_soft_keyboard`
  - `get_value(KEY_IS_SUPPORT_VOICE_CALL)`
  - `get_start_on_boot_opt`
  - `set_start_on_boot_opt`
  - `sync_app_dir`
  - `start_action`
- 本轮进一步补上 Android 权限桥接：
  - `check_permission`
  - `request_permission`
  - 已支持 `RECORD_AUDIO`
  - 已支持 `POST_NOTIFICATIONS`
  - 已支持 `SYSTEM_ALERT_WINDOW`
  - 已支持 `MANAGE_EXTERNAL_STORAGE`
- 特殊权限返回后会通过 `on_android_permission_result` 回传 Flutter 侧。

### 4. 控制端资源与字体已修正
- 已将 `flutter_hbb` 控制端所需资源导入当前工程。
- 修正了 `GestureIcons` 相关字体打包与 `IconData` 的 `fontPackage` 问题。
- 解决了 release 构建中手势图标字体无法被图标树摇识别的问题。

### 5. 第三方本地包兼容已打通
- 已将控制端依赖改为本地 `packages/` 形式接入。
- 已处理旧插件的 `namespace`、Java/Kotlin 版本与兼容性问题。
- `analysis_options.yaml` 已排除本地 vendor 目录的无关分析噪音。

## 本轮验证
- `flutter analyze --no-preamble --no-fatal-infos --no-fatal-warnings`
  - 通过
  - 仍有主工程历史 `info/warning`，但无新的 analyze error
- `flutter test`
  - 通过
  - 31 tests passed
- `flutter build apk --debug`
  - 通过
- `flutter build apk --release`
  - 通过

## 产物
- Debug APK:
  - `build/app/outputs/flutter-apk/app-debug.apk`
- Release APK:
  - `build/app/outputs/flutter-apk/app-release.apk`

## 当前已知限制
- 目前内置控制端 JNI 仅内置了 `arm64-v8a` 的 `librustdesk.so`。
  - 因此真机为 `arm64` 时可直接使用控制端。
  - 非 `arm64` 设备/模拟器上，`controllerAvailable` 会按设计显示不可用。
- `try_sync_clipboard` 目前仍是宿主占位实现。
  - 远控会话链路、输入、键盘、页面路由已可用。
  - 若要补成与原版 `vntcrustdesk` 一致的 Android 剪贴板同步，还需要继续移植其原生 `FFI + protobuf + RdClipboardManager` 链路。

## 建议下一步
1. 用 `arm64` 安卓真机安装 `app-release.apk`。
2. 联调 `Android -> Windows`：
   - 虚拟 IP 直连
   - 密码直连
   - 无密码手动接受
3. 回归验证：
   - Android 受控权限链路
   - 聊天室消息
   - VNT 组网状态
4. 若会话主链路正常，再决定是否继续补 Android 剪贴板同步与更多 RustDesk 原生宿主能力。
