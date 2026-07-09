# 030 Android远控骨架接入与APK编译完成

## 时间
- 2026-06-05

## 本轮目标
- 在当前 `VNT App` 主仓库内同步接入 Android 版远程协助能力。
- 保持单一 APK，不新开独立 Android 远控壳。
- 优先完成共享远控架构、Android 受控端权限链路、移动端页面改造、测试与 APK 编译。

## 已完成

### 1. 远程协助架构改为共享管理层 + 平台适配器
- 新增 `RemoteAssistPlatformAdapter`
- 新增：
  - `RemoteAssistWindowsAdapter`
  - `RemoteAssistAndroidAdapter`
  - `RemoteAssistUnsupportedAdapter`
- `RemoteAssistManager` 已改为通过适配器统一调度 Windows / Android 逻辑。

### 2. 远控共享模型已扩展 Android 平台字段
- `RemoteAssistHealthStatus` 新增：
  - `platform`
  - `supportedRoles`
  - `controllerAvailable`
  - `controlledServiceRunning`
  - `notificationPermissionGranted`
  - `screenCapturePermissionGranted`
  - `accessibilityPermissionGranted`
  - `overlayPermissionGranted`
  - `batteryOptimizationIgnored`
- `RemoteAssistPresenceAnnouncement` / `RemoteAssistPresenceContext` / `RemoteAssistPeer` 已同步增加平台与角色信息。
- Presence 广播与合并逻辑已支持 Android / Windows 平台识别。

### 3. Android 原生桥接与受控端最小链路已接入
- 新增 MethodChannel：
  - `top.wherewego.vnt/remote_assist_android`
- 已实现桥接方法：
  - `getStatus`
  - `requestPermission`
  - `openSystemSettings`
  - `startControlledService`
  - `stopControlledService`
  - `connectByVirtualIp`
  - `setAccessPassword`
  - `refreshState`
- 已新增 Android 原生类：
  - `RemoteAssistAndroidBridge.java`
  - `RemoteAssistControlledService.java`
  - `RemoteAssistInputService.java`
  - `RemoteAssistScreenCaptureActivity.java`
  - `RemoteAssistStateHolder.java`
- `AndroidManifest.xml` 已补充远控所需权限、服务、无障碍配置与录屏授权 Activity。

### 4. Android 移动端页面已改为手机优先布局
- `main_navigation_shell.dart` 已沿用底部 dock 导航。
- `remote_assist_page.dart` 已按 Android 改为三段式：
  - `控制别人`
  - `让别人控制我`
  - `权限与系统`
- `link_status_page.dart` 的远控摘要已区分：
  - Windows 远控状态语义
  - Android 远控状态语义
- 在线设备列表已显示平台与能力摘要，便于区分对端是 Windows 还是 Android。

### 5. 测试基线与验证已完成
- 已修复聊天室 TCP 测试固定端口占用问题：
  - `ChatTransportService.start()` 支持测试端口
  - `sendPacket()` 支持传入测试端口
- `flutter test` 已全绿。
- 远控相关测试已补齐模型升级后的断言。

### 6. Android APK 已成功产出
- Debug APK：
  - `D:\Myproject\vnt2.0\VntcApp1.0\build\app\outputs\flutter-apk\app-debug.apk`
- Release APK：
  - `D:\Myproject\vnt2.0\VntcApp1.0\build\app\outputs\flutter-apk\app-release.apk`

## 本轮实际验证结果
- `flutter test`：通过
- `flutter analyze lib test`：已确认无 error 级问题
- `flutter build apk --debug`：产出 APK
- `flutter build apk --release`：产出 APK

## 当前真实边界

### 1. Android 受控端已接入，Android 控制端尚未真正并壳完成
- 当前 APK 内：
  - Android 受控服务、录屏授权、无障碍、悬浮窗、电池优化状态采集已接入
  - Windows 控制 Android 的受控端准备链路已具备基础条件
- 但当前仍保持真实状态：
  - `controllerAvailable = false`
  - `connectByVirtualIp` 当前会返回未集成提示
- 原因：
  - `vntcrustdesk-src` 的 Android 控制端图像会话是完整独立 RustDesk 移动壳，不是几段原生代码可直接搬入。
  - 本轮只完成了“最小可运行受控端链路 + 共享架构 + 页面改造”，尚未把 Android 控制端的完整图像会话、渲染与交互栈并入当前 APK。

### 2. 真机验收尚未完成
- 当前机器 `flutter devices` 仅检测到：
  - Windows
  - Chrome
  - Edge
- 当前没有检测到 Android 真机或模拟器。
- 当前 `adb` 也不在 PATH 中。
- 所以本轮不能宣称已经完成以下真机端到端验收：
  - Android 控制 Windows
  - Windows 控制 Android
  - Android 权限拒绝/重试回归

## 下轮建议直接接着做
1. 先接入一台 Android 真机，并让 `flutter devices` / `adb devices` 能识别。
2. 用当前 APK 真机验证 Android 受控端权限链路：
   - 通知
   - 录屏
   - 无障碍
   - 悬浮窗
   - 电池优化白名单
   - 前台服务启停
3. 若要真正完成 `Android 控制 Windows`，需要继续把 `vntcrustdesk-src` 的 Android 控制端图像会话并入当前 APK，而不是只保留受控端桥接。

## 备份
- 本轮开始前已创建备份：
  - `backup\030_Android双向远控与全量移动适配前备份_20260605_084815`
