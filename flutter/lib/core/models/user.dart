/// User model — field names follow the backend exactly (architecture §4.2).
///
/// Traffic values come from the backend in bytes. The backend currently
/// carries dirty data (free plan `traffic_gb = 1e+97`); values above the
/// safe range are clamped to a sentinel so the UI can detect and label them
/// instead of crashing or showing a nonsense number (architecture §4.5).
class User {
  const User({
    required this.email,
    required this.name,
    required this.balance,
    required this.expires,
    required this.trafficTotal,
    required this.trafficUsed,
    required this.plans,
    required this.subToken,
    this.planId,
    this.planName,
    this.totpEnabled = false,
    this.inviteCount = 0,
    this.invitePaidCount = 0,
    this.rebateEarned = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final plansJson = json['plans'];
    return User(
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      balance: _toDouble(json['balance']),
      expires: _toInt(json['expires']),
      trafficTotal: _toIntClamped(json['traffic_total']),
      trafficUsed: _toIntClamped(json['traffic_used']),
      plans: plansJson is List
          ? plansJson
                .whereType<Map<String, dynamic>>()
                .map(UserPlan.fromJson)
                .toList()
          : const <UserPlan>[],
      subToken: json['sub_token'] as String? ?? '',
      planId: json['plan_id'] as String?,
      planName: json['plan_name'] as String?,
      totpEnabled: json['totp_enabled'] as bool? ?? false,
      inviteCount: (json['invite_count'] as num?)?.toInt() ?? 0,
      invitePaidCount: (json['invite_paid_count'] as num?)?.toInt() ?? 0,
      rebateEarned: _toDouble(json['rebate_earned']),
    );
  }

  /// Email (login name).
  final String email;

  /// Display name.
  final String name;

  /// Wallet balance (CNY).
  final double balance;

  /// Current plan expiry, milliseconds since epoch. 0 = no active plan.
  final int expires;

  /// Total traffic, bytes (clamped — see [Format.isDirtyTraffic]).
  final int trafficTotal;

  /// Used traffic, bytes.
  final int trafficUsed;

  /// All plans held by the user (multi-plan stacking).
  final List<UserPlan> plans;

  /// Subscription token (28 chars). Treat like a password.
  final String subToken;

  final String? planId;
  final String? planName;
  final bool totpEnabled;

  /// People who registered with this user as inviter (from /api/me).
  final int inviteCount;

  /// Of those, how many have bought a plan (from /api/me).
  final int invitePaidCount;

  /// Total invite rebate earned, CNY (from /api/me).
  final double rebateEarned;

  bool get hasActivePlan => expires > 0;

  /// Primary plan (first in [plans], falling back to the top-level fields).
  UserPlan? get primaryPlan => plans.isNotEmpty ? plans.first : null;

  /// Display name of the current plan, or empty when there is none.
  String get planDisplayName {
    if (primaryPlan != null && primaryPlan!.planName.isNotEmpty) {
      return primaryPlan!.planName;
    }
    return planName ?? '';
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return 0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  /// Parses a byte count; values beyond the safe int range (backend dirty
  /// data such as 1e+97) become [_dirtySentinel], which the UI detects.
  static int _toIntClamped(dynamic value) {
    if (value is int) return value;
    if (value is num) {
      if (value.isInfinite || value.isNaN) return _dirtySentinel;
      if (value > _maxSafeInt) return _dirtySentinel;
      return value.toInt();
    }
    return 0;
  }

  /// Largest exactly-representable integer (2^53 - 1).
  static const int _maxSafeInt = 9007199254740991;

  /// Sentinel for dirty/astronomical traffic values (2^62).
  static const int _dirtySentinel = 1 << 62;
}

/// One plan entry inside [User.plans].
class UserPlan {
  const UserPlan({
    required this.planId,
    required this.planName,
    required this.expires,
    required this.trafficGb,
  });

  factory UserPlan.fromJson(Map<String, dynamic> json) {
    return UserPlan(
      planId: json['planId'] as String? ?? '',
      planName: json['planName'] as String? ?? '',
      expires: json['expires'] is int
          ? json['expires'] as int
          : (json['expires'] as num?)?.toInt() ?? 0,
      trafficGb: json['traffic_gb'] is num
          ? (json['traffic_gb'] as num).toDouble()
          : 0,
    );
  }

  final String planId;
  final String planName;

  /// Expiry, milliseconds since epoch.
  final int expires;

  /// Traffic allowance, GB (may be backend dirty data — see [Format]).
  final double trafficGb;
}
