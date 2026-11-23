# 003 远程协助独立 Fork 与真实 MSI 产出

## 本轮完成内容
- 已在 `D:\Myproject\vnt2.0\vntcrustdesk-src` 基于 RustDesk `1.4.6` 建立正式独立 fork，并推送到公开仓库 `https://github.com/luojiang419/vntcrustdesk`
- 已完成 `vntcrustdesk` 侧核心改造并真实产出 Windows x64 安装包
  - 产物：`D:\Myproject\vnt2.0\vntcrustdesk-src\artifacts\windows\vntcrustdesk.msi`
  - 版本清单：`D:\Myproject\vnt2.0\vntcrustdesk-src\artifacts\windows\vntcrustdesk.version.json`
- 已将真实 MSI 回灌到当前宿主仓
  - `D:\Myproject\vnt2.0\VntcApp1.0\third_party\vntcrustdesk\windows\dist\vntcrustdesk.msi`
  - `D:\Myproject\vnt2.0\VntcApp1.0\third_party\vntcrustdesk\windows\dist\vntcrustdesk.version.json`
- 已重新导出带 `vntcrustdesk.msi` 的主安装包
  - `D:\Myproject\vnt2.0\VntcApp1.0\dist\installer\VNT_App_2.0_Windows_Setup.exe`
  - `D:\Myproject\vnt2.0\VntcApp1.0\dist\installer\VNT_App_2.0_Windows_Setup.sha256`

## 本轮关键修复
- 修复 `vntcrustdesk` fork 的 Flutter Rust Bridge 缺失问题
  - 构建脚本现在会自动执行 `flutter_rust_bridge_codegen`
  - 自动补齐 `src/bridge_generated.rs`、`src/bridge_generated.io.rs`、`flutter/lib/generated_bridge.dart`
- 修复 Flutter 3.24.5 在当前机器误选 VS 2026 导致 CMake 退回 `Visual Studio 16 2019` 的问题
  - 已为专用 Flutter 工具链打补丁，优先选择 `C:\VS2022BuildTools`
  - 构建脚本会清理旧的 Windows CMake 缓存
- 修复 `build_msi.ps1` 结尾通过可执行程序 stdout 取版本导致的收尾崩溃
  - 现在直接读 `vntcrustdesk.exe` 文件元数据生成 `version.json`
- 修复 `preprocess.py` 非幂等问题
  - 现在每次运行都会先清空标记区，再重新生成 WiX 片段
  - 已消除重复执行后 `RustDesk.wxs` 重复符号导致的 WiX 构建失败
- 修复宿主仓 `stage_vntcrustdesk_artifact.ps1`
  - 现在可保留 fork 产物里的 `sourceCommit`、`sourceTag`、`publicSourceUrl`
- 修复宿主仓 bootstrap / uninstall 脚本
  - bootstrap 现在会校验 `49999` 监听是否真的由 `vntcrustdesk.exe` 拉起
  - manifest 现在写入真实 MSI `ProductCode`
  - uninstall 现在可从 `uninstallString` 回退提取 GUID，并会先终止 `vntcrustdesk` 进程，避免卸载卡死

## 已完成实测
- 已真实执行 `D:\Myproject\vnt2.0\vntcrustdesk-src\vntc\windows\build_msi.ps1 -SkipPrepare`，最终成功
- 已真实执行宿主仓 `scripts\stage_vntcrustdesk_artifact.ps1`
- 已真实执行宿主仓 `scripts\export_installer_package.ps1`，成功生成主安装包
- 已在当前机器做 `vntcrustdesk` 安装 / 监听 / 卸载回滚验证
  - 安装目录：`C:\Program Files\VNTC RustDesk\`
  - 服务名：`vntcrustdesk`
  - 可执行文件：`C:\Program Files\VNTC RustDesk\vntcrustdesk.exe`
- 已验证与当前机器现有官方 `RustDesk 1.4.6` 共存
  - 官方版服务名仍为 `RustDesk`
  - 官方版安装目录仍为 `C:\Program Files\RustDesk`
  - 官方版卸载项未被改动
- 已验证当前机器共存时两者同时监听 `49999`
  - 官方版：`RustDesk.exe --server` 监听 `::`:49999
  - 集成版：`vntcrustdesk.exe --server` 监听 `0.0.0.0`:49999
  - 至少在本机现有环境下，双方可以并存，不会互相覆盖服务名、目录和卸载项
- 已验证修复后的卸载链
  - `scripts\uninstall_vntcrustdesk.ps1` 可正确移除 `vntcrustdesk`
  - 卸载后官方 `RustDesk` 服务仍保持运行
  - 卸载后 `C:\Program Files\VNTC RustDesk\` 已删除
  - 卸载后 `vntcrustdesk` 卸载项已移除
  - 卸载后 `49999` 只剩官方 `RustDesk` 监听

## 当前文件落点
- 独立 fork 仓：`D:\Myproject\vnt2.0\vntcrustdesk-src`
- 独立 MSI 产物：`D:\Myproject\vnt2.0\vntcrustdesk-src\artifacts\windows\`
- 宿主仓消费产物：`D:\Myproject\vnt2.0\VntcApp1.0\third_party\vntcrustdesk\windows\dist\`
- 主安装包：`D:\Myproject\vnt2.0\VntcApp1.0\dist\installer\`

## 还未完成的验证
- 还没有做双机 VNT 虚拟 IP 直连控制实测
- 还没有做受控端确认弹窗联机实测
- 还没有做 UAC / 高权限窗口 / 锁屏后恢复 / 文件传输等远控会话级联调
- 还没有验证远程协助页面到 `vntcrustdesk.exe --connect <ip:49999>` 的双机完整成功路径

## 下一步建议
- 准备两台已接入同一 VNT 虚拟网络的 Windows 机器
- 用最新 `VNT_App_2.0_Windows_Setup.exe` 安装宿主程序和 `vntcrustdesk`
- 实测“远程协助”页面在线用户列表、复制虚拟 IP、连接、受控端确认、桌面控制、文件传输、UAC 场景
