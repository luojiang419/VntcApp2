# 035 Android聊天室在线发现兜底与远程协助宿主接线完成

## 时间
- 2026-06-06

## 本次目标
- 修复 Android 端聊天室在 Presence 异常或未到达时，在线用户列表为空、消息无法正常投递的问题。
- 修复 Android 端远程协助“页面可见但宿主链路未接通”的状态，让访问密码配置与受控服务启动真正走到 `flutter_hbb`/`librustdesk.so` 宿主链路。

## 本次已完成

### 1. 聊天室已增加“无 Presence 时按 VNT 在线设备兜底”
- 修改：
  - `lib/chat/chat_manager.dart`
- 处理内容：
  - `_mergeOnlinePeers()` 不再强依赖 `ChatPresenceAnnouncement`
  - 只要 VNT peer 列表里设备在线，就先纳入聊天室在线用户
  - 如果有 Presence，就继续使用 Presence 的显示名和房间信息
  - 如果没有 Presence，就退回到 VNT 基础在线信息
- 结果：
  - Android 端即使临时收不到聊天室 Presence，公共大厅和私聊也不会直接“看起来没人在线”
  - 聊天补同步 `_syncKnownPeers()` 也不再因为在线列表为空而完全不触发

### 2. Android 远程协助访问密码已接到真实 RustDesk 配置
- 新增：
  - `lib/remote_assist/remote_assist_android_runtime.dart`
- 修改：
  - `lib/remote_assist/remote_assist_android_adapter.dart`
  - `lib/remote_assist/controller_mobile/embedded_remote_assist_launcher.dart`
- 处理内容：
  - 新增 Android 远控运行时引导器，统一初始化 `flutter_hbb`
  - “设置远程密码”不再只写内存态 `RemoteAssistStateHolder`
  - 现在会真实写入：
    - permanent password
    - `verification-method`
    - `approve-mode`
  - 控制端弹出的内置远控会话，与受控端宿主链路复用同一套 RustDesk bootstrap，避免重复初始化
- 结果：
  - Android 端远程密码配置不再是“界面成功、宿主无效”的假成功
  - 后续 Windows/Android 控制端连接 Android 被控端时，配置上下文终于一致

### 3. Android 远程协助受控端已从“占位桥接”改为真实宿主启动链路
- 修改：
  - `android/app/src/main/java/top/wherewego/vnt_app/MainActivity.java`
  - `android/app/src/main/java/top/wherewego/vnt_app/RemoteAssistAndroidBridge.java`
  - `android/app/src/main/java/top/wherewego/vnt_app/RemoteAssistControlledService.java`
  - `android/app/src/main/java/top/wherewego/vnt_app/RemoteAssistScreenCaptureActivity.java`
  - `lib/remote_assist/remote_assist_android_adapter.dart`
  - `lib/remote_assist/remote_assist_manager.dart`
- 处理内容：
  - RustDesk Android 方法通道补上：
    - `init_service`
    - `check_service`
    - `start_capture`
    - `stop_service`
  - `RemoteAssistControlledService` 现在会把宿主启停状态回推到 Flutter
  - 录屏授权 Activity 在授权成功/取消时都会把状态回推到 Flutter
  - Android 远控健康状态不再固定写死成“只支持控制端”
  - `RemoteAssistManager.start()` 现在会真正调用平台 adapter 的 `start/refreshState`
- 结果：
  - Android 远控受控端不再停留在“按钮能点、状态会变，但宿主不工作”的半成品状态
  - 远控页现在会按真实受控服务状态计算 readiness

### 4. 远程协助页面补上了受控服务启停反馈
- 修改：
  - `lib/pages/remote_assist_page.dart`
- 处理内容：
  - 启动/停止受控服务改成统一封装的 `_toggleControlledService()`
  - 补上成功/失败 toast
  - 屏幕录制未授权时，会明确提示用户先完成授权
- 结果：
  - Android 端点击“启动受控服务”不再静默失败
  - 用户现在能直接知道是权限没完成，还是宿主链路启动失败

## 本次验证

### 代码与测试
- `flutter test test/chat_transport_service_test.dart test/chat_storage_test.dart test/remote_assist_health_status_test.dart`
  - 通过
- `flutter analyze lib/chat/chat_manager.dart lib/pages/remote_assist_page.dart lib/remote_assist`
  - 无新的 error
  - 仍有仓库原有 `withOpacity` / `prefer_const_constructors` info，未在本轮顺手清理

### Android 构建
- `VNT_USE_PREBUILT_RUST_ANDROID=1 flutter build apk --debug`
  - 通过
- `VNT_USE_PREBUILT_RUST_ANDROID=1 flutter build apk --release`
  - 通过

### 产物
- Debug：
  - `build/app/outputs/flutter-apk/app-debug.apk`
- Release：
  - `build/app/outputs/flutter-apk/app-release.apk`

## 当前修改位置
- 聊天室在线发现兜底：
  - `lib/chat/chat_manager.dart`
- Android 远控运行时与宿主桥接：
  - `lib/remote_assist/remote_assist_android_runtime.dart`
  - `lib/remote_assist/remote_assist_android_adapter.dart`
  - `lib/remote_assist/remote_assist_manager.dart`
  - `lib/remote_assist/controller_mobile/embedded_remote_assist_launcher.dart`
  - `lib/pages/remote_assist_page.dart`
  - `android/app/src/main/java/top/wherewego/vnt_app/MainActivity.java`
  - `android/app/src/main/java/top/wherewego/vnt_app/RemoteAssistAndroidBridge.java`
  - `android/app/src/main/java/top/wherewego/vnt_app/RemoteAssistControlledService.java`
  - `android/app/src/main/java/top/wherewego/vnt_app/RemoteAssistScreenCaptureActivity.java`

## 本轮仍未完全消除的边界
1. 聊天室这次优先修的是“在线发现为空导致基础聊天不可用”。
   - 如果 Android 环境下 UDP Presence 长期不可达，自定义聊天室的房间发现仍建议继续做真机联调
   - 下一轮如仍有问题，可考虑把房间元数据再补一条 TCP 同步链路
2. Android 远控宿主链路已经接到 `flutter_hbb` 启动流，但真正的双机远控体验仍需要真机验证：
   - Windows -> Android 被控
   - Android -> Android 被控
   - 访问密码直连
   - 无障碍输入是否真实落到设备
3. 当前仓库里仍有大量其他未提交改动，本轮未去触碰或回滚无关文件

## 备份
- 本轮修改前备份：
  - `backup/035_Android聊天室与远程协助修复前备份_20260606_095743`

## 下一步建议
1. 先用本轮新的 APK 做双机真机联调：
   - Android 聊天大厅/私聊
   - Android 受控端启动
   - Windows 端输入 Android 虚拟 IP 发起协助
   - 访问密码直连
2. 如果聊天室“自定义房间”在 Android 上仍有边角问题，下一轮优先把房间元数据从 UDP Presence 补成 TCP 同步兜底。
3. 如果 Android 远控已经能连上但输入无效，下一轮重点继续落 `RemoteAssistInputService` 的真实输入注入，不再只是权限托管。
