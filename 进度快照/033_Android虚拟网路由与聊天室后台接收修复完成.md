# 033 Android虚拟网路由与聊天室后台接收修复完成

## 时间
- 2026-06-06

## 本次目标
- 修正 Android 端 VNT VPN 路由把宿主 App 排除在虚拟网之外的问题。
- 让聊天室不再依赖聊天页打开后才启动，确保 Android 端可在后台接收入站消息。
- 收口 Android 远控健康状态，停止把“控制端已集成”误报成“Android 也可被控制”。

## 本次已完成

### 1. 已放开 Android 宿主 App 进入 VNT 虚拟网
- `android/app/src/main/java/top/wherewego/vnt_app/vpn/MyVpnService.java`
  - 移除了整包级排除 `top.wherewego.vnt_app` 的 VPN Builder 设计
  - 新增 `protectSocketFd(int fd)` 原生接口，作为后续 VNT / RustDesk socket 豁免入口
- `android/app/src/main/java/top/wherewego/vnt_app/FlutterMethodChannel.java`
  - 新增 `protectVpnSocketFd` 方法通道
- `lib/vnt/vnt_manager.dart`
  - 新增 `VntAppCall.protectVpnSocketFd(int fd)` Dart 包装
- 结果：
  - Android 宿主 App 内普通业务流量不再被整体排除在 VNT 虚拟网之外
  - 为后续 Rust/VNT 核心按 fd 调用 `VpnService.protect(...)` 预留了桥接能力

### 2. 聊天室已改为应用级常驻启动
- `lib/main.dart`
  - 应用启动时即 `ChatManager.instance.start()`
  - 应用退出前统一 `ChatManager.instance.stop()`
- `lib/system_tray_manager.dart`
  - 托盘退出流程补充关闭聊天室管理器
- `lib/chat/chat_manager.dart`
  - 聊天管理器改为全局常驻
  - 启动、停止、同步、收包、丢包、发送失败等关键路径补日志
- `lib/chat/chat_transport_service.dart`
  - 新增监听成功、接收连接、解码失败、发送失败等运行日志
- `lib/chat/chat_log.dart`
  - 新增聊天室独立日志文件 `chat_transport.log`
- 结果：
  - Android 端不再需要先打开聊天页才能具备聊天室收包能力
  - 后台接收链路从“页面级 runtime”改成了“应用级 runtime”

### 3. 聊天发送状态已改为真实投递结果
- `lib/chat/chat_models.dart`
  - 新增 `ChatSendResult`
  - 返回尝试目标数、成功目标数、失败目标数与最终状态
- `lib/chat/chat_manager.dart`
  - `sendText(...)` / `sendAttachment(...)` / `resendMessage(...)` 现在都返回 `ChatSendResult`
  - 大厅、房间、私聊统一按真实发送结果决定 `sent / failed`
  - 无在线接收方时不再乐观标记为已发送
- `lib/pages/chat_page.dart`
  - 文本、附件、语音、重发统一显示真实送达结果提示
  - Android 录音临时文件仍保持移动端兼容路径
- 结果：
  - “看起来发出去了，实际上没人收到”的假阳性提示被收掉
  - 大厅/房间消息在全失败时会明确显示失败

### 4. Android 远控状态已明确降级为“当前只开放控制端”
- `android/app/src/main/java/top/wherewego/vnt_app/RemoteAssistAndroidBridge.java`
  - `buildStatus()` 不再把 `serviceRunning` 伪装成 `portListening`
  - 明确返回：
    - `controlledRoleSupported = false`
    - `controlledRuntimeReady = false`
    - `listenerReady = false`
- `lib/remote_assist/remote_assist_android_bridge.dart`
  - 补齐 Android 远控状态字段解析
- `lib/remote_assist/remote_assist_android_adapter.dart`
  - `supportedRoles` 改为仅控制端
  - 健康检查文案明确提示“Android 受控端真实会话尚未接入”
- `lib/remote_assist/remote_assist_models.dart`
  - 新增 `controllerReady`、`listenerReady`、`permissionsReady`、`controlledReady`
- `lib/pages/remote_assist_page.dart`
- `lib/pages/link_status_page.dart`
  - UI 改为按真实能力展示，不再向用户宣称“当前 Android 已可被控制”
- 结果：
  - 当前包的远控能力边界已被准确表达
  - 避免继续把“有内置控制端”误读成“双向远控已就绪”

## 本次验证

### 代码级验证
- `dart analyze lib/main.dart lib/system_tray_manager.dart lib/vnt/vnt_manager.dart lib/chat/chat_log.dart lib/chat/chat_models.dart lib/chat/chat_transport_service.dart lib/chat/chat_manager.dart lib/pages/chat_page.dart lib/remote_assist/remote_assist_models.dart lib/remote_assist/remote_assist_android_bridge.dart lib/remote_assist/remote_assist_android_adapter.dart lib/pages/remote_assist_page.dart lib/pages/link_status_page.dart test/remote_assist_health_status_test.dart`
  - 通过
  - 无新的 error
  - 仍有仓库里原有的 deprecation / info 提示，未在本轮顺手清理

### 定向测试
- `mkdir -p /tmp/vnt_sqlite && ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /tmp/vnt_sqlite/libsqlite3.so && LD_LIBRARY_PATH=/tmp/vnt_sqlite flutter test test/chat_transport_service_test.dart test/remote_assist_health_status_test.dart test/chat_storage_test.dart`
  - 通过
  - `All tests passed!`
  - 说明：当前 WSL 环境只有 `libsqlite3.so.0`，没有 `libsqlite3.so` 软链；用临时 `LD_LIBRARY_PATH` 指向本机现有库后，聊天室传输、聊天室存储、Android 远控健康状态测试均通过

### Android 构建验证
- `flutter build apk --debug`
  - 当前终端环境未完成
  - WSL 终端默认未配置 Android SDK
  - 补上 `ANDROID_HOME=/mnt/c/Users/Administrator/AppData/Local/Android/Sdk` 后继续构建，发现当前环境使用的是 Windows 版 SDK 目录，Gradle 在 WSL 下判定 `Build Tools 35.0.0` 异常
  - 本轮未得到新的 APK 构建产物

## 当前修改位置
- Android VPN 宿主路由与 fd protect 桥接：
  - `android/app/src/main/java/top/wherewego/vnt_app/vpn/MyVpnService.java`
  - `android/app/src/main/java/top/wherewego/vnt_app/FlutterMethodChannel.java`
  - `lib/vnt/vnt_manager.dart`
- 聊天室后台常驻与真实投递：
  - `lib/main.dart`
  - `lib/system_tray_manager.dart`
  - `lib/chat/chat_log.dart`
  - `lib/chat/chat_models.dart`
  - `lib/chat/chat_transport_service.dart`
  - `lib/chat/chat_manager.dart`
  - `lib/pages/chat_page.dart`
- Android 远控状态收口：
  - `android/app/src/main/java/top/wherewego/vnt_app/RemoteAssistAndroidBridge.java`
  - `lib/remote_assist/remote_assist_android_bridge.dart`
  - `lib/remote_assist/remote_assist_android_adapter.dart`
  - `lib/remote_assist/remote_assist_models.dart`
  - `lib/pages/remote_assist_page.dart`
  - `lib/pages/link_status_page.dart`

## 本轮未完全完成的部分
1. `protect(fd)` 目前已打通到 Android 宿主桥接层，但尚未真正接入 Rust / VNT vendor 核心的每个外联 socket 创建路径。
2. Android 受控端仍未接入真实 screen capture host / 输入注入 / listener 监听能力，本轮已明确降级显示，但还未补齐真正可被控制的实现。
3. 本轮无法在当前 WSL 终端里复现出一份新的 APK 构建产物，主要是本机 Android SDK / Build Tools 运行环境与终端不匹配。

## 备份
- 本轮修改前备份：
  - `backup/033_Android虚拟网路由与聊天室接收修复前备份_20260606_055236`

## 下一步建议
1. 下一轮优先处理 Rust / VNT 核心 socket protect 真正接线：
   - 在 Rust wrapper 或 vendor `vnt-core` 中引入 Android fd protect 回调
   - 让 server transport、stun、nat、port mapping 等对外 socket 在 Android 上统一走 `protect(fd)`
2. 在可用的 Android 原生构建终端里重新执行 APK 编译验证，避免继续用 WSL 直接消费 Windows 版 SDK。
3. 继续补 Android 受控端真实能力：
   - screen capture host 会话
   - 无障碍输入注入
   - listener 真状态
   - 可被 Windows / Android 端接管的真实联调
