# 037 移除Android聊天室入口与启动链路完成

## 时间
- 2026-06-10

## 本次目标
- 先完成 Android 版聊天室功能下线。
- 确保只影响 Android，不改动 Windows 版聊天室能力。

## 本次已完成

### 1. Android 已不再启动聊天室管理器
- 修改：
  - `lib/chat/chat_manager.dart`
  - `lib/main.dart`
- 处理内容：
  - `ChatManager.supported` 已恢复为仅支持 `Platform.isWindows`
  - 应用启动时仅在 `ChatManager.instance.supported` 为 `true` 时才启动聊天室管理器
- 结果：
  - Android 启动后不再初始化聊天室传输、在线发现和定时刷新链路
  - Windows 启动逻辑保持不变

### 2. Android 主导航已移除聊天室入口
- 修改：
  - `lib/pages/main_navigation_shell.dart`
- 处理内容：
  - 导航项改为按平台动态生成
  - Android 下不再显示“聊天室”按钮
  - 配置页、设置页跳转索引改为跟随当前导航结构自动调整
- 结果：
  - Android 用户无法再从主界面进入聊天室页面
  - 移除聊天室后，Android 其他页面导航索引保持正确

## 本次验证

### 代码检查
- `dart analyze lib/chat/chat_manager.dart lib/main.dart lib/pages/main_navigation_shell.dart`
  - 通过
  - 仅存在仓库原有 `deprecated_member_use` info，未因本轮新增 error

### Android 构建验证
- `flutter build apk --debug`
  - 首次失败
  - 原因不是代码问题，而是 Rust Android 目标链下载超时：
    - `rustup target add aarch64-linux-android`
- `VNT_USE_PREBUILT_RUST_ANDROID=1 flutter build apk --debug`
  - 通过
  - 产物：
    - `build/app/outputs/flutter-apk/app-debug.apk`

## 当前修改位置
- `lib/chat/chat_manager.dart:53`
  - 聊天室平台支持范围改回仅 Windows
- `lib/main.dart:416`
  - 应用启动时仅在支持平台启动聊天室管理器
- `lib/pages/main_navigation_shell.dart:42`
  - Android 下隐藏聊天室导航项
- `lib/pages/main_navigation_shell.dart:858`
  - 配置页 / 设置页跳转索引改为动态计算
- `lib/pages/main_navigation_shell.dart:916`
  - 页面栈按平台决定是否挂载聊天室页面

## 待办清单
- 移除 Android 版远程协助页面入口
- 停止 Android 上的远程协助管理器启动与链接状态页展示
- 清理 AndroidManifest 中远程协助相关权限、服务、Activity 声明
- 完成 Android 构建回归验证
- 生成下一份进度快照

## 下一步要做什么
- 继续第二步：移除 Android 版远程协助功能，但保留 Windows 版远程协助现有实现不变。
