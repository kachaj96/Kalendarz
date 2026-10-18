import 'dart:math';

/// Bez znaków mylących się na ekranie: I, O, 0, 1.
const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const inviteCodeLength = 8;
const _prefix = 'KAL';

String generateInviteCode([Random? random]) {
  final rnd = random ?? Random.secure();
  return List.generate(
    inviteCodeLength,
    (_) => _alphabet[rnd.nextInt(_alphabet.length)],
  ).join();
}

/// KAL-ABCD-EFGH, tak kod widzi użytkownik.
String formatInviteCode(String code) =>
    '$_prefix-${code.substring(0, 4)}-${code.substring(4)}';

/// Przyjmuje kod wpisany ręcznie: małe litery, myślniki, spacje, opcjonalny prefiks KAL.
/// Zwraca null, jeśli wynik nie wygląda jak kod.
String? normalizeInviteCode(String input) {
  var s = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (s.length == inviteCodeLength + _prefix.length && s.startsWith(_prefix)) {
    s = s.substring(_prefix.length);
  }
  if (s.length != inviteCodeLength) return null;
  if (s.split('').any((c) => !_alphabet.contains(c))) return null;
  return s;
}
