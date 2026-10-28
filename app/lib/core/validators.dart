/// Input checks shared by the forms; the server repeats them (functions/src/core/schedule.js).
abstract final class Validators {
  static bool name(String v) => v.trim().length >= 2 && v.trim().length <= 80;

  static bool phone(String v) => RegExp(r'^\+?\d{7,15}$').hasMatch(v.replaceAll(RegExp(r'[\s\-().]'), ''));

  static bool email(String v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()) && v.trim().length <= 120;

  static bool optionalEmail(String v) => v.trim().isEmpty || email(v);

  static bool password(String v) => v.length >= 8;

  static bool bookingRef(String v) => RegExp(r'^[A-Za-z2-9]{6}$').hasMatch(v.trim());
}
