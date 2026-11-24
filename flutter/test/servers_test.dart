import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zgltvpn/core/api/api_client.dart';
import 'package:zgltvpn/core/api/api_exception.dart';
import 'package:zgltvpn/core/api/catalog_api.dart';
import 'package:zgltvpn/core/models/node.dart';
import 'package:zgltvpn/core/providers.dart';
import 'package:zgltvpn/core/theme.dart';
import 'package:zgltvpn/features/servers/servers_controller.dart';
import 'package:zgltvpn/features/servers/servers_page.dart';

/// Fake catalog API: no network, behaviour swapped per test by mutating
/// [nodesResult], [statusResult] and [error].
class FakeCatalogApi extends CatalogApi {
  FakeCatalogApi({
    this.nodesResult = const <Node>[],
    this.statusResult = const <NodeStatus>[],
    this.error,
  }) : super(ApiClient());

  List<Node> nodesResult;
  List<NodeStatus> statusResult;
  Object? error;

  @override
  Future<List<Node>> nodes() async {
    if (error != null) throw error!;
    return nodesResult;
  }

  @override
  Future<List<NodeStatus>> nodeStatus() async {
    if (error != null) throw error!;
    return statusResult;
  }
}

const _hkNode = Node(
  id: 'n1',
  name: '香港 01',
  region: '香港',
  type: 'hysteria2',
  server: '43.103.2.53',
  port: 443,
  tls: true,
  enabled: true,
  sni: 'www.bing.com',
  skipCert: true,
  check: NodeCheck(ok: true, ms: 42),
);

const _sgNode = Node(
  id: 'n2',
  name: 'Singapore 01',
  region: '新加坡',
  type: 'vless',
  server: '1.2.3.4',
  port: 443,
  tls: true,
  enabled: true,
);

const _disabledNode = Node(
  id: 'n3',
  name: 'Tokyo 01',
  region: '日本',
  type: 'trojan',
  server: '5.6.7.8',
  port: 443,
  tls: true,
  enabled: false,
);

const _hkStatus = NodeStatus(name: '香港 01', region: '香港', ok: true, ms: 42);
const _sgStatus = NodeStatus(
  name: 'Singapore 01',
  region: '新加坡',
  ok: false,
  ms: null,
);

ProviderContainer _containerWith(FakeCatalogApi fake) {
  final container = ProviderContainer(
    overrides: [catalogApiProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ServersController', () {
    test('load success fills nodes, statuses and lastSync', () async {
      final fake = FakeCatalogApi(
        nodesResult: [_hkNode, _sgNode],
        statusResult: [_hkStatus, _sgStatus],
      );
      final container = _containerWith(fake);
      final notifier = container.read(serversControllerProvider.notifier);

      await notifier.refresh();
      final state = container.read(serversControllerProvider);

      expect(state.loading, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.error, isNull);
      expect(state.offline, isFalse);
      expect(state.nodes, [_hkNode, _sgNode]);
      expect(state.lastSync, isNotNull);
      expect(state.latencyMs(_hkNode), 42);
      expect(state.latencyMs(_sgNode), isNull);
      expect(state.statusFor(_hkNode), ServersNodeStatus.available);
      expect(state.statusFor(_sgNode), ServersNodeStatus.unreachable);
    });

    test('filter matches name and region, case-insensitive', () async {
      final fake = FakeCatalogApi(nodesResult: [_hkNode, _sgNode]);
      final container = _containerWith(fake);
      final notifier = container.read(serversControllerProvider.notifier);
      await notifier.refresh();

      notifier.setSearchQuery('香港');
      expect(container.read(serversControllerProvider).filteredNodes, [
        _hkNode,
      ]);

      notifier.setSearchQuery('singapore');
      expect(container.read(serversControllerProvider).filteredNodes, [
        _sgNode,
      ]);

      notifier.setSearchQuery('不存在');
      expect(container.read(serversControllerProvider).filteredNodes, isEmpty);

      notifier.setSearchQuery('');
      expect(container.read(serversControllerProvider).filteredNodes, [
        _hkNode,
        _sgNode,
      ]);
    });

    test('grouping groups by region with sorted keys', () async {
      final fake = FakeCatalogApi(
        nodesResult: [_sgNode, _hkNode, _disabledNode],
      );
      final container = _containerWith(fake);
      await container.read(serversControllerProvider.notifier).refresh();
      final grouped = container.read(serversControllerProvider).groupedNodes;

      expect(grouped.keys.toList(), ['新加坡', '日本', '香港']..sort());
      expect(grouped['香港'], [_hkNode]);
      expect(grouped['日本'], [_disabledNode]);
    });

    test('network error keeps last-known data and marks offline', () async {
      final fake = FakeCatalogApi(
        nodesResult: [_hkNode],
        statusResult: [_hkStatus],
      );
      final container = _containerWith(fake);
      final notifier = container.read(serversControllerProvider.notifier);
      await notifier.refresh();
      expect(container.read(serversControllerProvider).offline, isFalse);

      fake.error = ApiException.network();
      await notifier.refresh();
      final state = container.read(serversControllerProvider);

      expect(state.nodes, [_hkNode]);
      expect(state.offline, isTrue);
      expect(state.error, isNull);
      // Offline rows show "—" instead of the stale latency.
      expect(state.latencyMs(_hkNode), isNull);
    });

    test('server error keeps last-known data and records the error', () async {
      final fake = FakeCatalogApi(nodesResult: [_hkNode]);
      final container = _containerWith(fake);
      final notifier = container.read(serversControllerProvider.notifier);
      await notifier.refresh();

      fake.error = const ApiException(
        '节点列表加载失败，请重试',
        kind: ApiErrorKind.server,
      );
      await notifier.refresh();
      final state = container.read(serversControllerProvider);

      expect(state.nodes, [_hkNode]);
      expect(state.offline, isFalse);
      expect(state.error, '节点列表加载失败，请重试');
    });

    test('error with no cached data leaves an empty list + error', () async {
      final fake = FakeCatalogApi(
        error: const ApiException('节点列表加载失败，请重试', kind: ApiErrorKind.server),
      );
      final container = _containerWith(fake);
      await container.read(serversControllerProvider.notifier).refresh();
      final state = container.read(serversControllerProvider);

      expect(state.nodes, isEmpty);
      expect(state.loading, isFalse);
      expect(state.error, '节点列表加载失败，请重试');
    });

    test('empty load is an empty state, not an error', () async {
      final fake = FakeCatalogApi();
      final container = _containerWith(fake);
      await container.read(serversControllerProvider.notifier).refresh();
      final state = container.read(serversControllerProvider);

      expect(state.nodes, isEmpty);
      expect(state.error, isNull);
      expect(state.offline, isFalse);
    });

    test('disabled node is disabled, unknown node has no latency', () async {
      final fake = FakeCatalogApi(nodesResult: [_disabledNode, _sgNode]);
      final container = _containerWith(fake);
      await container.read(serversControllerProvider.notifier).refresh();
      final state = container.read(serversControllerProvider);

      expect(state.statusFor(_disabledNode), ServersNodeStatus.disabled);
      // Singapore has no status entry and no check: unknown, latency "—".
      expect(state.statusFor(_sgNode), ServersNodeStatus.unknown);
      expect(state.latencyMs(_sgNode), isNull);
    });
  });

  group('ServersPage', () {
    testWidgets('empty state shows 暂无可用节点 + 刷新 button', (tester) async {
      final fake = FakeCatalogApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [catalogApiProvider.overrideWithValue(fake)],
          child: MaterialApp(
            theme: ZgltTheme.light,
            home: const Scaffold(body: ServersPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('暂无可用节点'), findsOneWidget);
      expect(find.text('刷新'), findsOneWidget);
      expect(find.text('搜索节点 / 地区'), findsOneWidget);
    });

    testWidgets('loaded list shows grouped rows with badges', (tester) async {
      final fake = FakeCatalogApi(
        nodesResult: [_hkNode, _sgNode, _disabledNode],
        statusResult: [_hkStatus, _sgStatus],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [catalogApiProvider.overrideWithValue(fake)],
          child: MaterialApp(
            theme: ZgltTheme.light,
            home: const Scaffold(body: ServersPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('香港 01'), findsOneWidget);
      expect(find.text('Singapore 01'), findsOneWidget);
      expect(find.text('Tokyo 01'), findsOneWidget);
      expect(find.text('可用'), findsOneWidget);
      expect(find.text('不可达'), findsOneWidget);
      expect(find.text('已停用'), findsOneWidget);
      expect(find.text('42ms'), findsOneWidget);
      expect(find.text('延迟为服务端 TCP 检测结果'), findsOneWidget);
    });

    testWidgets('tapping a row opens the detail sheet, switch disabled', (
      tester,
    ) async {
      final fake = FakeCatalogApi(
        nodesResult: [_hkNode],
        statusResult: [_hkStatus],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [catalogApiProvider.overrideWithValue(fake)],
          child: MaterialApp(
            theme: ZgltTheme.light,
            home: const Scaffold(body: ServersPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('香港 01'));
      await tester.pumpAndSettle();

      expect(find.text('43.103.2.53'), findsOneWidget);
      expect(find.text('切换到该节点'), findsOneWidget);
      expect(find.text('节点切换随 VPN 连接功能上线'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '切换到该节点'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('dark theme: node rows use the dark surface, not light', (
      tester,
    ) async {
      final fake = FakeCatalogApi(
        nodesResult: [_hkNode, _sgNode, _disabledNode],
        statusResult: [_hkStatus, _sgStatus],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [catalogApiProvider.overrideWithValue(fake)],
          child: MaterialApp(
            theme: ZgltTheme.light,
            darkTheme: ZgltTheme.dark,
            themeMode: ThemeMode.dark,
            home: const Scaffold(body: ServersPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The node row box resolves to the dark card surface.
      final row = tester.widget<Container>(
        find.ancestor(of: find.text('香港 01'), matching: find.byType(Container)),
      );
      final rowColor = (row.decoration as BoxDecoration?)?.color;
      expect(rowColor, ZgltColorsDark.surface);
      expect(rowColor, isNot(ZgltColors.surface));

      // The node name text resolves to the dark primary text colour.
      final name = tester.widget<Text>(find.text('香港 01'));
      expect(name.style?.color, ZgltColorsDark.text);

      // The "可用" badge uses the dark soft-accent fill (its ancestors
      // also include the row box, so match by colour, not by count).
      final badgeColors = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text('可用'),
              matching: find.byType(Container),
            ),
          )
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .toList();
      expect(badgeColors, contains(ZgltColorsDark.accentSoft));
    });

    testWidgets('light theme: node rows keep the old light surface', (
      tester,
    ) async {
      final fake = FakeCatalogApi(
        nodesResult: [_hkNode, _sgNode, _disabledNode],
        statusResult: [_hkStatus, _sgStatus],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [catalogApiProvider.overrideWithValue(fake)],
          child: MaterialApp(
            theme: ZgltTheme.light,
            darkTheme: ZgltTheme.dark,
            themeMode: ThemeMode.light,
            home: const Scaffold(body: ServersPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = tester.widget<Container>(
        find.ancestor(of: find.text('香港 01'), matching: find.byType(Container)),
      );
      expect((row.decoration as BoxDecoration?)?.color, ZgltColors.surface);

      final name = tester.widget<Text>(find.text('香港 01'));
      expect(name.style?.color, ZgltColors.text);

      final badgeColors = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text('可用'),
              matching: find.byType(Container),
            ),
          )
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .toList();
      expect(badgeColors, contains(ZgltColors.accentSoft));
    });
  });
}
