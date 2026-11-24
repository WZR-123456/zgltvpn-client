import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zgltvpn/core/config/merge_config.dart';

/// Golden tests for the subscription merge (contract: SUBSCRIPTION.md §3,
/// architecture §4.5). The Dart port must produce the same merged config as
/// the TypeScript `mergeConfig` for the same input.
void main() {
  group('mergeConfig', () {
    late Map<String, dynamic> template;

    setUpAll(() async {
      // The real bundled template asset (loaded from disk, as the app does
      // from the asset bundle at runtime).
      final raw = await File('assets/singbox-template.json').readAsString();
      template = jsonDecode(raw) as Map<String, dynamic>;
    });

    Map<String, dynamic> serverResponse({String finalRoute = 'proxy'}) {
      return <String, dynamic>{
        'outbounds': <dynamic>[
          <String, dynamic>{
            'type': 'hysteria2',
            'tag': '香港',
            'server': '43.103.2.53',
            'server_port': 443,
            'password': 'test-password',
            'tls': <String, dynamic>{
              'enabled': true,
              'server_name': 'www.bing.com',
              'insecure': true,
            },
          },
          <String, dynamic>{
            'type': 'urltest',
            'tag': 'auto',
            'outbounds': <dynamic>['香港'],
            'url': 'https://www.gstatic.com/generate_204',
            'interval': '10m',
            'tolerance': 50,
          },
          <String, dynamic>{
            'type': 'selector',
            'tag': 'proxy',
            'outbounds': <dynamic>['auto', '香港'],
            'default': 'auto',
          },
          <String, dynamic>{'type': 'direct', 'tag': 'direct'},
        ],
        'route': <String, dynamic>{'final': finalRoute},
      };
    }

    test('merges server outbounds with the template', () {
      final merged = mergeConfig(
        serverJson: serverResponse(),
        template: template,
      );

      // Inbounds + DNS come verbatim from the template.
      expect(merged['inbounds'], template['inbounds']);
      expect(merged['dns'], template['dns']);
      // Outbounds = server outbounds + dns-out.
      final outbounds = merged['outbounds'] as List<dynamic>;
      expect(outbounds.length, 5);
      expect(outbounds.last, <String, dynamic>{
        'type': 'dns',
        'tag': 'dns-out',
      });
      expect(outbounds.first['tag'], '香港');
      // Route = template route with the server's final.
      final route = merged['route'] as Map<String, dynamic>;
      expect(route['final'], 'proxy');
      expect(route['rules'], template['route']['rules']);
      // Log level forced to info; clash_api kept from the template.
      expect(merged['log'], <String, dynamic>{'level': 'info'});
      expect(merged['experimental'], template['experimental']);
    });

    test('extracts real node tags and reports hasNodes', () {
      final merged = mergeConfig(
        serverJson: serverResponse(),
        template: template,
      );
      expect(extractNodeTags(merged), <String>['香港']);
      expect(hasNodes(merged), isTrue);
    });

    test('tunEnabled=false drops the tun inbound (Windows behaviour)', () {
      final merged = mergeConfig(
        serverJson: serverResponse(),
        template: template,
        tunEnabled: false,
      );
      final inbounds = merged['inbounds'] as List<dynamic>;
      expect(
        inbounds.whereType<Map<String, dynamic>>().map((e) => e['type']),
        <String>['mixed'],
      );
      // Template itself is untouched.
      expect(template['inbounds'].length, 2);
    });

    test('expired plan: route.final direct, no nodes', () {
      // Real server shape for an expired plan (Worker buildSingbox with
      // nodes=[]): outbounds carry only `direct`, no auto/proxy/node
      // outbounds at all — the server never sends nodes with final=direct.
      final expired = <String, dynamic>{
        'outbounds': <dynamic>[
          <String, dynamic>{'type': 'direct', 'tag': 'direct'},
        ],
        'route': <String, dynamic>{'final': 'direct'},
      };
      final merged = mergeConfig(serverJson: expired, template: template);
      final route = merged['route'] as Map<String, dynamic>;
      expect(route['final'], 'direct');
      expect(extractNodeTags(merged), isEmpty);
      expect(hasNodes(merged), isFalse);
    });

    test(
      'malformed server JSON throws instead of returning a partial config',
      () {
        expect(
          () =>
              mergeConfig(serverJson: <String, dynamic>{}, template: template),
          throwsFormatException,
        );
        expect(
          () => mergeConfig(
            serverJson: <String, dynamic>{'outbounds': 'nope'},
            template: template,
          ),
          throwsFormatException,
        );
      },
    );

    test('does not mutate the template', () {
      final before = jsonEncode(template);
      mergeConfig(serverJson: serverResponse(), template: template);
      mergeConfig(
        serverJson: serverResponse(),
        template: template,
        tunEnabled: false,
      );
      expect(jsonEncode(template), before);
    });
  });

  group('bundled template asset', () {
    test('parses and has the expected sections', () async {
      final raw = await File('assets/singbox-template.json').readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['inbounds'], isList);
      expect(decoded['dns'], isMap);
      expect(decoded['route'], isMap);
      final inbounds = decoded['inbounds'] as List<dynamic>;
      final types = inbounds
          .whereType<Map<String, dynamic>>()
          .map((e) => e['type'] as String?)
          .toList();
      expect(types, containsAll(<String>['tun', 'mixed']));
    });
  });
}
