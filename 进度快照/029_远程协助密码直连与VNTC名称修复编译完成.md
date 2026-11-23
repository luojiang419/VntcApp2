# 029_远程协助密码直连与VNTC名称修复编译完成

## 记录时间
- 2026-06-05 01:xx（亚洲/上海）

## 本轮目标
- 修复远程协助设置非空远程密码后仍需手动接受的问题。
- 修复 `VNTC RustDesk` 安装后应用名称重复成 `VNTC VNTC ... RustDesk` 的问题。
- 重新编译 `vntcrustdesk` MSI，并重新导出主项目完整安装包。

## 已完成内容
- 已完成远程密码直连逻辑修复：
  - `D:\Myproject\vnt2.0\vntcrustdesk-src\src\vntc.rs`
  - `D:\Myproject\vnt2.0\vntcrustdesk-src\src\flutter_ffi.rs`
  - `D:\Myproject\vnt2.0\vntcrustdesk-src\flutter\lib\main.dart`
- 已完成 Flutter 3.41.7 兼容修复：
  - `D:\Myproject\vnt2.0\vntcrustdesk-src\flutter\lib\common.dart`
  - `D:\Myproject\vnt2.0\vntcrustdesk-src\flutter\lib\desktop\pages\file_manager_page.dart`
  - `D:\Myproject\vnt2.0\vntcrustdesk-src\flutter\pubspec.yaml`
  - `D:\Myproject\vnt2.0\vntcrustdesk-src\flutter\pubspec.lock`
- 已定位并修复安装名称重复根因：
  - 根因在 `D:\Myproject\vnt2.0\vntcrustdesk-src\res\msi\preprocess.py`
  - 反复执行简单 `replace("RustDesk", app_name)` 会把 `VNTC RustDesk` 继续叠加成多个 `VNTC`
  - 现已改为幂等替换，重复前缀会收敛回单个 `VNTC RustDesk`
- 已修复 Windows 打包链路兼容问题：
  - `D:\Myproject\vnt2.0\vntcrustdesk-src\vntc\windows\build_msi.ps1`
  - 支持优先使用 `D:\APPdata\flutter`
  - 支持 VS 2026 的 `v145` 平台工具集覆盖
  - 对 Flutter 3.41.7 跳过 RustDesk 旧自定义引擎覆盖，避免运行期 snapshot 不匹配
  - 保留对默认 `flutter-3.24.5` 工具链的兼容判断
- 已重新生成远程协助安装产物：
  - `D:\Myproject\vnt2.0\vntcrustdesk-src\artifacts\windows\vntcrustdesk.msi`
  - `D:\Myproject\vnt2.0\vntcrustdesk-src\artifacts\windows\vntcrustdesk.version.json`
- 已核验 MSI 中的产品名：
  - `ProductName = VNTC RustDesk`
  - 不再是 `VNTC VNTC ... RustDesk`
- 已把新 MSI 接入主项目：
  - `D:\Myproject\vnt2.0\VntcApp1.0\third_party\vntcrustdesk\windows\dist\vntcrustdesk.msi`
- 已重新导出主项目完整产物：
  - 安装包：`D:\Myproject\vnt2.0\VntcApp1.0\dist\installer\VNT_App_2.9_Windows_Setup.exe`
  - 安装包校验：`D:\Myproject\vnt2.0\VntcApp1.0\dist\installer\VNT_App_2.9_Windows_Setup.sha256`
  - 便携包：`D:\Myproject\vnt2.0\VntcApp1.0\dist\portable\VNT_App_2.9_Windows_Portable.zip`
  - 便携包校验：`D:\Myproject\vnt2.0\VntcApp1.0\dist\portable\VNT_App_2.9_Windows_SHA256.txt`
- 已做 CLI 烟测：
  - `--configure-access-password "Abc123!"` 真实退出码 `0`
  - `--configure-access-password ""` 通过原始参数字符串传空值，真实退出码 `0`

## 当前修改到哪一块
- `vntcrustdesk-src` 侧本轮已经收口到“可编译、可打 MSI、名称正确、主项目已重新打包”的完成态。
- 主项目这边已完成新 MSI 接入与安装包导出。
- `scripts/build_version.txt` 当前已推进到下一轮版本号：`3.0`

## 待办清单
- 若要继续做更强验证，下一步建议在真实两台机器上做远程协助联调：
  - 设置非空远程密码后，控制端输入密码直连，确认不再弹“等待对方接受”
  - 清空远程密码后，确认恢复为手动接受
- 若后续仍需长期维护 `vntcrustdesk` Windows 构建链，建议把 Flutter 版本策略进一步固化成脚本文档，避免误用不匹配的自定义引擎

## 下一步建议
- 先安装本轮导出的 `VNT_App_2.9_Windows_Setup.exe` 做一次人工回归。
- 若人工回归通过，再决定是否提交本轮代码与产物整理。
