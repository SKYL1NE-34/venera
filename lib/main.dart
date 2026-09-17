import 'dart:async';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/pages/auth_page.dart';
import 'package:venera/pages/main_page.dart';
import 'package:venera/pages/splash_page.dart';
import 'package:venera/utils/io.dart';
import 'package:window_manager/window_manager.dart';
import 'components/components.dart';
import 'components/window_frame.dart';
import 'foundation/app.dart';
import 'foundation/appdata.dart';
import 'headless.dart';
import 'init.dart';

void main(List<String> args) {
  if (args.contains('--headless')) {
    runHeadlessMode(args);
    return;
  }
  if (runWebViewTitleBarWidget(args)) return;
  overrideIO(() {
    runZonedGuarded(() async {
      WidgetsFlutterBinding.ensureInitialized();
      if (App.isAndroid) {
        // Mount the app immediately and run [init] in the background while the
        // splash overlay is shown. This keeps the first frame fast and avoids
        // showing the native (white/black) window background for long.
        runApp(const MyApp(bootstrap: true));
      } else {
        await init();
        runApp(const MyApp());
      }
      if (App.isDesktop) {
        await windowManager.ensureInitialized();
        windowManager.waitUntilReadyToShow().then((_) async {
          await windowManager.setTitleBarStyle(
            TitleBarStyle.hidden,
            windowButtonVisibility: App.isMacOS,
          );
          if (App.isLinux) {
            await windowManager.setBackgroundColor(Colors.transparent);
          }
          await windowManager.setMinimumSize(const Size(500, 600));
          var placement = await WindowPlacement.loadFromFile();
          if (App.isLinux) {
            await windowManager.show();
            await placement.applyToWindow();
          } else {
            await placement.applyToWindow();
            await windowManager.show();
          }

          WindowPlacement.loop();
        });
      }
    }, (error, stack) {
      Log.error("Unhandled Exception", error, stack);
    });
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.bootstrap = false});

  /// Whether the app was mounted before [init] finished. When true a splash
  /// overlay is shown until initialization completes.
  final bool bootstrap;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Drives the home content. [MaterialApp.home] is cached by the navigator, so
  /// the switch from the bootstrap placeholder to the real home page must be
  /// driven by a listenable owned by a stable widget instead of rebuilding the
  /// `home` property.
  final ValueNotifier<bool> _readyNotifier = ValueNotifier(false);

  /// How long the fully written name is held on screen before fading out.
  /// Measured from the moment the writing animation completes so a slow
  /// [init] does not add extra waiting time.
  static const Duration _splashHoldDuration = Duration(milliseconds: 400);

  bool _splashVisible = false;

  double _splashOpacity = 1;

  bool _holdDone = false;

  Timer? _splashHoldTimer;

  late final AnimationController _splashController;

  @override
  void initState() {
    _readyNotifier.value = !widget.bootstrap;
    App.registerForceRebuild(forceRebuild);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.addObserver(this);
    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener(_onSplashAnimationStatus);
    if (widget.bootstrap) {
      _splashVisible = true;
      _splashController.forward();
      _bootstrap();
    } else {
      checkUpdates();
    }
    super.initState();
  }

  @override
  void dispose() {
    _splashHoldTimer?.cancel();
    _splashController.dispose();
    _readyNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Run the heavy initialization while the splash overlay is visible.
  ///
  /// Errors and a timeout are swallowed so the app still proceeds to the home
  /// page instead of being stuck on the splash forever.
  Future<void> _bootstrap() async {
    try {
      await init().timeout(const Duration(seconds: 10));
    } catch (e, s) {
      Log.error("init", "$e\n$s");
    }
    if (!mounted) return;
    setState(() {});
    _readyNotifier.value = true;
    checkUpdates();
    _maybeFinishSplash();
  }

  void _onSplashAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _splashHoldTimer = Timer(_splashHoldDuration, () {
        if (!mounted) return;
        _holdDone = true;
        _maybeFinishSplash();
      });
    }
  }

  void _maybeFinishSplash() {
    if (!_splashVisible ||
        !_readyNotifier.value ||
        !_holdDone ||
        !_splashController.isCompleted) {
      return;
    }
    setState(() => _splashOpacity = 0);
  }

  void _onSplashFadeEnd() {
    if (_splashOpacity == 0 && _splashVisible && mounted) {
      setState(() => _splashVisible = false);
    }
  }

  bool isAuthPageActive = false;

  OverlayEntry? hideContentOverlay;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!App.isMobile || !appdata.settings['authorizationRequired']) {
      return;
    }
    if (state == AppLifecycleState.inactive && hideContentOverlay == null) {
      hideContentOverlay = OverlayEntry(
        builder: (context) {
          return Positioned.fill(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: App.rootContext.colorScheme.surface,
            ),
          );
        },
      );
      Overlay.of(App.rootContext).insert(hideContentOverlay!);
    } else if (hideContentOverlay != null &&
        state == AppLifecycleState.resumed) {
      hideContentOverlay!.remove();
      hideContentOverlay = null;
    }
    if (state == AppLifecycleState.hidden &&
        !isAuthPageActive &&
        !IO.isSelectingFiles) {
      isAuthPageActive = true;
      App.rootContext.to(
        () => AuthPage(
          onSuccessfulAuth: () {
            App.rootContext.pop();
            isAuthPageActive = false;
          },
        ),
      );
    }
    super.didChangeAppLifecycleState(state);
  }

  void forceRebuild() {
    void rebuild(Element el) {
      el.markNeedsBuild();
      el.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
    setState(() {});
  }

  Color translateColorSetting() {
    return switch (appdata.settings['color']) {
      'red' => Colors.red,
      'pink' => Colors.pink,
      'purple' => Colors.purple,
      'green' => Colors.green,
      'orange' => Colors.orange,
      'blue' => Colors.blue,
      'yellow' => Colors.yellow,
      'cyan' => Colors.cyan,
      _ => Colors.blue,
    };
  }

  ThemeData getTheme(
    Color primary,
    Color? secondary,
    Color? tertiary,
    Brightness brightness,
  ) {
    String? font;
    List<String>? fallback;
    if (App.isLinux || App.isWindows) {
      font = 'Noto Sans CJK';
      fallback = [
        'Segoe UI',
        'Noto Sans SC',
        'Noto Sans TC',
        'Noto Sans',
        'Microsoft YaHei',
        'PingFang SC',
        'Arial',
        'sans-serif'
      ];
    }
    return ThemeData(
      colorScheme: SeedColorScheme.fromSeeds(
        primaryKey: primary,
        secondaryKey: secondary,
        tertiaryKey: tertiary,
        brightness: brightness,
        tones: FlexTones.vividBackground(brightness),
      ),
      fontFamily: font,
      fontFamilyFallback: fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (light, dark) {
      Color? primary, secondary, tertiary;
      if (appdata.settings['color'] != 'system' ||
          light == null ||
          dark == null) {
        primary = translateColorSetting();
      } else {
        primary = light.primary;
        secondary = light.secondary;
        tertiary = light.tertiary;
      }
      return MaterialApp(
        title: "venera",
        home: _BootstrapGate(readyListenable: _readyNotifier),
        debugShowCheckedModeBanner: false,
        theme: getTheme(primary, secondary, tertiary, Brightness.light),
        navigatorKey: App.rootNavigatorKey,
        darkTheme: getTheme(primary, secondary, tertiary, Brightness.dark),
        themeMode: switch (appdata.settings['theme_mode']) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system
        },
        color: Colors.transparent,
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: () {
          var lang = appdata.settings['language'];
          if (lang == 'system') {
            return null;
          }
          return switch (lang) {
            'zh-CN' => const Locale('zh', 'CN'),
            'zh-TW' => const Locale('zh', 'TW'),
            'en-US' => const Locale('en'),
            _ => null
          };
        }(),
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('zh', 'TW'),
          Locale('en'),
        ],
        builder: (context, widget) {
          ErrorWidget.builder = (details) {
            Log.error("Unhandled Exception",
                "${details.exception}\n${details.stack}");
            return Material(
              child: Center(
                child: Text(details.exception.toString()),
              ),
            );
          };
          if (widget != null) {
            /// 如果无法检测到状态栏高度设定指定高度
            /// https://github.com/flutter/flutter/issues/161086
            var isPaddingCheckError =
                MediaQuery.of(context).viewPadding.top <= 0 ||
                MediaQuery.of(context).viewPadding.top > 200;

            if (isPaddingCheckError && Platform.isAndroid) {
              widget = MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    viewPadding: const EdgeInsets.only(
                      top: 15,
                      bottom: 15,
                    ),
                    padding: const EdgeInsets.only(
                      top: 15,
                      bottom: 15,
                    ),
                  ),
                  child: widget);
            }

            widget = OverlayWidget(widget);
            if (App.isDesktop) {
              widget = Shortcuts(
                shortcuts: {
                  LogicalKeySet(LogicalKeyboardKey.escape): VoidCallbackIntent(
                    App.pop,
                  ),
                },
                child: MouseBackDetector(
                  onTapDown: App.pop,
                  child: WindowFrame(widget),
                ),
              );
            }
            if (_splashVisible) {
              var theme = Theme.of(context);
              widget = Stack(
                children: [
                  widget,
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _splashOpacity,
                      duration: const Duration(milliseconds: 300),
                      onEnd: _onSplashFadeEnd,
                      child: SplashOverlay(
                        animation: _splashController,
                        background: theme.brightness == Brightness.dark
                            ? const Color(0xFF121212)
                            : const Color(0xFFFAFAFA),
                        textColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              );
            }
            return _SystemUiProvider(Material(
              color: App.isLinux ? Colors.transparent : null,
              child: widget,
            ));
          }
          throw ('widget is null');
        },
      );
    });
  }
}

/// Switches the app home between a placeholder (while bootstrapping) and the
/// real home page, driven by a [ValueListenable].
///
/// [MaterialApp.home] is only built once by the navigator, so this must be a
/// stable widget that listens to [readyListenable] instead of rebuilding the
/// `home` property.
class _BootstrapGate extends StatelessWidget {
  const _BootstrapGate({required this.readyListenable});

  final ValueListenable<bool> readyListenable;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: readyListenable,
      builder: (context, ready, _) {
        if (!ready) {
          return const SizedBox.shrink();
        }
        if (appdata.settings['authorizationRequired']) {
          return AuthPage(
            onSuccessfulAuth: () {
              App.rootContext.toReplacement(() => const MainPage());
            },
          );
        }
        return const MainPage();
      },
    );
  }
}

class _SystemUiProvider extends StatelessWidget {
  const _SystemUiProvider(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    var brightness = Theme.of(context).brightness;
    SystemUiOverlayStyle systemUiStyle;
    if (brightness == Brightness.light) {
      systemUiStyle = SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      );
    } else {
      systemUiStyle = SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: child,
    );
  }
}
