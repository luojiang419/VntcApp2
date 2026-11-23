# 042-聊天室WinMac兼容补丁与Windows编译完成

## 时间
- 2026-06-23

## 本次目标
- 完成“Windows 发消息到 macOS 失败”的第二阶段处理：
  - 将分析结论收敛为可执行修复
  - 直接补强聊天室跨版本大厅 ID 兼容
  - 跑测试并重新构建 Windows 产物

## 已完成内容

### 1. 已完成修复前源码备份
- 备份目录：
  - `D:\Myproject\vnt2.0\VntcApp1.0\backup\037_聊天室WinMac兼容修复前备份_20260623_124216`
- 已备份文件：
  - `lib/chat/chat_models.dart`
  - `lib/chat/chat_manager.dart`
  - `test/chat_transport_service_test.dart`
- 已补充差异文档：
  - `代码差异说明.md`

### 2. 已将根因从“猜测”收敛到“高概率跨版本兼容问题”
- 旧版聊天室接收端在入站处理时，会直接按 `remoteMessage.hallId` 精确匹配本地大厅：
```dart
if (_localNodes[remoteMessage.hallId] == null) {
  await ChatLog.write(
    '丢弃聊天消息 conversation=${remoteMessage.conversationId} hall=${remoteMessage.hallId} reason=local_hall_offline',
  );
  return;
}
```
- 旧版大厅 ID 构造没有归一化：
```dart
String buildHallId({
  required String connectServer,
  required String virtualNetwork,
}) {
  return 'hall:$connectServer|$virtualNetwork';
}
```
- 这意味着旧版 Mac 如果连的是 `tcp://...`，而新版 Win 发的是 canonical hallId 或 `quic://...` 别名，旧版 Mac 会直接丢消息。

### 3. 已补强当前版本的 legacy hallId 兼容范围
- 修改文件：
  - `D:\Myproject\vnt2.0\VntcApp1.0\lib\chat\chat_models.dart`
  - `D:\Myproject\vnt2.0\VntcApp1.0\lib\chat\chat_manager.dart`
- 修复内容：
  - 新增 `buildLegacyChatHallIdCandidates(...)`
  - 发送 legacy 兼容报文时，不再只发单个协议形式
  - 现在会覆盖常见历史协议别名：
    - `quic://`
    - `udp://`
    - `tcp://`
    - `wss://`
    - `ws://`
    - `dynamic://`
    - `txt:`

### 4. 已修正 `txt:` 动态地址的大厅归一化问题
- 修改前：
```dart
final schemeIndex = normalized.indexOf('://');
if (schemeIndex > 0) {
  normalized = normalized.substring(schemeIndex + 3);
}
```
- 修改后：
```dart
if (lower.startsWith('txt:')) {
  normalized = normalized.substring('txt:'.length);
} else {
  final schemeIndex = normalized.indexOf('://');
  if (schemeIndex > 0) {
    normalized = normalized.substring(schemeIndex + 3);
  }
}
```
- 效果：
  - `txt:host:port`
  - `dynamic://host:port`
  - 现在会归一化到同一个大厅 ID

### 5. 已补测试，防止兼容逻辑回退
- 修改文件：
  - `D:\Myproject\vnt2.0\VntcApp1.0\test\chat_transport_service_test.dart`
- 新增测试覆盖：
  - `txt:` 与 `dynamic://` 大厅归一化一致
  - legacy hallId 候选覆盖常见协议别名

### 6. 已完成验证
- 静态检查：
  - `D:\APPdata\flutter\bin\dart.bat analyze lib\chat\chat_models.dart lib\chat\chat_manager.dart test\chat_transport_service_test.dart test\chat_platform_support_test.dart`
  - 结果：`No issues found!`
- 单元测试：
  - `D:\APPdata\flutter\bin\flutter.bat test test\chat_transport_service_test.dart test\chat_platform_support_test.dart`
  - 结果：`All tests passed!`
- Windows 构建：
  - `D:\APPdata\flutter\bin\flutter.bat build windows --debug`
  - 结果：构建成功
  - 产物：
    - `D:\Myproject\vnt2.0\VntcApp1.0\build\windows\x64\runner\Debug\vnt_app.exe`

## 当前修改到哪个模块
- 已完成模块：
  - `模块1：聊天室单向问题分析`
  - `模块2：聊天室Win-Mac跨版本兼容补丁`
- 当前未继续进入下一模块代码修改。

## 具体修改的代码前后对比

### 1. legacy hallId 发送前
```dart
return servers
    .map((server) => buildLegacyChatHallId(
          connectServer: server,
          virtualNetwork: virtualNetwork,
        ))
    .where((hallId) => hallId != canonicalHallId)
    .toSet()
    .toList(growable: false);
```

### 1. legacy hallId 发送后
```dart
return servers
    .expand(
      (server) => buildLegacyChatHallIdCandidates(
        connectServer: server,
        virtualNetwork: virtualNetwork,
      ),
    )
    .where((hallId) => hallId != canonicalHallId)
    .toSet()
    .toList(growable: false);
```

### 2. connectServer 主体提取前
```dart
final schemeIndex = normalized.indexOf('://');
if (schemeIndex > 0) {
  normalized = normalized.substring(schemeIndex + 3);
}
```

### 2. connectServer 主体提取后
```dart
if (lower.startsWith('txt:')) {
  normalized = normalized.substring('txt:'.length);
} else {
  final schemeIndex = normalized.indexOf('://');
  if (schemeIndex > 0) {
    normalized = normalized.substring(schemeIndex + 3);
  }
}
```

## 待办清单（未完成）
- 将这次兼容补丁同步到实际运行的 macOS 安装包/可执行版本。
- 在 Mac 真机上联调验证：
  - Win -> Mac 文本消息
  - Win -> Mac 附件消息
  - 不同协议接入（TCP / QUIC / WSS / DYNAMIC）下的大厅互通
- 如果 Mac 更新到本次补丁后仍然只能发不能收，继续检查：
  - macOS 系统防火墙是否阻止应用传入连接
  - Mac 端是否真实监听 `TCP 50019 / UDP 50018`

## 下一步要做什么
- 下一步建议进入：
  - `模块3：Mac 真机联调与系统防火墙排查`
- 优先动作：
  1. 使用本次补丁对应源码重新生成 Mac 端安装包/运行包
  2. 与当前 Windows 新包做一轮真实收发验证
  3. 若仍异常，再针对 macOS 入站环境做专项排查
