# 进度快照 025 - 安装名称固定与 VNTC APP2.0 编译完成

## 本次已完成

1. 已完成构建命名规则回调
   - `scripts/build_windows.bat` 已改为：
     - `APP_PRODUCT_NAME = VNTC APP2.0`
     - `APP_WINDOW_TITLE = VNTC APP2.0 v<build_version>`
   - `APP_DISPLAY_VERSION` 仍继续由 `scripts/build_version.txt` 自动递增驱动

2. 已完成 Flutter 侧标题聚合调整
   - `lib/app_version.dart` 已改为：
     - 产品名默认固定为 `VNTC APP2.0`
     - 窗口标题默认拼接为 `VNTC APP2.0 vX.Y`
   - `lib/main.dart` 的 `MaterialApp.title` 已改为读取 `AppVersion.windowTitle`

3. 已完成 Windows 原生标题与 EXE 元数据调整
   - `windows/runner/main.cpp` 启动瞬间窗口标题已改为 `VNTC APP2.0 vX.Y`
   - `windows/runner/Runner.rc` 的：
     - `FileDescription`
     - `ProductName`
   - 已同步改为 `VNTC APP2.0 vX.Y`

4. 已完成安装器命名规则调整
   - `scripts/export_installer_package.ps1` 已改为：
     - 安装器界面名固定为 `VNTC APP2.0`
     - 开始菜单组名固定为 `VNTC APP2.0`
     - 桌面快捷方式名固定为 `VNTC APP2.0`
     - 卸载项显示名为 `VNTC APP2.0 v2.6`
   - 安装目录物理基名继续保持 `VNT App`，避免升级路径抖动

5. 已完成版本规则文档同步
   - `编译版本规则.md` 已更新为新的命名策略：
     - 安装链路名称固定
     - 文件名继续带版本号
     - 窗口标题和卸载项继续带递增版本

6. 已完成 `2.6` 安装包与便携包编译
   - 执行命令：
     - `PowerShell -NoProfile -ExecutionPolicy Bypass -File scripts/export_installer_package.ps1`
   - 产物已生成：
     - `dist/installer/VNT_App_2.6_Windows_Setup.exe`
     - `dist/installer/VNT_App_2.6_Windows_Setup.sha256`
     - `dist/portable/VNT_App_2.6_Windows_Portable`
     - `dist/portable/VNT_App_2.6_Windows_Portable.zip`
     - `dist/portable/VNT_App_2.6_Windows_SHA256.txt`
   - `scripts/build_version.txt` 已自动推进到下一次版本 `2.7`

## 本次验证结果

- 已通过静态检查：
  - `D:\APPdata\flutter\bin\dart.bat analyze lib\app_version.dart lib\main.dart`
  - 结果：仅有 `lib/main.dart` 里一个与本次改动无关的既有 `onPopInvoked` 弃用提示
- 已通过脚本语法检查：
  - `scripts/export_installer_package.ps1`
  - `scripts/export_portable_package.ps1`
- 已通过编译验证：
  - `dist/installer/stage/VNT_App_2.6_Windows_Setup.iss`
  - 已确认：
    - `MyAppName = VNTC APP2.0`
    - `MyAppVersionedName = VNTC APP2.0 v2.6`
    - `DefaultDirName = {autopf}\VNT App`
    - `OutputBaseFilename = VNT_App_2.6_Windows_Setup`
- 已通过 EXE 元数据验证：
  - `build/windows/x64/runner/Release/vnt_app.exe`
  - `output/vnt_app.exe`
  - `dist/portable/VNT_App_2.6_Windows_Portable/vnt_app.exe`
  - 已确认：
    - `FileDescription = VNTC APP2.0 v2.6`
    - `ProductName = VNTC APP2.0 v2.6`
    - `FileVersion = 2.6.0`
    - `ProductVersion = 2.6.0`

## 当前修改位置

- Flutter 版本与标题聚合：
  - `lib/app_version.dart`
  - `lib/main.dart`
- Windows 构建脚本：
  - `scripts/build_windows.bat`
- Windows 安装器脚本：
  - `scripts/export_installer_package.ps1`
- Windows 原生标题与元数据：
  - `windows/runner/main.cpp`
  - `windows/runner/Runner.rc`
- 规则文档：
  - `编译版本规则.md`

## 待办清单

1. 建议手工安装 `dist/installer/VNT_App_2.6_Windows_Setup.exe`
2. 建议实际点验：
   - 安装器界面标题是否固定为 `VNTC APP2.0`
   - 开始菜单与桌面快捷方式名称是否固定为 `VNTC APP2.0`
   - 应用左上标题是否显示为 `VNTC APP2.0 v2.6`
   - 控制面板卸载项是否显示为 `VNTC APP2.0 v2.6`
3. 后续如需整套品牌迁移，再单独评估：
   - `关于页`
   - 本地化文案
   - 内部稳定标识与运行时目录

## 下一步要做什么

当前这轮命名规则调整与 `2.6` 编译已经完成。下一步更适合进入安装实机点验阶段，重点确认安装器界面、快捷方式、左上标题和卸载项显示是否与新的 `VNTC APP2.0` 规则一致。
