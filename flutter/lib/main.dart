import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Entry point.
///
/// The VPN core (`sing_box` plugin) is NOT initialized here yet: the real
/// tunnel wiring lands with the Phase 2.5 prototype. Slice 1 wires only the
/// plugin-agnostic [VpnService] interface (stub implementation), so the home
/// shell never pretends to connect.
void main() {
  runApp(const ProviderScope(child: ZgltApp()));
}
