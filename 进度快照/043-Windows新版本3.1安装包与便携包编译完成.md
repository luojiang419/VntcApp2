# 043-Windows新版本3.1安装包与便携包编译完成

## 时间
- 2026-06-23

## 本次目标
- 基于当前聊天室 Win-Mac 兼容补丁代码，编译新的 Windows 发布版本。
- 按项目既有打包流程同时产出：
  - 便携包
  - 安装包
- 确保版本号按规则自动推进，避免下一次仍编译旧版本。

## 已完成内容

### 1. 已读取最新快照并沿用当前修复状态
- 已读取：
  - `D:\Myproject\vnt2.0\VntcApp1.0\进度快照\042-聊天室WinMac兼容补丁与Windows编译完成.md`
- 本轮未新增业务代码修改，直接进入发布编译模块。

### 2. 已确认当前待编译版本号
- 编译前：
  - `D:\Myproject\vnt2.0\VntcApp1.0\scripts\build_version.txt`
  - 内容：`3.1`

### 3. 已按正式打包脚本完成 Windows 发布构建
- 执行脚本：
  - `D:\Myproject\vnt2.0\VntcApp1.0\scripts\export_installer_package.ps1`
- 脚本行为：
  - 先执行便携包导出
  - 再执行 Inno Setup 安装包导出
  - 成功后自动将版本号推进到下一次版本

### 4. 已生成 3.1 版本发布产物
- 便携目录：
  - `D:\Myproject\vnt2.0\VntcApp1.0\dist\portable\VNT_App_3.1_Windows_Portable`
- 便携包：
  - `D:\Myproject\vnt2.0\VntcApp1.0\dist\portable\VNT_App_3.1_Windows_Portable.zip`
- 便携包校验文件：
  - `D:\Myproject\vnt2.0\VntcApp1.0\dist\portable\VNT_App_3.1_Windows_SHA256.txt`
- 安装包：
  - `D:\Myproject\vnt2.0\VntcApp1.0\dist\installer\VNT_App_3.1_Windows_Setup.exe`
- 安装包校验文件：
  - `D:\Myproject\vnt2.0\VntcApp1.0\dist\installer\VNT_App_3.1_Windows_Setup.sha256`

### 5. 已完成版本号自动推进
- 编译前：
```txt
3.1
```
- 编译后：
```txt
3.2
```
- 当前文件：
  - `D:\Myproject\vnt2.0\VntcApp1.0\scripts\build_version.txt`

### 6. 已做构建后清理
- 已清理安装包中间 staging 目录：
  - `D:\Myproject\vnt2.0\VntcApp1.0\dist\installer\stage`
- 已将构建过程中被 `flutter pub` 触发的无关 `pubspec.lock` 变化回退，避免把无关依赖锁变动混入本轮结果。

## 当前修改到哪个模块
- 已完成模块：
  - `模块1：聊天室单向问题分析`
  - `模块2：聊天室Win-Mac跨版本兼容补丁`
  - `模块3：Windows新版本发布编译`

## 具体修改的代码前后对比

### 1. 版本文件修改前
```txt
3.1
```

### 1. 版本文件修改后
```txt
3.2
```

### 2. 本模块业务代码改动
- 本模块未新增业务代码改动。
- 当前代码仍沿用上一模块已完成的聊天室兼容补丁。

## 待办清单（未完成）
- 使用 Mac 环境基于当前源码编译新的 macOS 运行包/安装包。
- 用本次 Windows 3.1 新包与新的 Mac 包做真实联调：
  - Win -> Mac 文本消息
  - Win -> Mac 附件消息
  - TCP / QUIC / WSS / DYNAMIC 不同协议形式下的大厅互通
- 如果 Mac 更新到新包后仍只能发不能收，再继续排查 macOS 系统防火墙/传入连接权限。

## 下一步要做什么
- 下一步建议进入：
  - `模块4：Mac新包构建与跨端联调`
- 注意：
  - 当前这台 Windows 环境已经完成 Windows 新版本构建
  - macOS 包需要在 macOS + Xcode 环境继续编译，不能在当前 Windows 环境直接产出
