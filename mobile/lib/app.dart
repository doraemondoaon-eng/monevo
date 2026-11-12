import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/security/app_lock_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/settings_controller.dart';
import 'l10n/app_strings.dart';

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class MonevoApp extends ConsumerStatefulWidget {
  const MonevoApp({super.key});

  @override
  ConsumerState<MonevoApp> createState() => _MonevoAppState();
}

class _MonevoAppState extends ConsumerState<MonevoApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: () {
        ref.read(appLockControllerProvider.notifier).onAppBackgrounded();
      },
      onResume: () {
        ref.read(appLockControllerProvider.notifier).onAppResumed();
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = ref.watch(appRouterProvider);
    final AppSettingsState settings = ref.watch(settingsControllerProvider);

    return MaterialApp.router(
      title: 'MONEVO',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AppScrollBehavior(),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: Locale(settings.language.code),
      supportedLocales: const <Locale>[
        Locale('th'),
        Locale('en'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData mediaQuery = MediaQuery.of(context);
        final TextScaler clampedScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.30,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedScaler),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              final FocusScopeNode currentFocus = FocusScope.of(context);
              if (!currentFocus.hasPrimaryFocus &&
                  currentFocus.focusedChild != null) {
                FocusManager.instance.primaryFocus?.unfocus();
              }
            },
            child: InheritedAppStrings(
              strings: settings.strings,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
