/// Display formatting + dirty-data clamping (architecture §4.5).
///
/// The backend currently carries dirty data (free plan `traffic_gb = 1e+97`,
/// `speed = "100000"`). The client never shows those numbers raw: anything
/// above the thresholds below is displayed as "不限量（数据异常）" and the
/// progress bar is hidden for that value.
class Format {
  Format._();

  /// Byte counts at or above this are backend dirty data (10^15 bytes).
  static const int dirtyTrafficThreshold = 1000000000000000;

  /// Plan traffic (GB) at or above this is backend dirty data.
  /// 10^6 GB == 10^15 bytes.
  static const double dirtyTrafficGbThreshold = 1000000;

  static bool isDirtyTraffic(int bytes) => bytes >= dirtyTrafficThreshold;

  static bool isDirtyTrafficGb(double gb) => gb >= dirtyTrafficGbThreshold;

  /// Formats a byte count, or the dirty-data label when it is absurd.
  static String bytes(int bytes) {
    if (bytes < 0) return '—';
    if (isDirtyTraffic(bytes)) return '不限量（数据异常）';
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  /// Formats a plan traffic allowance in GB.
  static String trafficGb(double gb) {
    if (gb < 0) return '—';
    if (isDirtyTrafficGb(gb)) return '不限量（数据异常）';
    if (gb == gb.truncateToDouble()) return '${gb.toInt()} GB';
    return '${gb.toStringAsFixed(1)} GB';
  }

  /// Formats an expiry timestamp (ms since epoch) as yyyy/MM/dd.
  /// Returns '未开通' for 0/negative values.
  static String expiry(int expiresMs) {
    if (expiresMs <= 0) return '未开通';
    final date = DateTime.fromMillisecondsSinceEpoch(expiresMs);
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Whole days remaining until [expiresMs]; negative when already expired.
  static int daysRemaining(int expiresMs) {
    if (expiresMs <= 0) return 0;
    final diff = DateTime.fromMillisecondsSinceEpoch(expiresMs)
        .difference(DateTime.now());
    return diff.inDays;
  }

  /// Formats a sync time as HH:MM (for the "已同步 HH:MM" badge).
  static String syncTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}
