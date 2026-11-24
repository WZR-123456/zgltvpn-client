import 'dart:convert';

import 'api_client.dart';
import 'api_exception.dart';
import '../config/merge_config.dart';
import '../config/template_loader.dart';
import '../models/userinfo.dart';

/// Subscription fetch + merge (contract: SUBSCRIPTION.md §2–§3).
///
/// Fetches `GET /sub/<sub_token>?format=singbox` and merges the result with
/// the bundled template via [mergeConfig]. The merged JSON is what the VPN
/// core receives — the server response alone has no inbounds/dns and cannot
/// be handed to the core directly.
class SubscriptionApi {
  SubscriptionApi(this._client, {required this.templateLoader});

  final ApiClient _client;
  final TemplateLoader templateLoader;

  /// Fetches and merges the subscription for [subToken].
  ///
  /// Returns the merged config JSON string plus the parsed
  /// `subscription-userinfo` header and the real node tags. When the plan
  /// is expired the server returns no real nodes; [SubscriptionResult.hasNodes]
  /// is then false and the caller must show "套餐已过期，请续费" instead of
  /// starting a tunnel.
  Future<SubscriptionResult> fetchMerged({
    required String subToken,
    bool tunEnabled = true,
  }) async {
    final response = await _client.get(
      '/sub/$subToken',
      queryParameters: <String, dynamic>{'format': 'singbox'},
    );
    final data = ApiClient.asMap(response.data);
    if (data.isEmpty || data['outbounds'] == null) {
      throw const ApiException('订阅数据格式错误');
    }
    final userinfo = UserinfoHeader.parse(
      response.headers.value('subscription-userinfo'),
    );
    final template = await templateLoader.load();
    final merged = mergeConfig(
      serverJson: data,
      template: template,
      tunEnabled: tunEnabled,
    );
    return SubscriptionResult(
      configJson: jsonEncode(merged),
      mergedConfig: merged,
      userinfo: userinfo,
      nodeTags: extractNodeTags(merged),
    );
  }
}

class SubscriptionResult {
  const SubscriptionResult({
    required this.configJson,
    required this.mergedConfig,
    required this.userinfo,
    required this.nodeTags,
  });

  /// Merged sing-box config, JSON-encoded (what the VPN core receives).
  final String configJson;

  /// The same merged config, decoded.
  final Map<String, dynamic> mergedConfig;

  final UserinfoHeader userinfo;

  /// Real node tags (built-in groups excluded).
  final List<String> nodeTags;

  bool get hasNodes => nodeTags.isNotEmpty;
}
