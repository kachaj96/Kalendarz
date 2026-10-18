import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalendarz/space/invite_code.dart';

void main() {
  group('generateInviteCode', () {
    test('ma 8 znaków z alfabetu bez I, O, 0, 1', () {
      final rnd = Random(1);
      for (var i = 0; i < 500; i++) {
        final code = generateInviteCode(rnd);
        expect(code.length, 8);
        expect(
          RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code),
          isTrue,
          reason: code,
        );
      }
    });

    test('kolejne kody się różnią', () {
      final rnd = Random(7);
      final codes = {for (var i = 0; i < 200; i++) generateInviteCode(rnd)};
      expect(codes.length, 200);
    });
  });

  group('formatInviteCode', () {
    test('dzieli kod na KAL-XXXX-XXXX', () {
      expect(formatInviteCode('ABCD2345'), 'KAL-ABCD-2345');
    });
  });

  group('normalizeInviteCode', () {
    test('przyjmuje kod w formacie wyświetlanym', () {
      expect(normalizeInviteCode('KAL-ABCD-2345'), 'ABCD2345');
    });

    test('ignoruje wielkość liter, spacje i myślniki', () {
      expect(normalizeInviteCode(' kal abcd 2345 '), 'ABCD2345');
      expect(normalizeInviteCode('abcd-2345'), 'ABCD2345');
    });

    test('kod zaczynający się od KAL bez prefiksu zostaje nietknięty', () {
      expect(normalizeInviteCode('KALM2345'), 'KALM2345');
    });

    test('odrzuca zły format', () {
      expect(normalizeInviteCode(''), isNull);
      expect(normalizeInviteCode('ABC'), isNull);
      expect(normalizeInviteCode('ABCD234'), isNull);
      expect(normalizeInviteCode('ABCD23456'), isNull);
    });

    test('odrzuca znaki spoza alfabetu (0, 1, I, O)', () {
      expect(normalizeInviteCode('ABCD2340'), isNull);
      expect(normalizeInviteCode('ABCD234I'), isNull);
    });

    test('kod wygenerowany przechodzi pełny obieg', () {
      final code = generateInviteCode(Random(3));
      expect(normalizeInviteCode(formatInviteCode(code)), code);
    });
  });
}
