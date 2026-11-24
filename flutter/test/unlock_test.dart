import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zgltvpn/core/api/api_client.dart';
import 'package:zgltvpn/core/api/api_exception.dart';
import 'package:zgltvpn/core/api/auth_api.dart';
import 'package:zgltvpn/core/api/catalog_api.dart';
import 'package:zgltvpn/core/api/orders_api.dart';
import 'package:zgltvpn/core/api/subscription_api.dart';
import 'package:zgltvpn/core/config/template_loader.dart';
import 'package:zgltvpn/core/models/node.dart';
import 'package:zgltvpn/core/models/order.dart';
import 'package:zgltvpn/core/models/plan.dart';
import 'package:zgltvpn/core/models/user.dart';
import 'package:zgltvpn/core/providers.dart';
import 'package:zgltvpn/core/storage/secure_storage.dart';
import 'package:zgltvpn/core/storage/settings_storage.dart';
import 'package:zgltvpn/core/theme.dart';
import 'package:zgltvpn/features/connection/home_controller.dart';
import 'package:zgltvpn/features/connection/home_page.dart';
import 'package:zgltvpn/features/membership/membership_page.dart';
import 'package:zgltvpn/features/membership/orders_page.dart';
import 'package:zgltvpn/features/settings/settings_controller.dart';
import 'package:zgltvpn/features/settings/settings_page.dart';

/// NORTH Phase 4 unlock: every previously-locked control is tappable,
/// local preferences persist for real, and nothing is faked — no fake
/// connect state, no fake purchase, no fake update result.

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

  @override
  Future<User> me() async => user;
}

class FakeCatalogApi extends CatalogApi {
  FakeCatalogApi(this.plansToReturn) : super(ApiClient());

  final List<Plan> plansToReturn;

  @override
  Future<List<Plan>> plans() async => plansToReturn;

  @override
  Future<List<Node>> nodes() async => const <Node>[];
}

class FakeOrdersApi extends OrdersApi {
  FakeOrdersApi(this.ordersToReturn) : super(ApiClient());

  final List<Order> ordersToReturn;
  ApiException? throwOnOrders;
  int loadCalls = 0;

  @override
  Future<List<Order>> orders() async {
    loadCalls++;
    if (throwOnOrders != null) throw throwOnOrders!;
    return ordersToReturn;
  }
}

class FakeSettingsStorage extends SettingsStorage {
  final Map<String, Object> values = {};

  @override
  Future<String?> readThemeMode() async => values['theme'] as String?;

  @override
  Future<void> saveThemeMode(String value) async {
    values['theme'] = value;
  }

  @override
  Future<bool?> readAutoConnect() async => values['autoConnect'] as bool?;

  @override
  Future<void> saveAutoConnect(bool value) async {
    values['autoConnect'] = value;
  }

  @override
  Future<bool?> readAutoRefreshSubscription() async =>
      values['autoRefresh'] as bool?;

  @override
  Future<void> saveAutoRefreshSubscription(bool value) async {
    values['autoRefresh'] = value;
  }

  @override
  Future<bool?> readNotifications() async => values['notifications'] as bool?;

  @override
  Future<void> saveNotifications(bool value) async {
    values['notifications'] = value;
  }
}

User makeUser() {
  return User(
    email: 'test@test.com',
    name: '测试用户',
    balance: 12.5,
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

Future<HomeController> makeHomeController() async {
  final controller = HomeController(
    authApi: FakeAuthApi(makeUser()),
    catalogApi: FakeCatalogApi(const []),
    subscriptionApi: SubscriptionApi(
      ApiClient(),
      templateLoader: const TemplateLoader(),
    ),
    storage: FakeSecureStorage(),
    onUnauthorized: () async {},
  );
  await controller.refresh();
  return controller;
}

Future<void> pumpHome(WidgetTester tester, HomeController home) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [homeControllerProvider.overrideWith((ref) => home)],
      child: MaterialApp(theme: ZgltTheme.light, home: const HomePage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpMembership(
  WidgetTester tester, {
  required HomeController home,
  required FakeOrdersApi ordersApi,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catalogApiProvider.overrideWithValue(FakeCatalogApi(const [])),
        homeControllerProvider.overrideWith((ref) => home),
        ordersApiProvider.overrideWithValue(ordersApi),
      ],
      child: MaterialApp(theme: ZgltTheme.light, home: const MembershipPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpOrders(WidgetTester tester, FakeOrdersApi ordersApi) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [ordersApiProvider.overrideWithValue(ordersApi)],
      child: MaterialApp(theme: ZgltTheme.light, home: const OrdersPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpSettings(
  WidgetTester tester,
  SettingsController controller,
) async {
  // Tall surface: the page is a lazily-built ListView, so off-screen
  // switches would otherwise never be built.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsControllerProvider.overrideWith((ref) => controller)],
      child: MaterialApp(theme: ZgltTheme.light, home: const SettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Order model', () {
    test('fromJson parses backend fields, status labels are honest', () {
      final order = Order.fromJson(<String, dynamic>{
        'id': 'abc123',
        'kind': 'plan',
        'item': '月套餐 month',
        'amount': 10,
        'channel': '余额支付',
        'status': 'paid',
        'created': DateTime(2026, 11, 20).millisecondsSinceEpoch,
      });
      expect(order.id, 'abc123');
      expect(order.item, '月套餐 month');
      expect(order.amount, 10);
      expect(order.statusLabel, '已支付');
      expect(Order.fromJson({'status': 'pending'}).statusLabel, '待支付');
      expect(
        Order.fromJson({'status': 'weird_status'}).statusLabel,
        'weird_status',
      );
      expect(Order.fromJson({}).statusLabel, '—');
      expect(Order.fromJson({}).item, '');
      expect(Order.fromJson({}).amount, 0);
    });
  });

  group('User invite fields', () {
    test('fromJson parses invite stats from /api/me', () {
      final user = User.fromJson(<String, dynamic>{
        'email': 'a@b.c',
        'invite_count': 3,
        'invite_paid_count': 1,
        'rebate_earned': 5.5,
      });
      expect(user.inviteCount, 3);
      expect(user.invitePaidCount, 1);
      expect(user.rebateEarned, 5.5);
      // Missing fields default to zero — never a made-up number.
      expect(User.fromJson({}).inviteCount, 0);
      expect(User.fromJson({}).rebateEarned, 0);
    });
  });

  group('HomePage unlock', () {
    testWidgets('connect button opens coming-soon, never fakes connected', (
      tester,
    ) async {
      final home = await makeHomeController();
      await pumpHome(tester, home);

      expect(find.text('未连接'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.power_settings_new));
      await tester.pumpAndSettle();

      expect(find.text('VPN 连接即将上线'), findsOneWidget);
      expect(find.text('已连接'), findsNothing);
      expect(find.textContaining('连接成功'), findsNothing);
    });

    testWidgets('renew button opens the purchase coming-soon page', (
      tester,
    ) async {
      final home = await makeHomeController();
      await pumpHome(tester, home);

      await tester.tap(find.text('续订套餐'));
      await tester.pumpAndSettle();
      expect(find.text('购买与续订即将上线'), findsOneWidget);
    });

    testWidgets('speed test and support quick actions are tappable', (
      tester,
    ) async {
      final home = await makeHomeController();
      await pumpHome(tester, home);

      await tester.tap(find.text('测速'));
      await tester.pumpAndSettle();
      expect(find.text('测速即将上线'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('客服'));
      await tester.pumpAndSettle();
      expect(find.text('客服中心即将上线'), findsOneWidget);
    });

    testWidgets('messages tab shows the coming-soon body, not a dead end', (
      tester,
    ) async {
      final home = await makeHomeController();
      await pumpHome(tester, home);

      await tester.tap(find.text('消息'));
      await tester.pumpAndSettle();
      expect(find.text('消息中心即将上线'), findsOneWidget);
      expect(find.text('站内信与通知功能即将上线。'), findsOneWidget);
    });
  });

  group('OrdersPage (real wiring)', () {
    testWidgets('shows real orders from /api/u/orders', (tester) async {
      final fake = FakeOrdersApi([
        Order(
          id: 'o1',
          item: '月套餐 month',
          amount: 10,
          status: 'paid',
          created: DateTime(2026, 11, 20).millisecondsSinceEpoch,
          channel: '余额支付',
        ),
        Order(
          id: 'o2',
          item: '流量重置',
          amount: 5.5,
          status: 'paid',
          created: DateTime(2026, 11, 21).millisecondsSinceEpoch,
        ),
      ]);
      await pumpOrders(tester, fake);

      expect(find.text('月套餐 month'), findsOneWidget);
      expect(find.text('¥10'), findsOneWidget);
      expect(find.text('流量重置'), findsOneWidget);
      expect(find.text('¥5.50'), findsOneWidget);
      expect(find.text('已支付'), findsWidgets);
      expect(find.text('2026/11/20'), findsOneWidget);
      expect(find.text('余额支付'), findsOneWidget);
      expect(fake.loadCalls, 1);
    });

    testWidgets('empty list shows 暂无订单, never a fake order', (tester) async {
      await pumpOrders(tester, FakeOrdersApi(const []));
      expect(find.text('暂无订单'), findsOneWidget);
    });

    testWidgets('error state shows retry and retry recovers', (tester) async {
      final fake = FakeOrdersApi(const [])
        ..throwOnOrders = ApiException.network();
      await pumpOrders(tester, fake);

      expect(find.text('网络异常，请重试'), findsOneWidget);
      expect(fake.loadCalls, 1);

      fake.throwOnOrders = null;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('网络异常，请重试'), findsNothing);
      expect(find.text('暂无订单'), findsOneWidget);
      expect(fake.loadCalls, 2);
    });

    testWidgets('orders row on the membership page opens the real list', (
      tester,
    ) async {
      final home = await makeHomeController();
      final fake = FakeOrdersApi([
        Order(
          id: 'o1',
          item: '月套餐 month',
          amount: 10,
          status: 'paid',
          created: DateTime(2026, 11, 20).millisecondsSinceEpoch,
        ),
      ]);
      await pumpMembership(tester, home: home, ordersApi: fake);

      await tester.tap(find.text('我的订单'));
      await tester.pumpAndSettle();
      expect(find.text('月套餐 month'), findsOneWidget);
      expect(find.text('¥10'), findsOneWidget);
    });
  });

  group('SettingsPage unlock', () {
    testWidgets('language row opens the more-languages coming-soon page', (
      tester,
    ) async {
      final controller = SettingsController(FakeSettingsStorage());
      await controller.load();
      await pumpSettings(tester, controller);

      // '语言' also appears as the section header: tap the tile itself.
      await tester.tap(find.widgetWithText(ListTile, '语言'));
      await tester.pumpAndSettle();
      expect(find.text('更多语言即将上线'), findsOneWidget);
    });

    testWidgets('auto-refresh and notifications toggles persist and reload', (
      tester,
    ) async {
      final storage = FakeSettingsStorage();
      final controller = SettingsController(storage);
      await controller.load();
      await pumpSettings(tester, controller);

      await tester.tap(find.widgetWithText(SwitchListTile, '订阅自动刷新'));
      await tester.pumpAndSettle();
      expect(controller.state.autoRefreshSubscription, isTrue);
      expect(storage.values['autoRefresh'], isTrue);

      await tester.tap(find.widgetWithText(SwitchListTile, '通知'));
      await tester.pumpAndSettle();
      expect(controller.state.notificationsEnabled, isFalse);
      expect(storage.values['notifications'], isFalse);

      // Round-trip: a fresh controller reads the saved values back.
      final second = SettingsController(storage);
      await second.load();
      expect(second.state.autoRefreshSubscription, isTrue);
      expect(second.state.notificationsEnabled, isFalse);
      expect(second.state.autoConnect, isFalse);
    });
  });
}
