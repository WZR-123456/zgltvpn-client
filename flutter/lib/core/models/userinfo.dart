/// Parsed `subscription-userinfo` response header.
///
/// Format: `upload=0; download=used bytes; total=total bytes;
/// expire=expiry unix seconds`. All four subscription formats carry it.
/// Byte values are clamped like the user model (backend dirty data).
class UserinfoHeader {
  const UserinfoHeader({
    required this.upload,
    required this.download,
    required this.total,
    required this.expire,
  });

  factory UserinfoHeader.parse(String? header) {
    if (header == null || header.isEmpty) {
      return const UserinfoHeader(upload: 0, download: 0, total: 0, expire: 0);
    }
    var upload = 0;
    var download = 0;
    var total = 0;
    var expire = 0;
    for (final part in header.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length != 2) continue;
      final value = int.tryParse(kv[1].trim()) ?? 0;
      switch (kv[0].trim()) {
        case 'upload':
          upload = value;
        case 'download':
          download = value;
        case 'total':
          total = value;
        case 'expire':
          expire = value;
      }
    }
    return UserinfoHeader(
      upload: upload,
      download: download,
      total: total,
      expire: expire,
    );
  }

  /// Uploaded bytes (always 0 from this backend).
  final int upload;

  /// Used bytes.
  final int download;

  /// Total bytes (may be backend dirty data — see [Format]).
  final int total;

  /// Expiry, unix seconds.
  final int expire;
}
