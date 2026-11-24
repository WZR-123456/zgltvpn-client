import 'package:flutter_test/flutter_test.dart';
import 'package:zgltvpn/core/models/userinfo.dart';

void main() {
  group('UserinfoHeader.parse', () {
    test('parses a full header', () {
      final header = UserinfoHeader.parse(
        'upload=0; download=123456; total=10737418240; expire=1795555200',
      );
      expect(header.upload, 0);
      expect(header.download, 123456);
      expect(header.total, 10737418240);
      expect(header.expire, 1795555200);
    });

    test('tolerates spaces and unknown keys', () {
      final header = UserinfoHeader.parse(
        'upload = 0 ; download=42; total=100; expire=7; extra=zzz',
      );
      expect(header.download, 42);
      expect(header.total, 100);
      expect(header.expire, 7);
    });

    test('empty or null header yields zeros', () {
      expect(UserinfoHeader.parse(null).total, 0);
      expect(UserinfoHeader.parse('').download, 0);
      expect(UserinfoHeader.parse('garbage').expire, 0);
    });

    test('non-numeric values fall back to zero', () {
      final header = UserinfoHeader.parse('download=abc; total=10');
      expect(header.download, 0);
      expect(header.total, 10);
    });
  });
}
