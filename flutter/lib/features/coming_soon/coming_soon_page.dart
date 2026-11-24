import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Honest "not built yet" destination (NORTH Phase 4 unlock).
///
/// Every previously-locked action now leads here instead of sitting
/// disabled: the page names the feature and says plainly what is
/// missing. It never claims the feature works and never shows fake
/// data — the back button is the only way out.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.feature, this.detail});

  /// Feature name, e.g. 'VPN 连接'. Shown as the title and in the
  /// "$feature即将上线" headline.
  final String feature;

  /// One honest sentence about what is missing. When null a generic
  /// line is shown.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(feature, style: textTheme.titleMedium)),
      body: ComingSoonBody(feature: feature, detail: detail),
    );
  }
}

/// The centered body of [ComingSoonPage], reusable where a full page
/// cannot be pushed — the home 消息 tab renders it inline.
class ComingSoonBody extends StatelessWidget {
  const ComingSoonBody({super.key, required this.feature, this.detail});

  final String feature;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // The icon uses the helper-text token when the app theme provides
    // it; without the Zglt theme (e.g. a bare MaterialApp in tests) it
    // falls back to a muted on-surface colour instead of crashing.
    final extra = Theme.of(context).extension<ZgltExtraColors>();
    final iconColor =
        extra?.text3 ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top_outlined, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text('$feature即将上线', style: textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              detail ?? '该功能在后续版本中上线，当前版本不会假装它已可用。',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pushes a [ComingSoonPage] for [feature] onto the navigator.
void openComingSoon(
  BuildContext context, {
  required String feature,
  String? detail,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ComingSoonPage(feature: feature, detail: detail),
    ),
  );
}
