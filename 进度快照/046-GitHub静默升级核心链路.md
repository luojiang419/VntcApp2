# 046-GitHub静默升级核心链路

## 时间
- 2026-07-09

## 本次目标
- 参考 `G:\data\app\故事板` 最新 GitHub 静默升级方式，把当前项目 Windows 更新流程从“下载后外部打开安装包”改为“打开独立更新进度窗口并静默安装”。
- Android APK 仍保留系统安装器路径。

## 已完成内容

### 1. 已读取上一轮最新快照
- 最新快照：`进度快照/045-轻量源码分发包制作.md`
- 上一轮没有业务代码待办。

### 2. 已核对参考项目路径
- 用户给出的 `G:\data\app\故事板r` 当前不存在。
- 已按实际存在且高度匹配的 `G:\data\app\故事板` 读取参考实现。
- 重点参考：
  - `进度快照/139-GitHub静默升级改造.md`
  - `进度快照/142-更新进度窗口改造.md`
  - `进度快照/149-更新确认与自动更新开关.md`
  - `lib/features/updater/data/updater_service.dart`
  - `lib/features/updater/presentation/app_updater_page.dart`

### 3. 已创建阶段备份
- 新增：`backup/001-GitHub静默升级改造前.md`
- 已记录本阶段关键代码修改前后对比。

### 4. 已完成静默升级核心链路
- `lib/update/update_service.dart`
  - 新增更新器会话参数解析。
  - 新增 `AppUpdateInstallSession` 与 `AppUpdateProgressEvent`。
  - Windows 下载完成后不再直接打开安装包。
  - Windows 会复制当前 Flutter 运行时到临时 staging 目录并启动独立更新窗口。
  - 更新窗口等待旧进程退出后，通过 PowerShell 调用 Inno Setup 静默安装参数：
    - `/SP-`
    - `/VERYSILENT`
    - `/SUPPRESSMSGBOXES`
    - `/NORESTART`
    - `/NOCANCEL`
    - `/CLOSEAPPLICATIONS`
    - `/FORCECLOSEAPPLICATIONS`
    - `/DIR=...`
    - `/LOG=...`
  - 安装完成后自动启动新版程序。
- `lib/update/app_updater_page.dart`
  - 新增独立更新进度窗口。
  - 展示准备安装、关闭旧版本、安装新版本、启动新版本、完成五个阶段。
- `lib/main.dart`
  - 新增更新器会话早期分流。
  - 更新器会话只启动最小 MaterialApp，不执行完整 VNT 业务初始化。
- `lib/update/update_dialog.dart`
  - Windows 按钮文案改为“下载并静默升级”。
  - Windows 启动更新进度窗口后延迟退出旧版本。
  - 非 Windows 平台继续保留原有外部打开安装包体验。
- `test/update_service_test.dart`
  - 补充版本标签规范化测试。
  - 补充更新器会话参数解析测试。

## 当前修改到哪个模块
- 当前完成模块：
  - `模块1：GitHub 静默升级核心链路`

## 具体修改的代码前后对比

### 1. 更新服务入口

修改前：

```dart
Future<void> openDownloadedInstaller(AppUpdateDownloadResult result) async {
  if (Platform.isAndroid) {
    await AndroidUpdateInstaller.installApk(result.filePath);
    return;
  }
  final uri = Uri.file(result.filePath);
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened) {
    throw StateError('无法打开安装包：${result.filePath}');
  }
}
```

修改后：

```dart
Future<void> openDownloadedInstaller(AppUpdateDownloadResult result) async {
  if (Platform.isAndroid) {
    await AndroidUpdateInstaller.installApk(result.filePath);
    return;
  }
  if (Platform.isWindows) {
    final launched = await _launchWindowsUpdater(result);
    if (!launched) {
      throw StateError('无法启动更新进度窗口：${result.filePath}');
    }
    return;
  }
  final uri = Uri.file(result.filePath);
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened) {
    throw StateError('无法打开安装包：${result.filePath}');
  }
}
```

### 2. 主入口

修改前：

```dart
Future<void> main() async {
  _writeBootTrace('main enter');
```

修改后：

```dart
Future<void> main(List<String> args) async {
  _writeBootTrace('main enter');

  final updaterSession = AppUpdateService.parseInstallSessionArgs(args);
  if (updaterSession != null) {
    WidgetsFlutterBinding.ensureInitialized();
    await _runUpdaterSessionApp(updaterSession);
    return;
  }
```

### 3. 更新对话框

修改前：

```dart
showTopToast(context, '安装包已下载，已交给系统处理', isSuccess: true);
Navigator.of(context).pop();
```

修改后：

```dart
showTopToast(
  context,
  Platform.isWindows ? '更新进度窗口已打开，正在退出旧版本' : '安装包已下载，已交给系统处理',
  isSuccess: true,
);
Navigator.of(context).pop();
if (Platform.isWindows) {
  unawaited(
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      exit(0);
    }),
  );
}
```

## 验证结果
- 通过：`D:\flutter\bin\flutter.bat pub get`
- 通过：`D:\flutter\bin\dart.bat format ...`
- 通过：`D:\flutter\bin\dart.bat analyze lib\update\update_service.dart lib\update\update_dialog.dart lib\update\app_updater_page.dart test\update_service_test.dart`
  - 结果：No issues found。
- 通过：`D:\flutter\bin\flutter.bat test test\update_service_test.dart -r expanded`
  - 结果：5 项测试通过。

## 待办清单（未完成）
- 创建新的 GitHub 公开仓库。
- 将默认 GitHub Release 更新地址改为新仓库。
- 初始化本项目 git 仓库并推送源码。
- 运行全量 `flutter analyze`。
- 运行全量 `flutter test`。
- 尝试 Windows 构建/安装包构建，确保构建产物更新。
- 清理本次开发产生的临时缓存。

## 下一步要做什么
- 进入 `模块2：GitHub 公开仓库与更新地址适配`。
- 先检查 `gh` 登录状态与 GitHub 用户名，再创建公开仓库并把更新默认地址改到新仓库。
