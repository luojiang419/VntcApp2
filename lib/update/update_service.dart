import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vnt_app/app_version.dart';

enum AppUpdatePlatform { android, windows, macos, linux, ios, unsupported }

class AppUpdateAsset {
  const AppUpdateAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    this.contentType,
    this.sha256,
  });

  final String name;
  final Uri downloadUrl;
  final int size;
  final String? contentType;
  final String? sha256;

  static AppUpdateAsset? fromGitHubJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString();
    final rawUrl = (json['browser_download_url'] ?? '').toString();
    final url = Uri.tryParse(rawUrl);
    if (name.isEmpty || url == null) {
      return null;
    }
    return AppUpdateAsset(
      name: name,
      downloadUrl: url,
      size: int.tryParse('${json['size'] ?? 0}') ?? 0,
      contentType: json['content_type']?.toString(),
      sha256: json['sha256']?.toString(),
    );
  }
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.tagName,
    required this.releaseName,
    required this.releaseNotes,
    required this.releasePageUrl,
    required this.hasUpdate,
    required this.platform,
    required this.asset,
    this.proxyLabel,
  });

  final String currentVersion;
  final String latestVersion;
  final String tagName;
  final String releaseName;
  final String releaseNotes;
  final Uri releasePageUrl;
  final bool hasUpdate;
  final AppUpdatePlatform platform;
  final AppUpdateAsset? asset;
  final String? proxyLabel;

  bool get canDownload => asset != null && platform != AppUpdatePlatform.ios;

  String get shortReleaseNotes {
    final trimmed = releaseNotes.trim();
    if (trimmed.length <= 500) {
      return trimmed;
    }
    return '${trimmed.substring(0, 500)}...';
  }
}

class AppUpdateDownloadResult {
  const AppUpdateDownloadResult({
    required this.filePath,
    required this.asset,
    required this.versionTag,
    this.proxyLabel,
  });

  final String filePath;
  final AppUpdateAsset asset;
  final String versionTag;
  final String? proxyLabel;
}

class AppUpdateProxy {
  const AppUpdateProxy({required this.config, required this.label});

  final String config;
  final String label;
}

typedef AppUpdateProgress = void Function(int received, int total);

typedef AppUpdateProcessLauncher =
    Future<int> Function(
      String executable,
      List<String> arguments, {
      ProcessStartMode mode,
      bool runInShell,
    });

class AppUpdateInstallSession {
  const AppUpdateInstallSession({
    required this.sessionId,
    required this.versionTag,
    required this.installerPath,
    required this.installRoot,
    required this.oldProcessId,
  });

  final String sessionId;
  final String versionTag;
  final String installerPath;
  final String installRoot;
  final int oldProcessId;
}

class AppUpdateProgressEvent {
  const AppUpdateProgressEvent({
    required this.stepIndex,
    required this.stepLabel,
    required this.message,
    this.substep = '',
    this.isError = false,
    this.isSuccess = false,
  });

  final int stepIndex;
  final String stepLabel;
  final String message;
  final String substep;
  final bool isError;
  final bool isSuccess;
}

class AppUpdateService {
  AppUpdateService({
    Future<AppUpdateProxy?> Function()? proxyResolver,
    AppUpdateProcessLauncher? processLauncher,
    Directory? stagingRootDirectory,
  }) : _proxyResolver = proxyResolver ?? AppUpdateProxyResolver.resolve,
       _processLauncher = processLauncher ?? _defaultProcessLauncher,
       _stagingRootDirectory = stagingRootDirectory;

  static const latestReleaseApiUrl = String.fromEnvironment(
    'APP_UPDATE_API_URL',
    defaultValue:
        'https://api.github.com/repos/luojiang419/VntcApp2/releases/latest',
  );
  static const releasePageUrl = String.fromEnvironment(
    'APP_UPDATE_RELEASE_PAGE_URL',
    defaultValue: 'https://github.com/luojiang419/VntcApp2/releases/latest',
  );
  static const updaterSessionArg = '--run-update-session=';
  static const updaterVersionArg = '--update-version=';
  static const updaterInstallerArg = '--update-installer=';
  static const updaterInstallRootArg = '--update-install-root=';
  static const updaterOldPidArg = '--update-old-pid=';
  static const updaterRelaunchDelayMilliseconds = 800;

  final Future<AppUpdateProxy?> Function() _proxyResolver;
  final AppUpdateProcessLauncher _processLauncher;
  final Directory? _stagingRootDirectory;

  static AppUpdateInstallSession? parseInstallSessionArgs(List<String> args) {
    final sessionId = _argumentValue(args, updaterSessionArg);
    if (sessionId == null || sessionId.trim().isEmpty) {
      return null;
    }
    final versionTag = normalizeUpdateVersionTag(
      _argumentValue(args, updaterVersionArg) ?? '',
    );
    final installerPath = _argumentValue(args, updaterInstallerArg) ?? '';
    final installRoot = _argumentValue(args, updaterInstallRootArg) ?? '';
    final oldProcessId = int.tryParse(
      _argumentValue(args, updaterOldPidArg) ?? '',
    );
    if (versionTag.isEmpty ||
        installerPath.trim().isEmpty ||
        installRoot.trim().isEmpty ||
        oldProcessId == null) {
      return null;
    }
    return AppUpdateInstallSession(
      sessionId: sessionId.trim(),
      versionTag: versionTag,
      installerPath: installerPath,
      installRoot: installRoot,
      oldProcessId: oldProcessId,
    );
  }

  Future<AppUpdateInfo> checkLatest({
    String? currentVersion,
    AppUpdatePlatform? platform,
  }) async {
    final proxy = await _proxyResolver();
    final release = await _fetchJson(
      Uri.parse(latestReleaseApiUrl),
      proxy: proxy,
    );
    final resolvedCurrentVersion =
        currentVersion ?? await _resolveCurrentVersion();
    final resolvedPlatform = platform ?? resolveCurrentUpdatePlatform();
    return parseGitHubRelease(
      release,
      currentVersion: resolvedCurrentVersion,
      platform: resolvedPlatform,
      proxyLabel: proxy?.label,
    );
  }

  Future<AppUpdateDownloadResult> downloadUpdate(
    AppUpdateInfo info, {
    AppUpdateProgress? onProgress,
  }) async {
    final asset = info.asset;
    if (asset == null) {
      throw StateError('当前平台没有可下载的安装包');
    }
    if (info.platform == AppUpdatePlatform.ios) {
      throw StateError('iOS 版本需要通过 TestFlight、App Store 或企业分发更新');
    }

    final directory = await _resolveDownloadDirectory();
    await directory.create(recursive: true);
    final filePath = path.join(directory.path, _safeFileName(asset.name));
    final target = File(filePath);
    if (await target.exists()) {
      await target.delete();
    }

    final proxy = await _proxyResolver();
    await _downloadFile(
      asset.downloadUrl,
      target,
      proxy: proxy,
      onProgress: onProgress,
    );

    if (Platform.isLinux && asset.name.toLowerCase().endsWith('.appimage')) {
      await Process.run('chmod', ['+x', target.path], runInShell: true);
    }

    return AppUpdateDownloadResult(
      filePath: target.path,
      asset: asset,
      versionTag: normalizeUpdateVersionTag(info.tagName),
      proxyLabel: proxy?.label,
    );
  }

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

  Future<void> openReleasePage([AppUpdateInfo? info]) async {
    final uri = info?.releasePageUrl ?? Uri.parse(releasePageUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw StateError('无法打开发布页面：$uri');
    }
  }

  Future<void> runUpdaterSession(
    AppUpdateInstallSession session, {
    required void Function(AppUpdateProgressEvent event) onProgress,
  }) async {
    if (!Platform.isWindows) {
      throw StateError('当前平台暂未实现自动安装。');
    }

    final installer = File(session.installerPath);
    if (!installer.existsSync()) {
      throw StateError('更新安装包不存在：${session.installerPath}');
    }
    final installRoot = Directory(session.installRoot);
    if (!installRoot.existsSync()) {
      throw StateError('安装目录不存在：${session.installRoot}');
    }

    onProgress(
      const AppUpdateProgressEvent(
        stepIndex: 0,
        stepLabel: '准备安装',
        message: '正在准备独立更新器会话...',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    onProgress(
      const AppUpdateProgressEvent(
        stepIndex: 1,
        stepLabel: '关闭旧版本',
        message: '正在等待旧版本退出...',
        substep: '主程序即将关闭，更新窗口会继续完成安装。',
      ),
    );
    await _waitForProcessExit(session.oldProcessId);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    onProgress(
      const AppUpdateProgressEvent(
        stepIndex: 2,
        stepLabel: '安装新版本',
        message: '正在启动静默安装程序...',
        substep: '系统可能会请求管理员权限确认。',
      ),
    );
    final installerExitCode = await _runSilentWindowsInstaller(
      session: session,
      installer: installer,
    );
    if (installerExitCode != 0) {
      onProgress(
        AppUpdateProgressEvent(
          stepIndex: 2,
          stepLabel: '安装新版本',
          message: '安装程序退出码：$installerExitCode',
          substep: '请重新打开 VNTC APP 后在设置页重试。',
          isError: true,
        ),
      );
      return;
    }

    onProgress(
      const AppUpdateProgressEvent(
        stepIndex: 3,
        stepLabel: '启动新版本',
        message: '安装完成，正在启动新版本...',
        substep: '正在等待新版主程序可用。',
      ),
    );
    final appExe = File(
      path.join(
        session.installRoot,
        path.basename(Platform.resolvedExecutable),
      ),
    );
    await _waitForFile(appExe);
    await Future<void>.delayed(
      const Duration(milliseconds: updaterRelaunchDelayMilliseconds),
    );
    await Process.start(
      appExe.path,
      const [],
      mode: ProcessStartMode.detached,
      workingDirectory: session.installRoot,
    );

    onProgress(
      AppUpdateProgressEvent(
        stepIndex: 4,
        stepLabel: '完成',
        message: '已启动 ${session.versionTag}',
        substep: '更新完成。',
        isSuccess: true,
      ),
    );
  }

  Future<String> _resolveCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.trim().isNotEmpty) {
        return info.version.trim();
      }
    } catch (_) {
      // 测试环境或平台通道不可用时回退到编译期版本。
    }
    return AppVersion.currentVersion;
  }

  Future<Map<String, dynamic>> _fetchJson(
    Uri uri, {
    required AppUpdateProxy? proxy,
  }) async {
    final bytes = await _readUri(
      uri,
      proxy: proxy,
      accept: 'application/vnd.github+json',
    );
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('GitHub 返回数据格式不正确');
    }
    return decoded;
  }

  Future<List<int>> _readUri(
    Uri uri, {
    required AppUpdateProxy? proxy,
    required String accept,
  }) async {
    try {
      return await _readUriOnce(uri, proxy: proxy, accept: accept);
    } catch (_) {
      if (proxy == null) {
        rethrow;
      }
      return _readUriOnce(uri, proxy: null, accept: accept);
    }
  }

  Future<List<int>> _readUriOnce(
    Uri uri, {
    required AppUpdateProxy? proxy,
    required String accept,
  }) async {
    final client = _createHttpClient(proxy);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, accept);
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('请求失败：HTTP ${response.statusCode}', uri: uri);
      }
      return consolidateHttpClientResponseBytes(response);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _downloadFile(
    Uri uri,
    File target, {
    required AppUpdateProxy? proxy,
    AppUpdateProgress? onProgress,
  }) async {
    try {
      await _downloadFileOnce(
        uri,
        target,
        proxy: proxy,
        onProgress: onProgress,
      );
    } catch (_) {
      if (proxy == null) {
        rethrow;
      }
      if (await target.exists()) {
        await target.delete();
      }
      await _downloadFileOnce(uri, target, proxy: null, onProgress: onProgress);
    }
  }

  Future<void> _downloadFileOnce(
    Uri uri,
    File target, {
    required AppUpdateProxy? proxy,
    AppUpdateProgress? onProgress,
  }) async {
    final client = _createHttpClient(proxy);
    final sink = target.openWrite();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('下载失败：HTTP ${response.statusCode}', uri: uri);
      }

      final total = response.contentLength < 0 ? 0 : response.contentLength;
      var received = 0;
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
      client.close(force: true);
    }
  }

  HttpClient _createHttpClient(AppUpdateProxy? proxy) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 20)
      ..autoUncompress = true;
    if (proxy != null) {
      client.findProxy = (_) => '${proxy.config}; DIRECT';
    }
    return client;
  }

  Future<Directory> _resolveDownloadDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return getTemporaryDirectory();
    }
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return Directory(path.join(downloads.path, 'VNTC APP Updates'));
    }
    final temp = await getTemporaryDirectory();
    return Directory(path.join(temp.path, 'vnt_app_updates'));
  }

  Future<bool> _launchWindowsUpdater(AppUpdateDownloadResult result) async {
    final installer = File(result.filePath);
    if (!installer.existsSync()) {
      throw StateError('更新安装包不存在：${result.filePath}');
    }

    final appDir = File(Platform.resolvedExecutable).parent.path;
    final sessionId = _safeSessionId(
      'update_${DateTime.now().microsecondsSinceEpoch}',
    );
    final runtime = await _stageUpdaterRuntime(
      sessionId: sessionId,
      sourceRootDir: appDir,
      sourceExecutablePath: Platform.resolvedExecutable,
    );
    final launchedPid = await _processLauncher(
      runtime.executablePath,
      [
        '$updaterSessionArg$sessionId',
        '$updaterVersionArg${result.versionTag}',
        '$updaterInstallerArg${installer.path}',
        '$updaterInstallRootArg$appDir',
        '$updaterOldPidArg$pid',
      ],
      mode: ProcessStartMode.detached,
      runInShell: false,
    );
    return launchedPid > 0;
  }

  Future<_PreparedUpdateRuntime> _stageUpdaterRuntime({
    required String sessionId,
    required String sourceRootDir,
    required String sourceExecutablePath,
  }) async {
    final root = _stagingRootDirectory ?? await _resolveDownloadDirectory();
    final runtimeDir = Directory(
      path.join(root.path, 'staging', '${_safeSessionId(sessionId)}_runtime'),
    );
    if (runtimeDir.existsSync()) {
      await runtimeDir.delete(recursive: true);
    }
    await runtimeDir.create(recursive: true);

    final sourceRoot = Directory(sourceRootDir);
    if (!sourceRoot.existsSync()) {
      throw StateError('更新器源目录不存在：$sourceRootDir');
    }
    await for (final entity in sourceRoot.list(followLinks: false)) {
      final name = path.basename(entity.path);
      if (entity is File) {
        await entity.copy(path.join(runtimeDir.path, name));
        continue;
      }
      if (entity is Directory && name.toLowerCase() == 'data') {
        await _copyFlutterRuntimeData(
          entity,
          Directory(path.join(runtimeDir.path, name)),
        );
      }
    }

    final executablePath = path.join(
      runtimeDir.path,
      path.basename(sourceExecutablePath),
    );
    if (!File(executablePath).existsSync()) {
      throw StateError('临时更新器主程序不存在：$executablePath');
    }
    return _PreparedUpdateRuntime(
      runtimeDir: runtimeDir.path,
      executablePath: executablePath,
    );
  }

  Future<void> _copyFlutterRuntimeData(
    Directory source,
    Directory target,
  ) async {
    if (!target.existsSync()) {
      await target.create(recursive: true);
    }
    for (final fileName in ['app.so', 'icudtl.dat']) {
      final file = File(path.join(source.path, fileName));
      if (file.existsSync()) {
        await file.copy(path.join(target.path, fileName));
      }
    }
    final flutterAssets = Directory(path.join(source.path, 'flutter_assets'));
    if (flutterAssets.existsSync()) {
      await _copyDirectoryRecursively(
        flutterAssets,
        Directory(path.join(target.path, 'flutter_assets')),
      );
    }
  }

  Future<void> _copyDirectoryRecursively(
    Directory source,
    Directory target,
  ) async {
    if (!target.existsSync()) {
      await target.create(recursive: true);
    }
    await for (final entity in source.list(followLinks: false)) {
      final targetPath = path.join(target.path, path.basename(entity.path));
      if (entity is File) {
        await entity.copy(targetPath);
        continue;
      }
      if (entity is Directory) {
        await _copyDirectoryRecursively(entity, Directory(targetPath));
      }
    }
  }

  Future<int> _runSilentWindowsInstaller({
    required AppUpdateInstallSession session,
    required File installer,
  }) async {
    final updatesRoot = await _resolveDownloadDirectory();
    if (!updatesRoot.existsSync()) {
      await updatesRoot.create(recursive: true);
    }
    final sessionRoot = Directory(
      path.join(
        updatesRoot.path,
        'sessions',
        _safeSessionId(session.sessionId),
      ),
    );
    if (!sessionRoot.existsSync()) {
      await sessionRoot.create(recursive: true);
    }
    final logPath = path.join(sessionRoot.path, 'installer.log');
    final scriptLogPath = path.join(sessionRoot.path, 'updater.log');
    final scriptFile = File(path.join(sessionRoot.path, 'install-update.ps1'));
    final scriptLines = [
      r"$ErrorActionPreference = 'Stop'",
      '\$installerPath = ${_toPowerShellLiteral(installer.path)}',
      '\$appDir = ${_toPowerShellLiteral(session.installRoot)}',
      '\$installerLogPath = ${_toPowerShellLiteral(logPath)}',
      '\$scriptLogPath = ${_toPowerShellLiteral(scriptLogPath)}',
      r'function Write-UpdateLog([string]$message) {',
      r"    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'",
      r"    Add-Content -LiteralPath $scriptLogPath -Value ($timestamp + ' ' + $message) -Encoding UTF8",
      r'}',
      r'try {',
      "    Write-UpdateLog '可视化更新器开始静默安装，目标版本：${session.versionTag}'",
      r'    $installerArgs = @(',
      r"        '/SP-',",
      r"        '/VERYSILENT',",
      r"        '/SUPPRESSMSGBOXES',",
      r"        '/NORESTART',",
      r"        '/NOCANCEL',",
      r"        '/CLOSEAPPLICATIONS',",
      r"        '/FORCECLOSEAPPLICATIONS',",
      r'        "/DIR=`"$appDir`"",',
      r'        "/LOG=`"$installerLogPath`""',
      r'    )',
      r'    $process = Start-Process -FilePath $installerPath -ArgumentList $installerArgs -Verb RunAs -Wait -PassThru',
      r"    Write-UpdateLog ('安装进程已结束，ExitCode=' + $process.ExitCode)",
      r'    exit $process.ExitCode',
      r'} catch {',
      r"    Write-UpdateLog ('安装脚本失败：' + $_.Exception.Message)",
      r'    exit 1',
      r'}',
    ];
    await scriptFile.writeAsBytes([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(scriptLines.join('\r\n')),
    ]);
    final process = await Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        scriptFile.path,
      ],
      mode: ProcessStartMode.normal,
      runInShell: false,
    );
    return process.exitCode;
  }

  Future<void> _waitForProcessExit(int processId) async {
    if (processId <= 0 || processId == pid) {
      return;
    }
    final deadline = DateTime.now().add(const Duration(seconds: 120));
    while (DateTime.now().isBefore(deadline)) {
      if (!await _processExists(processId)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<bool> _processExists(int processId) async {
    try {
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-Command',
          'if (Get-Process -Id $processId -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }',
        ],
        stdoutEncoding: utf8,
        stderrEncoding: systemEncoding,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _waitForFile(File file) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      if (file.existsSync()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  static const _userAgent = 'VNTC-APP-Updater/2.0';

  static String _toPowerShellLiteral(String value) {
    return "'${value.replaceAll("'", "''")}'";
  }

  static String? _argumentValue(List<String> args, String prefix) {
    for (final arg in args) {
      if (arg.startsWith(prefix)) {
        return arg.substring(prefix.length);
      }
    }
    return null;
  }

  static String _safeSessionId(String value) {
    return value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');
  }
}

class _PreparedUpdateRuntime {
  const _PreparedUpdateRuntime({
    required this.runtimeDir,
    required this.executablePath,
  });

  final String runtimeDir;
  final String executablePath;
}

Future<int> _defaultProcessLauncher(
  String executable,
  List<String> arguments, {
  ProcessStartMode mode = ProcessStartMode.normal,
  bool runInShell = false,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    mode: mode,
    runInShell: runInShell,
  );
  return process.pid;
}

class AndroidUpdateInstaller {
  static const MethodChannel _channel = MethodChannel(
    'top.wherewego.vnt/update',
  );

  static Future<void> installApk(String filePath) async {
    await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
  }
}

class AppUpdateProxyResolver {
  static const proxyHost = String.fromEnvironment(
    'APP_UPDATE_PROXY_HOST',
    defaultValue: '',
  );
  static const proxyPort = int.fromEnvironment(
    'APP_UPDATE_PROXY_PORT',
    defaultValue: 7890,
  );

  static Future<AppUpdateProxy?> resolve() async {
    final envProxy = _fromEnvironment();
    if (envProxy != null) {
      return envProxy;
    }

    if (!kIsWeb) {
      final systemProxy = await _fromSystemProxy();
      if (systemProxy != null) {
        return systemProxy;
      }
    }

    return _fromReachableLocalProxy();
  }

  static AppUpdateProxy? parseProxyValue(String value, String source) {
    final trimmed = value.trim().replaceAll('"', '');
    if (trimmed.isEmpty || trimmed.toUpperCase() == 'DIRECT') {
      return null;
    }

    if (trimmed.contains('=') && trimmed.contains(';')) {
      final selected = _selectProxyServerValue(trimmed);
      if (selected != null) {
        return parseProxyValue(selected, source);
      }
    }

    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty || uri.port == 0) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();
    final command = scheme.startsWith('socks') ? 'SOCKS' : 'PROXY';
    return AppUpdateProxy(
      config: '$command ${uri.host}:${uri.port}',
      label: '$source ${uri.host}:${uri.port}',
    );
  }

  static AppUpdateProxy? _fromEnvironment() {
    for (final key in const [
      'HTTPS_PROXY',
      'https_proxy',
      'ALL_PROXY',
      'all_proxy',
      'HTTP_PROXY',
      'http_proxy',
    ]) {
      final value = Platform.environment[key];
      if (value == null) {
        continue;
      }
      final proxy = parseProxyValue(value, '环境代理');
      if (proxy != null) {
        return proxy;
      }
    }
    return null;
  }

  static Future<AppUpdateProxy?> _fromSystemProxy() async {
    if (Platform.isMacOS) {
      return _fromMacOSProxy();
    }
    if (Platform.isWindows) {
      return _fromWindowsProxy();
    }
    if (Platform.isLinux) {
      return _fromLinuxProxy();
    }
    return null;
  }

  static Future<AppUpdateProxy?> _fromMacOSProxy() async {
    final result = await _runProcess('scutil', ['--proxy']);
    if (result == null || result.exitCode != 0) {
      return null;
    }
    final output = result.stdout.toString();
    final httpsEnabled = _macProxyValue(output, 'HTTPSEnable') == '1';
    final httpEnabled = _macProxyValue(output, 'HTTPEnable') == '1';
    if (httpsEnabled) {
      final host = _macProxyValue(output, 'HTTPSProxy');
      final port = _macProxyValue(output, 'HTTPSPort');
      final proxy = parseProxyValue('$host:$port', 'macOS 系统代理');
      if (proxy != null) {
        return proxy;
      }
    }
    if (httpEnabled) {
      final host = _macProxyValue(output, 'HTTPProxy');
      final port = _macProxyValue(output, 'HTTPPort');
      return parseProxyValue('$host:$port', 'macOS 系统代理');
    }
    return null;
  }

  static Future<AppUpdateProxy?> _fromWindowsProxy() async {
    final result = await _runProcess('reg', [
      'query',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
    ]);
    if (result == null || result.exitCode != 0) {
      return null;
    }
    final output = result.stdout.toString();
    final enabled = RegExp(
      r'ProxyEnable\s+REG_DWORD\s+0x1',
      caseSensitive: false,
    ).hasMatch(output);
    if (!enabled) {
      return null;
    }
    final match = RegExp(
      r'ProxyServer\s+REG_SZ\s+(.+)',
      caseSensitive: false,
    ).firstMatch(output);
    if (match == null) {
      return null;
    }
    return parseProxyValue(match.group(1) ?? '', 'Windows 系统代理');
  }

  static Future<AppUpdateProxy?> _fromLinuxProxy() async {
    final mode = await _runProcess('gsettings', [
      'get',
      'org.gnome.system.proxy',
      'mode',
    ]);
    if (mode == null ||
        mode.exitCode != 0 ||
        !mode.stdout.toString().contains('manual')) {
      return null;
    }
    final httpsHost = await _linuxGSettingsValue(
      'org.gnome.system.proxy.https',
      'host',
    );
    final httpsPort = await _linuxGSettingsValue(
      'org.gnome.system.proxy.https',
      'port',
    );
    final httpsProxy = parseProxyValue('$httpsHost:$httpsPort', 'Linux 系统代理');
    if (httpsProxy != null) {
      return httpsProxy;
    }
    final httpHost = await _linuxGSettingsValue(
      'org.gnome.system.proxy.http',
      'host',
    );
    final httpPort = await _linuxGSettingsValue(
      'org.gnome.system.proxy.http',
      'port',
    );
    return parseProxyValue('$httpHost:$httpPort', 'Linux 系统代理');
  }

  static Future<AppUpdateProxy?> _fromReachableLocalProxy() async {
    final hosts = <String>[
      if (proxyHost.trim().isNotEmpty) proxyHost.trim(),
      '127.0.0.1',
      'localhost',
      if (Platform.isAndroid) '10.0.2.2',
    ];
    for (final host in hosts) {
      if (await _canConnect(host, proxyPort)) {
        return AppUpdateProxy(
          config: 'PROXY $host:$proxyPort',
          label: '本机代理 $host:$proxyPort',
        );
      }
    }
    return null;
  }

  static Future<ProcessResult?> _runProcess(
    String executable,
    List<String> arguments,
  ) async {
    try {
      return await Process.run(
        executable,
        arguments,
      ).timeout(const Duration(seconds: 2));
    } catch (_) {
      return null;
    }
  }

  static String? _selectProxyServerValue(String value) {
    final parts = value.split(';').map((item) => item.trim());
    for (final key in const ['https=', 'http=', 'socks=']) {
      for (final part in parts) {
        if (part.toLowerCase().startsWith(key)) {
          final selected = part.substring(key.length);
          if (selected.isNotEmpty) {
            return selected;
          }
        }
      }
    }
    return null;
  }

  static String _macProxyValue(String output, String key) {
    final match = RegExp('$key\\s*:\\s*(.+)').firstMatch(output);
    return match?.group(1)?.trim() ?? '';
  }

  static Future<String> _linuxGSettingsValue(String schema, String key) async {
    final result = await _runProcess('gsettings', ['get', schema, key]);
    if (result == null || result.exitCode != 0) {
      return '';
    }
    return result.stdout.toString().trim().replaceAll("'", '');
  }

  static Future<bool> _canConnect(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 350),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}

AppUpdatePlatform resolveCurrentUpdatePlatform() {
  if (kIsWeb) {
    return AppUpdatePlatform.unsupported;
  }
  if (Platform.isAndroid) {
    return AppUpdatePlatform.android;
  }
  if (Platform.isWindows) {
    return AppUpdatePlatform.windows;
  }
  if (Platform.isMacOS) {
    return AppUpdatePlatform.macos;
  }
  if (Platform.isLinux) {
    return AppUpdatePlatform.linux;
  }
  if (Platform.isIOS) {
    return AppUpdatePlatform.ios;
  }
  return AppUpdatePlatform.unsupported;
}

AppUpdateInfo parseGitHubRelease(
  Map<String, dynamic> release, {
  required String currentVersion,
  required AppUpdatePlatform platform,
  String? proxyLabel,
}) {
  final tagName = (release['tag_name'] ?? '').toString();
  if (tagName.isEmpty) {
    throw const FormatException('GitHub Release 缺少 tag_name');
  }
  final latestVersion = normalizeVersionString(tagName);
  final pageUrl =
      Uri.tryParse((release['html_url'] ?? '').toString()) ??
      Uri.parse(AppUpdateService.releasePageUrl);
  final rawAssets = release['assets'];
  final assets = rawAssets is List
      ? rawAssets
            .whereType<Map<String, dynamic>>()
            .map(AppUpdateAsset.fromGitHubJson)
            .whereType<AppUpdateAsset>()
            .toList()
      : <AppUpdateAsset>[];

  return AppUpdateInfo(
    currentVersion: normalizeVersionString(currentVersion),
    latestVersion: latestVersion,
    tagName: tagName,
    releaseName: (release['name'] ?? tagName).toString(),
    releaseNotes: (release['body'] ?? '').toString(),
    releasePageUrl: pageUrl,
    hasUpdate: compareVersionStrings(latestVersion, currentVersion) > 0,
    platform: platform,
    asset: selectBestUpdateAsset(assets, platform),
    proxyLabel: proxyLabel,
  );
}

AppUpdateAsset? selectBestUpdateAsset(
  List<AppUpdateAsset> assets,
  AppUpdatePlatform platform,
) {
  if (platform == AppUpdatePlatform.ios) {
    return null;
  }

  final patterns = switch (platform) {
    AppUpdatePlatform.android => ['.apk'],
    AppUpdatePlatform.windows => ['setup.exe', '.msi', '.exe', '.zip'],
    AppUpdatePlatform.macos => ['.dmg'],
    AppUpdatePlatform.linux => ['.appimage', '.deb', '.tar.gz'],
    AppUpdatePlatform.ios => const <String>[],
    AppUpdatePlatform.unsupported => const <String>[],
  };

  for (final pattern in patterns) {
    for (final asset in assets) {
      if (asset.name.toLowerCase().contains(pattern)) {
        return asset;
      }
    }
  }
  return null;
}

int compareVersionStrings(String left, String right) {
  final leftVersion = normalizeVersionString(left);
  final rightVersion = normalizeVersionString(right);
  final leftParts = _numericVersionParts(leftVersion);
  final rightParts = _numericVersionParts(rightVersion);
  final maxLength = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;

  for (var index = 0; index < maxLength; index++) {
    final leftPart = index < leftParts.length ? leftParts[index] : 0;
    final rightPart = index < rightParts.length ? rightParts[index] : 0;
    if (leftPart != rightPart) {
      return leftPart.compareTo(rightPart);
    }
  }

  final leftPrerelease = leftVersion.contains('-');
  final rightPrerelease = rightVersion.contains('-');
  if (leftPrerelease == rightPrerelease) {
    return 0;
  }
  return leftPrerelease ? -1 : 1;
}

String normalizeVersionString(String version) {
  var normalized = version.trim();
  if (normalized.startsWith('refs/tags/')) {
    normalized = normalized.substring('refs/tags/'.length);
  }
  if (normalized.startsWith('v') || normalized.startsWith('V')) {
    normalized = normalized.substring(1);
  }
  final plusIndex = normalized.indexOf('+');
  if (plusIndex >= 0) {
    normalized = normalized.substring(0, plusIndex);
  }
  return normalized.isEmpty ? '0.0.0' : normalized;
}

String normalizeUpdateVersionTag(String version) {
  final normalized = normalizeVersionString(version);
  if (normalized == '0.0.0') {
    return '';
  }
  return 'v$normalized';
}

List<int> _numericVersionParts(String version) {
  final firstSection = version.split('-').first;
  return RegExp(r'\d+')
      .allMatches(firstSection)
      .map((match) => int.tryParse(match.group(0) ?? '') ?? 0)
      .toList();
}

String _safeFileName(String fileName) {
  return fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
