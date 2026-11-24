import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zgltvpn/core/api/api_client.dart';
import 'package:zgltvpn/core/api/api_exception.dart';
import 'package:zgltvpn/core/api/auth_api.dart';
import 'package:zgltvpn/core/api/catalog_api.dart';
import 'package:zgltvpn/core/api/subscription_api.dart';
import 'package:zgltvpn/core/config/template_loader.dart';
import 'package:zgltvpn/core/models/node.dart';
import 'package:zgltvpn/core/models/plan.dart';
import 'package:zgltvpn/core/models/user.dart';
import 'package:zgltvpn/core/providers.dart';
import 'package:zgltvpn/core/storage/secure_storage.dart';
import 'package:zgltvpn/features/auth/auth_controller.dart';
import 'package:zgltvpn/features/account/account_page.dart';
import 'package:zgltvpn/features/connection/home_controller.dart';

class FakeSecureStorage extends SecureStorage {
  String? token;
  String? subToken;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<String?> readSubToken() async => subToken;

  @override
  Future<void> saveSession({
    required String token,
    required String subToken,
  }) async {
    this.token = token;
    this.subToken = subToken;
  }

  @override
  Future<void> clearSession() async {
    token = null;
    subToken = null;
  }
}

class FakeAuthApi extends AuthApi {
  FakeAuthApi(this.user) : super(ApiClient());

  final User user;
  ApiException? throwOnMe;

  @override
  Future<User> me() async {
    if (throwOnMe != null) throw throwOnMe!;
    return user;
  }
}

class FakeCatalogApi extends CatalogApi {
  FakeCatalogApi() : super(ApiClient());

  @override
  Future<List<Plan>> plans() async => const <Plan>[];

  @override
  Future<List<Node>> nodes() async => const <Node>[];
}

User makeUser({double balance = 12.5}) {
  return User(
    email: 'test@test.com',
    name: '测试用户',
    balance: balance,
    expires: DateTime.now()
        .add(const Duration(days: 30))
        .millisecondsSinceEpoch,
    trafficTotal: 10 * 1073741824,
    trafficUsed: 2 * 1073741824,
    plans: const [],
    subToken: 'sub-token',
    planId: 'p1',
    planName: '新人',
  );
}

HomeController makeHomeController({
  required FakeAuthApi authApi,
  FakeSecureStorage? storage,
}) {
  return HomeController(
    authApi: authApi,
    catalogApi: FakeCatalogApi(),
    subscriptionApi: SubscriptionApi(
      ApiClient(),
      templateLoader: const TemplateLoader(),
    ),
    storage: storage ?? FakeSecureStorage(),
    onUnauthorized: () async {},
  );
}

Future<void> pumpAccount(
  WidgetTester tester, {
  required HomeController home,
  AuthController? auth,
}) async {
  // Tall surface: the page is a lazily-built ListView, so off-screen
  // rows (entry list, logout button) would otherwise never be built.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeControllerProvider.overrideWith((ref) => home),
        if (auth != null) authControllerProvider.overrideWith((ref) => auth),
      ],
      child: const MaterialApp(home: AccountPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AccountPage', () {
    testWidgets('shows email, nickname and balance', (tester) async {
      final home = makeHomeController(authApi: FakeAuthApi(makeUser()));
      await home.refresh();
      await pumpAccount(tester, home: home);

      expect(find.text('test@test.com'), findsOneWidget);
      expect(find.text('测试用户'), findsOneWidget);
      expect(find.text('¥12.50'), findsOneWidget);
    });

    testWidgets('entries are disabled with the coming-soon note', (
      tester,
    ) async {
      final home = makeHomeController(authApi: FakeAuthApi(makeUser()));
      await home.refresh();
      await pumpAccount(tester, home: home);

      for (final label in ['工作空间', '设备管理', '安全中心', '客服中心', '设置']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('即将上线'), findsWidgets);
      expect(find.text('退出登录'), findsOneWidget);
    });

    testWidgets('invite section shows coming soon and no code or link', (
      tester,
    ) async {
      final home = makeHomeController(authApi: FakeAuthApi(makeUser()));
      await home.refresh();
      await pumpAccount(tester, home: home);

      expect(find.text('邀请功能即将上线'), findsOneWidget);
      expect(find.text('暂无邀请记录'), findsOneWidget);
      expect(find.textContaining('邀请码'), findsNothing);
      expect(find.textContaining('邀请链接'), findsNothing);
    });

    testWidgets('offline marks the balance as cached data', (tester) async {
      final authApi = FakeAuthApi(makeUser());
      final home = makeHomeController(authApi: authApi);
      await home.refresh();
      expect(home.state.offline, isFalse);

      authApi.throwOnMe = ApiException.network();
      await home.refresh();
      expect(home.state.offline, isTrue);
      expect(home.state.user, isNotNull);

      await pumpAccount(tester, home: home);
      expect(find.text('无网络，余额为缓存数据'), findsOneWidget);
      expect(find.text('缓存'), findsOneWidget);
      // The cached balance is still shown, labelled — never as live data.
      expect(find.text('¥12.50'), findsOneWidget);
    });

    testWidgets('error state shows retry and retry recovers', (tester) async {
      final authApi = FakeAuthApi(makeUser());
      authApi.throwOnMe = const ApiException('用户信息加载失败');
      final home = makeHomeController(authApi: authApi);
      await home.refresh();
      expect(home.state.user, isNull);

      await pumpAccount(tester, home: home);
      expect(find.text('账号信息加载失败，请重试'), findsOneWidget);

      authApi.throwOnMe = null;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('账号信息加载失败，请重试'), findsNothing);
      expect(find.text('test@test.com'), findsOneWidget);
    });

    testWidgets('logout clears the session and flips auth state', (
      tester,
    ) async {
      final storage = FakeSecureStorage()..token = 'session-token';
      final auth = AuthController(
        FakeAuthApi(makeUser()),
        storage,
        ApiClient(),
      );
      await auth.restore();
      expect(auth.state.isLoggedIn, isTrue);

      final home = makeHomeController(authApi: FakeAuthApi(makeUser()));
      await home.refresh();
      await pumpAccount(tester, home: home, auth: auth);

      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();

      // The session is gone, so app.dart routes back to the login page:
      // it shows LoginPage whenever auth state is not logged in.
      expect(auth.state.isLoggedIn, isFalse);
      expect(auth.state.user, isNull);
      expect(storage.token, isNull);
    });
  });
}
