# 050-全局验证与Windows构建

## 时间
- 2026-07-09

## 本次目标
- 完成静默升级改造后的全局验证。
- 更新 Windows release 构建产物。
- 尝试导出 Windows 安装器。

## 已完成内容

### 1. 全量测试已通过
- 命令：`D:\flutter\bin\flutter.bat test -r expanded`
- 结果：59 项测试通过。

### 2. 本次改动文件定向分析已通过
- 命令：

```txt
D:\flutter\bin\dart.bat analyze lib\update\update_service.dart lib\update\update_dialog.dart lib\update\app_updater_page.dart test\update_service_test.dart test\remote_assist_macos_runtime_test.dart test\runtime_storage_paths_test.dart
```

- 结果：No issues found。

### 3. 全量分析已记录
- 命令：`D:\flutter\bin\flutter.bat analyze --no-fatal-infos --no-fatal-warnings`
- 结果：命令完成。
- 当前全项目仍有 359 个既有 warning/info，主要是旧代码中的 deprecated API、未使用元素、生产代码 print、prefer const 等。
- 本次改造涉及文件定向分析无问题。

### 4. Windows release 构建成功
- 命令：`cmd /c scripts\build_windows.bat`
- 结果：成功。
- 主要产物：
  - `build\windows\x64\runner\Release\vnt_app.exe`
  - `dist\`
  - `output\`
- 说明：
  - 构建脚本已使用 `D:\flutter\bin\flutter.bat`。
  - 构建过程中有 Rust/链接器 warning，但未导致失败。

### 5. Windows 安装器导出被远控 MSI 资产阻塞
- 命令：`powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts\export_installer_package.ps1`
- 失败原因：

```txt
vntcrustdesk MSI artifact missing:
G:\data\app\VntcApp2\third_party\vntcrustdesk\windows\dist\vntcrustdesk.msi
```

- 已尝试从 `vntcrustdesk-src` 现编 MSI：

```txt
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File vntcrustdesk-src\vntc\windows\build_msi.ps1 -FlutterRoot D:\flutter -OutputDir "G:\data\app\VntcApp2\third_party\vntcrustdesk\windows\dist"
```

- 现编失败原因：

```txt
Expected text was not found in D:\Myproject\vnt2.0\toolchains\vntcrustdesk\flutter-3.24.5\packages\flutter_tools\lib\src\windows\visual_studio.dart
```

- 已搜索 `G:\data\app` 与 `D:\Myproject`，未找到现成 `vntcrustdesk.msi`。

## 当前修改到哪个模块
- 当前完成模块：
  - `模块5：全局验证与 Windows 构建`

## 具体修改的代码前后对比
- 本模块无业务代码修改。
- 仅执行验证、构建与安装器导出尝试。

## 待办清单（未完成）
- 清理失败 MSI 准备过程中下载的临时工具链缓存。
- 初始化 git 仓库。
- 推送源码到新 GitHub 公开仓库：`https://github.com/luojiang419/VntcApp2`
- 最终确认远端文件列表。

## 下一步要做什么
- 清理本次失败的 MSI toolchain 缓存。
- 进入源码推送阶段。
