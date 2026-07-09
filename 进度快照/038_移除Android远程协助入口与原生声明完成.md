# 038 移除Android远程协助入口与原生声明完成

## 时间
- 2026-06-10

## 本次目标
- 移除 Android 版远程协助功能。
- 保持 Windows 版远程协助不受影响。

## 本次已完成

### 1. Android 主导航已移除远程协助入口
- 修改：
  - `lib/pages/main_navigation_shell.dart`
- 处理内容：
  - 新增 `_showRemoteAssistPage`
  - Android 下不再显示“远程协助”导航项
  - 配置页、设置页索引改为根据当前可见页面动态计算
  - 页面栈中 Android 不再挂载 `RemoteAssistPage`
- 结果：
  - Android 主界面现在只保留组网相关页面，不再提供远程协助入口

### 2. Android 不再启动远程协助管理器，也不再显示链接状态页远程协助面板
- 修改：
  - `lib/main.dart`
  - `lib/pages/link_status_page.dart`
  - `lib/remote_assist/remote_assist_manager.dart`
- 处理内容：
  - 应用启动时，Android 不再执行 `RemoteAssistManager.instance.start()`
  - 链接状态页在 Android 下不再初始化远程协助状态，也不再渲染“本机状态”远程协助卡片
  - `RemoteAssistManager` 平台适配器创建逻辑已恢复为仅 Windows 走真实适配器，其他平台统一走 unsupported
- 结果：
  - Android 端不再进行远程协助 Presence、状态刷新与页面展示
  - Windows 端远程协助逻辑保持原状

### 3. AndroidManifest 已清理远程协助原生权限与组件声明
- 修改：
  - `android/app/src/main/AndroidManifest.xml`
  - `android/app/src/main/java/top/wherewego/vnt_app/MainActivity.java`
- 处理内容：
  - 移除远程协助相关权限：
    - `FOREGROUND_SERVICE_MEDIA_PROJECTION`
    - `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
    - `RECORD_AUDIO`
    - `SYSTEM_ALERT_WINDOW`
  - 移除远程协助相关组件声明：
    - `RemoteAssistControlledService`
    - `RemoteAssistInputService`
    - `RemoteAssistScreenCaptureActivity`
  - `MainActivity` 不再初始化 `RemoteAssistAndroidBridge`
- 结果：
  - Android 安装包不再注册远程协助受控服务、无障碍服务和录屏授权 Activity
  - Android 端远程协助原生入口已从清单层关闭

## 本次验证

### 代码检查
- `dart analyze lib/main.dart lib/pages/main_navigation_shell.dart lib/pages/link_status_page.dart lib/remote_assist/remote_assist_manager.dart`
  - 通过
  - 仅存在仓库原有 info 级提示，未因本轮新增 error

### Android 构建验证
- `VNT_USE_PREBUILT_RUST_ANDROID=1 flutter build apk --debug`
  - 通过
  - 产物：
    - `build/app/outputs/flutter-apk/app-debug.apk`

## 当前修改位置
- `lib/main.dart:419`
  - Android 不再启动远程协助管理器
- `lib/pages/main_navigation_shell.dart:43`
  - Android 下隐藏远程协助导航项
- `lib/pages/main_navigation_shell.dart:870`
  - 页面跳转索引改为跟随实际页面结构
- `lib/pages/link_status_page.dart:55`
  - Android 下不再初始化远程协助状态
- `lib/pages/link_status_page.dart:135`
  - Android 下不再显示远程协助状态面板
- `lib/remote_assist/remote_assist_manager.dart:44`
  - 平台适配器仅保留 Windows 真正接线
- `android/app/src/main/AndroidManifest.xml:7`
  - 已清理远程协助权限与服务/Activity 声明
- `android/app/src/main/java/top/wherewego/vnt_app/MainActivity.java:258`
  - 不再初始化 Android 远程协助桥接

## 待办清单
- 当前这次“移除 Android 聊天室与远程协助功能”的目标已完成
- 如需进一步瘦身，可继续删除仓库中未再使用的 Android 远程协助 Java / Dart 实现文件

## 下一步要做什么
- 如果你希望继续做“彻底清理无用代码与资源”，下一轮可以把 Android 侧已失效的远程协助实现文件、无障碍配置和相关说明文档继续收口。
