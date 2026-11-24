import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'api/auth_api.dart';
import 'api/catalog_api.dart';
import 'api/subscription_api.dart';
import 'config/template_loader.dart';
import 'storage/secure_storage.dart';
import '../features/auth/auth_controller.dart';
import '../features/connection/home_controller.dart';
import '../platform/vpn/vpn_service.dart';

/// Riverpod providers. All API access flows through these; widgets never
/// construct an [ApiClient] or a storage object directly.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

final catalogApiProvider = Provider<CatalogApi>(
  (ref) => CatalogApi(ref.watch(apiClientProvider)),
);

final templateLoaderProvider = Provider<TemplateLoader>(
  (ref) => const TemplateLoader(),
);

final subscriptionApiProvider = Provider<SubscriptionApi>(
  (ref) => SubscriptionApi(
    ref.watch(apiClientProvider),
    templateLoader: ref.watch(templateLoaderProvider),
  ),
);

/// VPN core behind the plugin-agnostic interface (architecture §3.2).
/// Slice 1 wires the stub; the Phase 2.5 prototype swaps in the
/// `sing_box` plugin adapter without touching business code.
final vpnServiceProvider = Provider<VpnService>((ref) => StubVpnService());

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    ref.watch(authApiProvider),
    ref.watch(secureStorageProvider),
    ref.watch(apiClientProvider),
  ),
);

final homeControllerProvider = StateNotifierProvider<HomeController, HomeState>(
  (ref) => HomeController(
    authApi: ref.watch(authApiProvider),
    catalogApi: ref.watch(catalogApiProvider),
    subscriptionApi: ref.watch(subscriptionApiProvider),
    storage: ref.watch(secureStorageProvider),
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
  ),
);
