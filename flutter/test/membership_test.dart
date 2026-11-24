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
import 'package:zgltvpn/core/theme.dart';
import 'package:zgltvpn/core/utils/format.dart';
import 'package:zgltvpn/features/connection/home_controller.dart';
import 'package:zgltvpn/features/membership/membership_controller.dart';
import 'package:zgltvpn/features/membership/membership_page.dart';

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
  FakeCatalogApi(this.plansToReturn, {this.failuresRemaining = 0})
    : super(ApiClient());

  final List<Plan> plansToReturn;
  int failuresRemaining;
  int loadCalls = 0;

  @override
  Future<List<Plan>> plans() async {
    loadCalls++;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw ApiException.network();
    }
    return plansToReturn;
  }

  @override
  Future<List<Node>> nodes() async => const <Node>[];
}

User makeUser({
  int? expires,
  int trafficTotal = 10 * 1073741824,
  int trafficUsed = 2 * 1073741824,
  String planName = '新人',
}) {
  return User(
    email: 'test@test.com',
    name: '测试用户',
    balance: 12.5,
    expires:
        expires ??
        DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
    trafficTotal: trafficTotal,
    trafficUsed: trafficUsed,
    plans: const [],
    subToken: 'sub-token',
    planId: 'p1',
    planName: planName,
  );
}

Future<HomeController> makeHomeController(User user) async {
  final controller = HomeController(
    authApi: FakeAuthApi(user),
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

const testPlans = <Plan>[
  Plan(
    id: 'p1',
    name: '月套餐',
    kind: 'sub',
    trafficGb: 10,
    prices: PlanPrices(month: 10, quarter: 25, year: 90),
    nodeIds: [],
    enabled: true,
  ),
  Plan(
    id: 'p2',
    name: '流量包',
    kind: 'pack',
    trafficGb: 5,
    prices: PlanPrices(month: 5),
    nodeIds: [],
    enabled: true,
  ),
  Plan(
    id: 'p3',
    name: '下架套餐',
    kind: 'sub',
    trafficGb: 1,
    prices: PlanPrices(month: 1),
    nodeIds: [],
    enabled: false,
  ),
];

Future<void> pumpMembership(
  WidgetTester tester, {
  required FakeCatalogApi catalog,
  required HomeController home,
}) async {
  // Tall surface: the page is a lazily-built ListView, so off-screen
  // rows (orders row, buy buttons) would otherwise never be built.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catalogApiProvider.overrideWithValue(catalog),
        homeControllerProvider.overrideWith((ref) => home),
      ],
      child: MaterialApp(theme: ZgltTheme.light, home: const MembershipPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('price helpers', () {
    test('priceForPeriod picks the period price', () {
      const plan = Plan(
        id: 'p1',
        name: '月套餐',
        kind: 'sub',
        trafficGb: 10,
        prices: PlanPrices(month: 10, quarter: 25, year: 90),
        nodeIds: [],
        enabled: true,
      );
      expect(priceForPeriod(plan, MembershipPeriod.month), 10);
      expect(priceForPeriod(plan, MembershipPeriod.quarter), 25);
      expect(priceForPeriod(plan, MembershipPeriod.year), 90);
    });

    test('missing period price is null and formats as a dash', () {
      const plan = Plan(
        id: 'p2',
        name: '流量包',
        kind: 'pack',
        trafficGb: 5,
        prices: PlanPrices(month: 5),
        nodeIds: [],
        enabled: true,
      );
      expect(priceForPeriod(plan, MembershipPeriod.quarter), isNull);
      expect(formatPrice(null), '—');
      expect(formatPrice(10), '¥10');
      expect(formatPrice(10.5), '¥10.50');
    });

    test('displaySpeed hides missing and dirty speeds', () {
      expect(displaySpeed(null), '—');
      expect(displaySpeed(''), '—');
      expect(displaySpeed('100Mbps'), '100Mbps');
      // The known dirty backend value is never shown raw.
      expect(displaySpeed('100000'), '—');
      expect(displaySpeed('10000'), '—');
    });

    test('expiry reminder shows at 7 days or less, not at 8', () {
      final now = DateTime(2026, 11, 24, 12);
      final in5Days = now.add(const Duration(days: 5)).millisecondsSinceEpoch;
      final in7Days = now.add(const Duration(days: 7)).millisecondsSinceEpoch;
      final in8Days = now.add(const Duration(days: 8)).millisecondsSinceEpoch;
      final past = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      expect(shouldShowExpiryReminder(in5Days, now: now), isTrue);
      expect(shouldShowExpiryReminder(in7Days, now: now), isTrue);
      expect(shouldShowExpiryReminder(in8Days, now: now), isFalse);
      expect(shouldShowExpiryReminder(past, now: now), isFalse);
      expect(shouldShowExpiryReminder(0, now: now), isFalse);
    });
  });

  group('MembershipPage', () {
    testWidgets('period switch changes the displayed price', (tester) async {
      final home = await makeHomeController(makeUser());
      await pumpMembership(
        tester,
        catalog: FakeCatalogApi(testPlans),
        home: home,
      );

      expect(find.text('¥10/月'), findsOneWidget);
      expect(find.text('¥5/月'), findsOneWidget);
      expect(find.text('下架套餐'), findsNothing);

      await tester.tap(find.text('季'));
      await tester.pumpAndSettle();
      expect(find.text('¥25/季'), findsOneWidget);
      expect(find.text('¥10/月'), findsNothing);
      // The pack has no quarterly price: shown as "—", never made up.
      expect(find.text('—'), findsOneWidget);

      await tester.tap(find.text('年'));
      await tester.pumpAndSettle();
      expect(find.text('¥90/年'), findsOneWidget);
    });

    testWidgets('expiry reminder bar shows within 7 days only', (tester) async {
      final expiresSoon = DateTime.now()
          .add(const Duration(days: 5))
          .millisecondsSinceEpoch;
      final home = await makeHomeController(makeUser(expires: expiresSoon));
      await pumpMembership(
        tester,
        catalog: FakeCatalogApi(testPlans),
        home: home,
      );
      expect(
        find.text('套餐将于 ${Format.expiry(expiresSoon)} 到期'),
        findsOneWidget,
      );

      final expiresLater = DateTime.now()
          .add(const Duration(days: 30))
          .millisecondsSinceEpoch;
      final homeLater = await makeHomeController(
        makeUser(expires: expiresLater),
      );
      await pumpMembership(
        tester,
        catalog: FakeCatalogApi(testPlans),
        home: homeLater,
      );
      expect(find.text('套餐将于 ${Format.expiry(expiresLater)} 到期'), findsNothing);
    });

    testWidgets('dirty plan traffic shows the dirty-data label', (
      tester,
    ) async {
      const dirtyPlan = Plan(
        id: 'p9',
        name: '免费套餐',
        kind: 'sub',
        trafficGb: 1e97,
        prices: PlanPrices(month: 0),
        nodeIds: [],
        enabled: true,
      );
      final home = await makeHomeController(makeUser());
      await pumpMembership(
        tester,
        catalog: FakeCatalogApi(const [dirtyPlan]),
        home: home,
      );
      expect(find.text('不限量（数据异常）'), findsWidgets);
      expect(find.textContaining('1e+97'), findsNothing);
    });

    testWidgets('empty plan shows the no-plan state', (tester) async {
      final home = await makeHomeController(makeUser(expires: 0, planName: ''));
      await pumpMembership(
        tester,
        catalog: FakeCatalogApi(testPlans),
        home: home,
      );
      expect(find.text('暂无生效套餐'), findsOneWidget);
      expect(find.text('购买与续订功能即将上线'), findsWidgets);
    });

    testWidgets('error state shows offline banner and retry works', (
      tester,
    ) async {
      final catalog = FakeCatalogApi(testPlans, failuresRemaining: 1);
      final home = await makeHomeController(makeUser());
      await pumpMembership(tester, catalog: catalog, home: home);

      expect(find.text('套餐信息加载失败，请重试'), findsOneWidget);
      expect(find.text('无网络，无法购买'), findsOneWidget);
      expect(catalog.loadCalls, 1);

      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('套餐信息加载失败，请重试'), findsNothing);
      expect(find.text('月套餐'), findsOneWidget);
      expect(catalog.loadCalls, 2);
    });

    testWidgets('buy buttons are disabled with the coming-soon note', (
      tester,
    ) async {
      final home = await makeHomeController(makeUser());
      await pumpMembership(
        tester,
        catalog: FakeCatalogApi(testPlans),
        home: home,
      );
      expect(find.text('购买与续订功能即将上线'), findsWidgets);
      expect(find.text('我的订单'), findsOneWidget);
      expect(find.text('即将上线'), findsWidgets);
    });

    testWidgets(
      'tapping a plan card expands its detail, second tap collapses',
      (tester) async {
        const detailPlan = Plan(
          id: 'pd',
          name: '详情套餐',
          kind: 'sub',
          trafficGb: 20,
          prices: PlanPrices(month: 10, quarter: 25, year: 90),
          nodeIds: ['n1', 'n2'],
          enabled: true,
          devices: '2',
          speed: '100Mbps',
        );
        final home = await makeHomeController(makeUser());
        await pumpMembership(
          tester,
          catalog: FakeCatalogApi(const [detailPlan]),
          home: home,
        );

        // Collapsed: only the summary is shown.
        expect(find.text('详情套餐'), findsOneWidget);
        expect(find.text('¥10/月'), findsOneWidget);
        expect(find.text('设备数'), findsNothing);
        expect(find.text('限速'), findsNothing);

        await tester.tap(find.text('详情套餐'));
        await tester.pumpAndSettle();

        // Expanded: all three period prices plus the stored detail.
        expect(find.text('月价'), findsOneWidget);
        expect(find.text('¥10'), findsOneWidget);
        expect(find.text('季价'), findsOneWidget);
        expect(find.text('¥25'), findsOneWidget);
        expect(find.text('年价'), findsOneWidget);
        expect(find.text('¥90'), findsOneWidget);
        expect(find.text('流量'), findsOneWidget);
        // Shown in both the collapsed summary and the detail rows.
        expect(find.text('20 GB'), findsWidgets);
        expect(find.text('设备数'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('限速'), findsOneWidget);
        expect(find.text('100Mbps'), findsOneWidget);
        expect(find.text('节点'), findsOneWidget);
        expect(find.text('包含 2 个节点'), findsOneWidget);

        await tester.tap(find.text('详情套餐'));
        await tester.pumpAndSettle();
        expect(find.text('设备数'), findsNothing);
        expect(find.text('限速'), findsNothing);
        expect(find.text('详情套餐'), findsOneWidget);
      },
    );

    testWidgets('expanded detail shows a dash for missing fields', (
      tester,
    ) async {
      // testPlans p1 has no devices/speed and unrestricted nodes.
      final home = await makeHomeController(makeUser());
      await pumpMembership(
        tester,
        catalog: FakeCatalogApi(testPlans),
        home: home,
      );

      await tester.tap(find.text('月套餐'));
      await tester.pumpAndSettle();

      expect(find.text('设备数'), findsOneWidget);
      expect(find.text('限速'), findsOneWidget);
      expect(find.text('全部节点'), findsOneWidget);
      // Devices + speed are both missing: shown as "—", never made up.
      expect(find.text('—'), findsWidgets);
    });
  });
}
