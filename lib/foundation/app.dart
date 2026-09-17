import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:venera/foundation/history.dart';

import 'appdata.dart';
import 'favorites.dart';
import 'local.dart';

export "widget_utils.dart";
export "context.dart";

class _App {
  /// Version name of the installed app. Filled from the platform package info
  /// during [init]. The initial value is only a fallback.
  String version = "1.6.7";

  /// Build number of the installed app (the part after `+` in pubspec).
  String buildNumber = "";

  bool get isAndroid => Platform.isAndroid;

  bool get isIOS => Platform.isIOS;

  bool get isWindows => Platform.isWindows;

  bool get isLinux => Platform.isLinux;

  bool get isMacOS => Platform.isMacOS;

  bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool get isMobile => Platform.isAndroid || Platform.isIOS;

  // Whether the app has been initialized.
  // If current Isolate is main Isolate, this value is always true.
  bool isInitialized = false;

  Locale get locale {
    Locale deviceLocale = PlatformDispatcher.instance.locale;
    if (deviceLocale.languageCode == "zh" &&
        deviceLocale.scriptCode == "Hant") {
      deviceLocale = const Locale("zh", "TW");
    }
    if (appdata.settings['language'] != 'system') {
      return Locale(
        appdata.settings['language'].split('-')[0],
        appdata.settings['language'].split('-')[1],
      );
    }
    return deviceLocale;
  }

  late String dataPath;
  late String cachePath;
  String? externalStoragePath;

  final rootNavigatorKey = GlobalKey<NavigatorState>();

  GlobalKey<NavigatorState>? mainNavigatorKey;

  BuildContext get rootContext => rootNavigatorKey.currentContext!;

  final Appdata data = appdata;

  final HistoryManager history = HistoryManager();

  final LocalFavoritesManager favorites = LocalFavoritesManager();

  final LocalManager local = LocalManager();

  void rootPop() {
    rootNavigatorKey.currentState?.maybePop();
  }

  void pop() {
    if (rootNavigatorKey.currentState?.canPop() ?? false) {
      rootNavigatorKey.currentState?.pop();
    } else if (mainNavigatorKey?.currentState?.canPop() ?? false) {
      mainNavigatorKey?.currentState?.pop();
    }
  }

  Future<void> init() async {
    cachePath = (await getApplicationCacheDirectory()).path;
    dataPath = (await getApplicationSupportDirectory()).path;
    if (isAndroid) {
      externalStoragePath = (await getExternalStorageDirectory())!.path;
    }
    try {
      var info = await PackageInfo.fromPlatform();
      version = info.version;
      buildNumber = info.buildNumber;
    } catch (e) {
      debugPrint("Failed to read package info: $e");
    }
    isInitialized = true;
  }

  Future<void> initComponents() async {
    await Future.wait([
      data.init(),
      history.init(),
      favorites.init(),
      local.init(),
    ]);
  }

  /// Wait until the main navigator (the home page) is mounted.
  ///
  /// Used by deep link / text share handlers that may fire while the app is
  /// still bootstrapping and the home page is not available yet. Returns false
  /// if it is still unavailable after [timeout].
  Future<bool> waitForMainNavigator({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    var end = DateTime.now().add(timeout);
    while (mainNavigatorKey?.currentContext == null) {
      if (DateTime.now().isAfter(end)) {
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return true;
  }

  Function? _forceRebuildHandler;

  void registerForceRebuild(Function handler) {
    _forceRebuildHandler = handler;
  }

  void forceRebuild() {
    _forceRebuildHandler?.call();
  }
}

// ignore: non_constant_identifier_names
final App = _App();
