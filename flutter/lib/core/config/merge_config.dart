import 'dart:convert';

/// Port of the TypeScript `mergeConfig` (contract: SUBSCRIPTION.md §3,
/// architecture §4.5). The same input must produce the same merged config
/// on both clients; a golden test guards this.
///
/// - `inbounds` = template inbounds (tun + mixed), verbatim.
///   When [tunEnabled] is false the tun inbound is dropped (the Windows
///   system-proxy behaviour); Android keeps it.
/// - `dns` = template dns, verbatim.
/// - `outbounds` = server outbounds + `{type: "dns", tag: "dns-out"}`.
/// - `route` = template route, with `route.final` taken from the server
///   (`proxy` when nodes exist, `direct` when the plan is expired).
/// - `experimental.clash_api` is kept from the template (Windows uses it;
///   Android ignores it — libbox has its own stats interface).
/// - `log.level` is forced to `info`.
///
/// Throws [FormatException] on malformed input; never returns a partial
/// config. The template map is never mutated (sections are deep-copied).
Map<String, dynamic> mergeConfig({
  required Map<String, dynamic> serverJson,
  required Map<String, dynamic> template,
  bool tunEnabled = true,
}) {
  final serverOutbounds = serverJson['outbounds'];
  if (serverOutbounds is! List) {
    throw const FormatException('订阅缺少 outbounds');
  }
  final serverRoute = serverJson['route'];
  final serverFinal = serverRoute is Map<String, dynamic>
      ? serverRoute['final'] as String?
      : null;

  final merged = <String, dynamic>{};

  final inbounds = _deepCopyList(template['inbounds']);
  if (!tunEnabled) {
    inbounds.removeWhere(
      (e) => e is Map<String, dynamic> && e['type'] == 'tun',
    );
  }
  merged['inbounds'] = inbounds;

  merged['dns'] = _deepCopy(template['dns']);

  final outbounds = _deepCopyList(serverOutbounds);
  outbounds.add(<String, dynamic>{'type': 'dns', 'tag': 'dns-out'});
  merged['outbounds'] = outbounds;

  final route = _deepCopyMap(template['route']);
  route['final'] = serverFinal ?? 'direct';
  merged['route'] = route;

  if (template['experimental'] != null) {
    merged['experimental'] = _deepCopy(template['experimental']);
  }

  merged['log'] = <String, dynamic>{'level': 'info'};
  return merged;
}

/// Node tags from a merged config, excluding the built-in groups
/// (`auto`, `proxy`, `direct`, `dns-out`). What remains are real nodes;
/// the default selection is `auto`.
List<String> extractNodeTags(Map<String, dynamic> merged) {
  const excluded = <String>{'auto', 'proxy', 'direct', 'dns-out'};
  final outbounds = merged['outbounds'];
  if (outbounds is! List) return const <String>[];
  return outbounds
      .whereType<Map<String, dynamic>>()
      .map((e) => e['tag'] as String?)
      .where((tag) => tag != null && tag.isNotEmpty && !excluded.contains(tag))
      .cast<String>()
      .toList();
}

/// True when the merged config has at least one real node outbound.
/// False means the plan is expired (or the account has no nodes): the
/// client must show "套餐已过期，请续费" and must NOT start a tunnel.
bool hasNodes(Map<String, dynamic> merged) =>
    extractNodeTags(merged).isNotEmpty;

dynamic _deepCopy(dynamic value) {
  if (value == null) return null;
  return jsonDecode(jsonEncode(value));
}

Map<String, dynamic> _deepCopyMap(dynamic value) {
  final copied = _deepCopy(value);
  if (copied is Map<String, dynamic>) return copied;
  if (copied is Map) return Map<String, dynamic>.from(copied);
  return <String, dynamic>{};
}

List<dynamic> _deepCopyList(dynamic value) {
  final copied = _deepCopy(value);
  if (copied is List) return List<dynamic>.from(copied);
  return <dynamic>[];
}
