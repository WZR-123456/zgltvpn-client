// ignore_for_file: prefer_initializing_formals
// The constructor keeps public named parameters (authApi:, catalogApi:, …)
// so call sites read clearly; initializing formals would force private
// parameter names that callers in other libraries cannot use.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/auth_api.dart';
import '../../core/api/catalog_api.dart';
import '../../core/api/subscription_api.dart';
import '../../core/models/node.dart';
import '../../core/models/user.dart';
import '../../core/models/userinfo.dart';
import '../../core/storage/secure_storage.dart';

/// Home state. Membership/traffic come only from the server
/// (architecture §4.4): a failed refresh keeps the last-known values and
/// marks the page stale — it never flips the membership to "expired".
class HomeState {
  const HomeState({
    this.user,
    this.nodes = const <Node>[],
    this.nodeTags = const <String>[],
    this.userinfo,
    this.lastSync,
    this.isRefreshing = false,
    this.error,
    this.offline = false,
    this.subscriptionNote,
  });

  final User? user;
  final List<Node> nodes;
  final List<String> nodeTags;
  final UserinfoHeader? userinfo;
  final DateTime? lastSync;
  final bool isRefreshing;

  /// Last sync error, shown in an error block when there is no data yet.
  final String? error;

  /// True when data is shown from the last successful sync.
  final bool offline;

  /// Non-fatal subscription note ("订阅未更新…", "套餐已过期，请续费").
  final String? subscriptionNote;

  HomeState copyWith({
    User? user,
    List<Node>? nodes,
    List<String>? nodeTags,
    UserinfoHeader? userinfo,
    DateTime? lastSync,
    bool? isRefreshing,
    String? error,
    bool? offline,
    String? subscriptionNote,
  }) {
    return HomeState(
      user: user ?? this.user,
      nodes: nodes ?? this.nodes,
      nodeTags: nodeTags ?? this.nodeTags,
      userinfo: userinfo ?? this.userinfo,
      lastSync: lastSync ?? this.lastSync,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      offline: offline ?? this.offline,
      subscriptionNote: subscriptionNote,
    );
  }
}

class HomeController extends StateNotifier<HomeState> {
  HomeController({
    required AuthApi authApi,
    required CatalogApi catalogApi,
    required SubscriptionApi subscriptionApi,
    required SecureStorage storage,
    required Future<void> Function() onUnauthorized,
  }) : _authApi = authApi,
       _catalogApi = catalogApi,
       _subscriptionApi = subscriptionApi,
       _storage = storage,
       _onUnauthorized = onUnauthorized,
       super(const HomeState());

  final AuthApi _authApi;
  final CatalogApi _catalogApi;
  final SubscriptionApi _subscriptionApi;
  final SecureStorage _storage;
  final Future<void> Function() _onUnauthorized;

  /// Full sync: /api/me + /api/nodes + subscription fetch+merge.
  /// Also used by the "刷新订阅" quick action.
  Future<void> refresh() async {
    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, error: null);
    try {
      final user = await _authApi.me();
      final nodes = await _catalogApi.nodes();
      final subscription = await _fetchSubscription();
      state = state.copyWith(
        user: user,
        nodes: nodes,
        nodeTags: subscription.nodeTags,
        userinfo: subscription.userinfo,
        lastSync: DateTime.now(),
        isRefreshing: false,
        offline: false,
        subscriptionNote: subscription.note,
      );
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.unauthorized ||
          e.kind == ApiErrorKind.forbidden) {
        state = state.copyWith(isRefreshing: false);
        await _onUnauthorized();
        return;
      }
      // Keep last-known data, mark stale — never flip membership to expired.
      state = state.copyWith(
        isRefreshing: false,
        error: e.message,
        offline: state.user != null,
      );
    } catch (_) {
      state = state.copyWith(
        isRefreshing: false,
        error: '同步失败，请重试',
        offline: state.user != null,
      );
    }
  }

  /// Subscription fetch+merge only. Failures are non-fatal: the previous
  /// merged config (if any) keeps working and a note is shown.
  Future<({List<String> nodeTags, UserinfoHeader? userinfo, String? note})>
  _fetchSubscription() async {
    final subToken = await _storage.readSubToken();
    if (subToken == null || subToken.isEmpty) {
      return (nodeTags: state.nodeTags, userinfo: state.userinfo, note: null);
    }
    try {
      final result = await _subscriptionApi.fetchMerged(subToken: subToken);
      return (
        nodeTags: result.nodeTags,
        userinfo: result.userinfo,
        note: result.hasNodes ? null : '套餐已过期，请续费',
      );
    } on ApiException catch (e) {
      return (
        nodeTags: state.nodeTags,
        userinfo: state.userinfo,
        note: '订阅未更新：${e.message}',
      );
    } catch (_) {
      return (
        nodeTags: state.nodeTags,
        userinfo: state.userinfo,
        note: '订阅未更新',
      );
    }
  }
}
