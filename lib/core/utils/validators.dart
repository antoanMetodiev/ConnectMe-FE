class Validators {
  Validators._();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Въведи имейл.';
    if (!_emailPattern.hasMatch(v)) return 'Невалиден имейл.';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Въведи парола.';
    if (v.length < 6) return 'Поне 6 символа.';
    return null;
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Въведи име.';
    return null;
  }
}
