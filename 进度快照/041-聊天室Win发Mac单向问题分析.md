# 041-聊天室Win发Mac单向问题分析

## 时间
- 2026-06-23

## 本次目标
- 分析“Windows 版聊天室无法发送到 macOS 版、但可以接收 macOS 发来的消息”的根因。
- 不直接改代码，先锁定最可能的问题点和验证顺序。

## 本次已完成

### 1. 已读取最新历史快照
- 读取快照：
  - `D:\Myproject\vnt2.0\VntcApp1.0\进度快照\040_同步vntcrustdesk源码副本并准备推送.md`

### 2. 已梳理聊天室实际传输链路
- 当前聊天室不是第三方 IM 服务，而是本地自建链路：
  - `UDP 50018`：Presence 在线广播
  - `TCP 50019`：文本/附件/补同步消息收发
- 关键文件：
  - `D:\Myproject\vnt2.0\VntcApp1.0\lib\chat\chat_presence_service.dart`
  - `D:\Myproject\vnt2.0\VntcApp1.0\lib\chat\chat_transport_service.dart`
  - `D:\Myproject\vnt2.0\VntcApp1.0\lib\chat\chat_manager.dart`

### 3. 已定位两个高概率根因

#### 根因候选 A：Mac 端如果运行旧版本，会与当前 Win 端存在大厅 ID 兼容差异
- 当前代码已经加入：
  - 大厅 ID 归一化
  - 旧大厅 ID 兼容
  - 发送时双格式兼容投递
- 这些逻辑是在提交 `aff2de7` 中补进去的。
- 更早版本中，大厅 ID 直接使用原始 `connectServer` 拼接，没有归一化，也没有兼容投递。
- 因此如果：
  - Win 端是新版本
  - Mac 端是旧版本
  - 两端 `connectServer` 表达形式不同（如 `tcp://` / `quic://` / 尾部斜杠等）
- 就会出现：
  - `Mac -> Win`：新 Win 能兼容旧格式，所以能收
  - `Win -> Mac`：旧 Mac 不认新格式，直接丢包

#### 根因候选 B：macOS 侧没有像 Windows 一样做入站放行
- 当前聊天室收消息依赖本地监听：
  - `TCP 50019`
  - `UDP 50018`
- Windows 端已经做了自动防火墙规则同步。
- 但 `ChatFirewallService` 明确只在 Windows 生效，macOS 没有对应入站放行处理。
- 这会导致一种非常符合现象的情况：
  - Mac 可以主动向 Win 发消息（出站正常）
  - Win 发往 Mac 的入站连接/报文被系统防火墙拦截
  - 最终表现就是“Mac 只能发，不能收”

## 当前修改到哪个模块
- 当前完成模块：
  - `模块1：聊天室跨平台单向消息问题分析`
- 当前尚未进入代码修复模块。

## 具体修改的代码前后对比
- 本模块未修改业务代码。
- 但已确认“旧版本逻辑”和“当前版本逻辑”的关键差异如下：

### 旧逻辑（兼容补丁前）
```dart
String buildHallId({
  required String connectServer,
  required String virtualNetwork,
}) {
  return 'hall:$connectServer|$virtualNetwork';
}
```

### 当前逻辑（已加入归一化）
```dart
String buildHallId({
  required String connectServer,
  required String virtualNetwork,
}) {
  return 'hall:${normalizeChatConnectServer(connectServer)}|${virtualNetwork.trim()}';
}
```

### 当前发送侧额外兼容逻辑
```dart
final packets = <ChatTransportPacket>[
  packet,
  for (final aliasHallId in localNode.legacyHallIds)
    _packetForHallAlias(...),
];
```

## 待办清单（未完成）
- 确认当前正在使用的 macOS 安装包/源码版本，是否已经包含提交 `aff2de7` 之后的聊天兼容补丁。
- 在 Mac 真机上检查聊天室日志，重点看：
  - 是否出现 `聊天 TCP 监听已启动`
  - 是否出现 `聊天 TCP 监听启动失败`
  - 是否出现 `聊天室在线状态广播更新失败`
- 在 Mac 真机上确认系统防火墙是否拦截当前应用的传入连接。
- 如果 Mac 端确实是旧版本，先同步并重新构建 Mac 安装包再联调。
- 如果 Mac 端已是新版本，再进入代码级修复：
  - 增强启动期错误提示
  - 增加 macOS 入站能力检测/提示
  - 必要时补充 macOS 侧放行方案

## 下一步要做什么
- 下一步进入 `模块2：根因验证与修复决策`。
- 优先顺序：
  1. 先确认 Mac 端运行版本是否落后于当前 Win 端
  2. 再确认 Mac 端监听与防火墙状态
  3. 根据结果决定是“先升级 Mac 包”还是“直接补 macOS 侧能力修复”
