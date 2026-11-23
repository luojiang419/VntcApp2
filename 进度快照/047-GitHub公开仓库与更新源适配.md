# 047-GitHub公开仓库与更新源适配

## 时间
- 2026-07-09

## 本次目标
- 为当前项目创建新的 GitHub 公开仓库。
- 将应用内置 GitHub Release 更新地址切换到新仓库。

## 已完成内容

### 1. 已确认 GitHub CLI 与账号
- `gh --version`：可用，版本 `2.92.0`。
- `gh auth status`：已登录 `github.com`。
- 当前账号：`luojiang419`。

### 2. 已确认仓库命名
- `luojiang419/VntcApp2`：创建前不存在。
- `luojiang419/VNTC2.0-APP`：已存在且公开，是旧默认更新源。

### 3. 已创建新的公开仓库
- 新仓库：`https://github.com/luojiang419/VntcApp2`
- 可见性：Public

### 4. 已更新默认 GitHub Release 地址
- 文件：`lib/update/update_service.dart`

修改前：

```dart
static const latestReleaseApiUrl = String.fromEnvironment(
  'APP_UPDATE_API_URL',
  defaultValue:
      'https://api.github.com/repos/luojiang419/VNTC2.0-APP/releases/latest',
);
static const releasePageUrl = String.fromEnvironment(
  'APP_UPDATE_RELEASE_PAGE_URL',
  defaultValue: 'https://github.com/luojiang419/VNTC2.0-APP/releases/latest',
);
```

修改后：

```dart
static const latestReleaseApiUrl = String.fromEnvironment(
  'APP_UPDATE_API_URL',
  defaultValue:
      'https://api.github.com/repos/luojiang419/VntcApp2/releases/latest',
);
static const releasePageUrl = String.fromEnvironment(
  'APP_UPDATE_RELEASE_PAGE_URL',
  defaultValue: 'https://github.com/luojiang419/VntcApp2/releases/latest',
);
```

## 当前修改到哪个模块
- 当前完成模块：
  - `模块2：GitHub 公开仓库与更新地址适配`

## 待办清单（未完成）
- 初始化本地 git 仓库。
- 检查并确认 `.gitignore` 能排除构建产物、缓存、备份大文件。
- 全量分析/测试。
- Windows 构建或安装包构建验证。
- 推送源码到 `https://github.com/luojiang419/VntcApp2`。
- 清理本次开发产生的临时缓存。

## 下一步要做什么
- 进入 `模块3：全局验证、构建与源码推送`。
