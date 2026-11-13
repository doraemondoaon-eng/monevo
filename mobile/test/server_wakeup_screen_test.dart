import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monevo/core/storage/secure_storage_service.dart';
import 'package:monevo/core/theme/app_theme.dart';
import 'package:monevo/features/auth/data/auth_api.dart';
import 'package:monevo/features/auth/data/auth_repository.dart';
import 'package:monevo/features/auth/domain/auth_models.dart';
import 'package:monevo/features/auth/presentation/auth_controller.dart';
import 'package:monevo/features/auth/presentation/server_wakeup_screen.dart';
import 'package:monevo/features/settings/presentation/settings_controller.dart';
import 'package:monevo/l10n/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecureStorage implements SecureStorageService {
  @override
  Future<void> clearPin() async {}

  @override
  Future<void> clearTokens() async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getPinHash() async => null;

  @override
  Future<String?> getPinSalt() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> savePinHash({required String hash, required String salt}) async {}

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}
}

class _StubAuthRepository extends AuthRepository {
  _StubAuthRepository({
    this.registrationOpen = true,
  }) : super(
          api: AuthApi(Dio()),
          secureStorage: _MemorySecureStorage(),
        );

  final bool registrationOpen;

  @override
  Future<HealthStatus> checkHealth() async => const HealthStatus(
        status: 'ok',
        uptime: 10,
        version: '1.0.0',
      );

  @override
  Future<AuthStatus> getStatus() async =>
      AuthStatus(registrationOpen: registrationOpen);

  @override
  Future<User?> restoreSession() async => null;
}

class _TestAuthController extends AuthController {
  _TestAuthController(AuthState initial)
      : super(_StubAuthRepository(), autoBootstrap: false) {
    state = initial;
  }

  int bootstrapCalls = 0;

  @override
  Future<void> bootstrap() async {
    bootstrapCalls += 1;
  }
}

Widget _buildTestHarness({
  required _TestAuthController authController,
}) {
  return ProviderScope(
    overrides: <Override>[
      authControllerProvider.overrideWith((Ref ref) => authController),
    ],
    child: Consumer(
      builder: (BuildContext context, WidgetRef ref, _) {
        final AppSettingsState settings = ref.watch(settingsControllerProvider);
        return MaterialApp(
          theme: AppTheme.light(),
          locale: Locale(settings.language.code),
          supportedLocales: const <Locale>[Locale('th'), Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (BuildContext context, Widget? child) {
            return InheritedAppStrings(
              strings: settings.strings,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const ServerWakeupScreen(),
        );
      },
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'renders branded splash icon, MONEVO wordmark, and minimal loader cleanly at 360x800',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final _TestAuthController authController = _TestAuthController(
        const AuthState(
          stage: AuthStage.wakingServer,
          wakeupAttempt: 1,
          wakeupElapsedSeconds: 0,
        ),
      );

      await tester.pumpWidget(_buildTestHarness(authController: authController));
      // Advance entrance choreography without waiting on the infinite ambient loop.
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('MONEVO'), findsOneWidget);
      expect(find.text('MANAGE • SAVE • GROW'), findsOneWidget);
      expect(
        find.text('กำลังเตรียมพื้นที่ทางการเงินของคุณ...'),
        findsOneWidget,
      );
      expect(find.text('ลองอีกครั้ง'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reveals cold-start status card with attempt, elapsed time, and working retry button',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final _TestAuthController authController = _TestAuthController(
        const AuthState(
          stage: AuthStage.wakingServer,
          wakeupAttempt: 3,
          wakeupElapsedSeconds: 18,
        ),
      );

      await tester.pumpWidget(_buildTestHarness(authController: authController));
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.text('กำลังเชื่อมต่อเซิร์ฟเวอร์ MONEVO...'), findsOneWidget);
      expect(find.text('กำลังลองเชื่อมต่อครั้งที่ 3'), findsOneWidget);
      expect(find.text('เวลาที่รอ: 18 วินาที'), findsOneWidget);

      await tester.tap(find.text('ลองอีกครั้ง'));
      await tester.pump();
      expect(authController.bootstrapCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'language toggle switches splash copy between Thai and English',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final _TestAuthController authController = _TestAuthController(
        const AuthState(stage: AuthStage.wakingServer),
      );

      await tester.pumpWidget(_buildTestHarness(authController: authController));
      await tester.pump(const Duration(milliseconds: 1200));

      await tester.tap(find.text('EN'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Preparing your financial workspace...'), findsOneWidget);
      expect(find.text('ไทย'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'AuthController holds initial splash stage for minSplashDuration before advancing',
    () async {
      final AuthController controller = AuthController(
        _StubAuthRepository(registrationOpen: true),
        autoBootstrap: false,
        minSplashDuration: const Duration(milliseconds: 80),
      );

      final Future<void> bootstrapFuture = controller.bootstrap();
      expect(controller.state.stage, AuthStage.wakingServer);

      await bootstrapFuture;
      expect(controller.state.stage, AuthStage.needsSetup);
      controller.dispose();
    },
  );
}
