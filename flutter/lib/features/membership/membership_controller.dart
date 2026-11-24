import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/catalog_api.dart';
import '../../core/models/plan.dart';
import '../../core/providers.dart';

/// Billing period for the plan list (phase 3 §5.7: 月/季/年切换）.
enum MembershipPeriod {
  month('月'),
  quarter('季'),
  year('年');

  const MembershipPeriod(this.label);

  /// Segment label (also the price suffix, e.g. `¥10/月`).
  final String label;

  /// Price of [prices] for this period, or null when the plan has no
  /// price for the period (shown as "—", never a made-up price).
  double? priceOf(PlanPrices prices) {
    switch (this) {
      case MembershipPeriod.month:
        return prices.month;
      case MembershipPeriod.quarter:
        return prices.quarter;
      case MembershipPeriod.year:
        return prices.year;
    }
  }
}

/// Price of [plan] for [period], or null when the plan has no price
/// for that period.
double? priceForPeriod(Plan plan, MembershipPeriod period) =>
    period.priceOf(plan.prices);

/// Formats a plan price for display: `¥10`, `¥10.5`, or "—" when the
/// plan has no price for the selected period.
String formatPrice(double? price) {
  if (price == null) return '—';
  if (price == price.truncateToDouble()) return '¥${price.toInt()}';
  return '¥${price.toStringAsFixed(2)}';
}

/// Displays a plan speed limit, or "—" when the backend has none.
/// A bare number at or above 10000 is backend dirty data (the known
/// `speed = "100000"` case, see Format) — never shown raw. Non-numeric
/// values (e.g. "100Mbps") are shown as stored.
String displaySpeed(String? speed) {
  if (speed == null || speed.isEmpty) return '—';
  final numeric = double.tryParse(speed);
  if (numeric != null && numeric >= 10000) return '—';
  return speed;
}

/// True when the plan expires within 7 days (and has not expired yet):
/// the amber reminder bar shows (phase 3 §5.7, "到期前 7 天显示琥珀提醒条").
bool shouldShowExpiryReminder(int expiresMs, {DateTime? now}) {
  if (expiresMs <= 0) return false;
  final current = now ?? DateTime.now();
  final days = DateTime.fromMillisecondsSinceEpoch(expiresMs)
      .difference(current)
      .inDays;
  return days >= 0 && days <= 7;
}

/// Membership state: the enabled plan list from [CatalogApi.plans].
class MembershipState {
  const MembershipState({
    this.plans = const <Plan>[],
    this.isLoading = false,
    this.error,
    this.offline = false,
    this.selectedPeriod = MembershipPeriod.month,
  });

  /// Enabled plans only (disabled plans are filtered out on load).
  final List<Plan> plans;

  final bool isLoading;

  /// Load error, shown as "套餐信息加载失败，请重试" when there is no
  /// cached list yet. Null when the list loaded (or is cached).
  final String? error;

  /// True when the list is shown from the last successful load after a
  /// network failure.
  final bool offline;

  final MembershipPeriod selectedPeriod;

  MembershipState copyWith({
    List<Plan>? plans,
    bool? isLoading,
    String? error,
    bool? offline,
    MembershipPeriod? selectedPeriod,
    bool clearError = false,
  }) {
    return MembershipState(
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      offline: offline ?? this.offline,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
    );
  }
}

class MembershipController extends StateNotifier<MembershipState> {
  MembershipController(this._catalogApi)
    : super(const MembershipState(isLoading: true));

  final CatalogApi _catalogApi;
  bool _loading = false;

  /// Loads the enabled plan list. A failure keeps the last-known list
  /// (if any) and marks it stale; with no list yet it shows the error
  /// state. Network failures also set [MembershipState.offline].
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final plans = await _catalogApi.plans();
      state = state.copyWith(
        plans: plans.where((plan) => plan.enabled).toList(),
        isLoading: false,
        offline: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: state.plans.isEmpty ? '套餐信息加载失败，请重试' : null,
        offline: e.kind == ApiErrorKind.network,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: state.plans.isEmpty ? '套餐信息加载失败，请重试' : null,
      );
    } finally {
      _loading = false;
    }
  }

  void selectPeriod(MembershipPeriod period) {
    if (period == state.selectedPeriod) return;
    state = state.copyWith(selectedPeriod: period);
  }
}

final membershipControllerProvider =
    StateNotifierProvider<MembershipController, MembershipState>(
      (ref) => MembershipController(ref.watch(catalogApiProvider))..load(),
    );
