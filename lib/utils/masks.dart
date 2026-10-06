import 'formatters.dart';

String sanitizeEmail(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s'), '');
}

String formatPhoneBr(String value) {
  final digits = digitsOnly(value).substring(
    0,
    digitsOnly(value).length > 11 ? 11 : digitsOnly(value).length,
  );
  if (digits.isEmpty) return '';
  if (digits.length <= 2) return '($digits';
  if (digits.length <= 6) {
    return '(${digits.substring(0, 2)}) ${digits.substring(2)}';
  }
  if (digits.length <= 10) {
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
  }
  return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
}

String formatCpf(String value) {
  final digits = _takeDigits(value, 11);
  if (digits.length <= 3) return digits;
  if (digits.length <= 6) {
    return '${digits.substring(0, 3)}.${digits.substring(3)}';
  }
  if (digits.length <= 9) {
    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6)}';
  }
  return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
}

String formatCnpj(String value) {
  final digits = _takeDigits(value, 14);
  if (digits.length <= 2) return digits;
  if (digits.length <= 5) {
    return '${digits.substring(0, 2)}.${digits.substring(2)}';
  }
  if (digits.length <= 8) {
    return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5)}';
  }
  if (digits.length <= 12) {
    return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8)}';
  }
  return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8, 12)}-${digits.substring(12)}';
}

String formatCpfCnpj(String value) {
  final digits = _takeDigits(value, 14);
  if (digits.length <= 11) return formatCpf(digits);
  return formatCnpj(digits);
}

String formatMoneyInput(String value) {
  final digits = _takeDigits(value, 11);
  if (digits.isEmpty) return '';
  final cents = int.parse(digits);
  return Money.full(cents / 100);
}

double parseMoneyInput(String value) {
  final digits = digitsOnly(value);
  if (digits.isEmpty) return 0;
  return int.parse(digits) / 100;
}

String formatPercentInput(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^0-9,]'), '');
  final comma = cleaned.indexOf(',');
  final wholeRaw = comma == -1 ? cleaned : cleaned.substring(0, comma);
  final fracRaw = comma == -1 ? '' : cleaned.substring(comma + 1);
  final whole = _takeDigits(wholeRaw, 3);
  if (comma == -1) return whole;
  return '$whole,${_takeDigits(fracRaw, 2)}';
}

double parsePercentInput(String value) {
  final normalized = value.trim().replaceAll('%', '').replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(normalized) ?? 0;
}

String formatDateBr(String value) {
  final digits = _takeDigits(value, 8);
  if (digits.length <= 2) return digits;
  if (digits.length <= 4) {
    return '${digits.substring(0, 2)}/${digits.substring(2)}';
  }
  return '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4)}';
}

DateTime? parseDateBr(String value) {
  final digits = digitsOnly(value);
  if (digits.length != 8) return null;
  final day = int.tryParse(digits.substring(0, 2));
  final month = int.tryParse(digits.substring(2, 4));
  final year = int.tryParse(digits.substring(4));
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  if (date.day != day || date.month != month) return null;
  return date;
}

String formatAgency(String value) {
  final digits = _takeDigits(value, 5);
  if (digits.length <= 4) return digits;
  return '${digits.substring(0, 4)}-${digits.substring(4)}';
}

String formatAccount(String value) {
  final digits = _takeDigits(value, 12);
  if (digits.length <= 1) return digits;
  return '${digits.substring(0, digits.length - 1)}-${digits.substring(digits.length - 1)}';
}

String formatUuid(String value) {
  final hex = value.replaceAll(RegExp(r'[^a-fA-F0-9]'), '').toLowerCase();
  final clipped = hex.length > 32 ? hex.substring(0, 32) : hex;
  if (clipped.length <= 8) return clipped;
  if (clipped.length <= 12) {
    return '${clipped.substring(0, 8)}-${clipped.substring(8)}';
  }
  if (clipped.length <= 16) {
    return '${clipped.substring(0, 8)}-${clipped.substring(8, 12)}-${clipped.substring(12)}';
  }
  if (clipped.length <= 20) {
    return '${clipped.substring(0, 8)}-${clipped.substring(8, 12)}-${clipped.substring(12, 16)}-${clipped.substring(16)}';
  }
  return '${clipped.substring(0, 8)}-${clipped.substring(8, 12)}-${clipped.substring(12, 16)}-${clipped.substring(16, 20)}-${clipped.substring(20)}';
}

String formatPixKey(String value) {
  final trimmed = value.trim();
  if (trimmed.contains('@')) return sanitizeEmail(trimmed);
  if (RegExp(r'[A-Za-z]').hasMatch(trimmed)) return formatUuid(trimmed);
  final digits = _takeDigits(trimmed, 14);
  if (digits.length <= 11) {
    if (_looksLikePhone(digits)) return formatPhoneBr(digits);
    return formatCpf(digits);
  }
  return formatCnpj(digits);
}

bool _looksLikePhone(String digits) {
  if (digits.length == 10) return true;
  if (digits.length == 11) return digits[2] == '9';
  return false;
}

bool isValidPhoneBr(String value) {
  final digits = digitsOnly(value);
  return digits.length == 10 || digits.length == 11;
}

bool isValidCpf(String value) {
  final digits = digitsOnly(value);
  if (digits.length != 11) return false;
  if (RegExp(r'^(\d)\1+$').hasMatch(digits)) return false;
  final numbers = digits.split('').map(int.parse).toList();
  var sum = 0;
  for (var i = 0; i < 9; i++) {
    sum += numbers[i] * (10 - i);
  }
  var dv1 = (sum * 10) % 11;
  if (dv1 == 10) dv1 = 0;
  if (dv1 != numbers[9]) return false;
  sum = 0;
  for (var i = 0; i < 10; i++) {
    sum += numbers[i] * (11 - i);
  }
  var dv2 = (sum * 10) % 11;
  if (dv2 == 10) dv2 = 0;
  return dv2 == numbers[10];
}

bool isValidCnpj(String value) {
  final digits = digitsOnly(value);
  if (digits.length != 14) return false;
  if (RegExp(r'^(\d)\1+$').hasMatch(digits)) return false;
  final numbers = digits.split('').map(int.parse).toList();
  const w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  const w2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += numbers[i] * w1[i];
  }
  var dv1 = sum % 11;
  dv1 = dv1 < 2 ? 0 : 11 - dv1;
  if (dv1 != numbers[12]) return false;
  sum = 0;
  for (var i = 0; i < 13; i++) {
    sum += numbers[i] * w2[i];
  }
  var dv2 = sum % 11;
  dv2 = dv2 < 2 ? 0 : 11 - dv2;
  return dv2 == numbers[13];
}

bool isValidCpfOrCnpj(String value) {
  final digits = digitsOnly(value);
  if (digits.length == 11) return isValidCpf(digits);
  if (digits.length == 14) return isValidCnpj(digits);
  return false;
}

bool isValidEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(sanitizeEmail(value));
}

/// Chave PIX: e-mail, celular, CPF/CNPJ (com dígito) ou chave aleatória.
bool isValidPixKey(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return true;
  if (trimmed.contains('@')) return isValidEmail(trimmed);
  if (RegExp(r'[A-Za-z]').hasMatch(trimmed)) {
    final hex = trimmed.replaceAll(RegExp(r'[^a-fA-F0-9]'), '');
    return hex.length == 32;
  }
  final digits = digitsOnly(trimmed);
  if (_looksLikePhone(digits)) return isValidPhoneBr(digits);
  if (digits.length == 11) return isValidCpf(digits);
  if (digits.length == 14) return isValidCnpj(digits);
  return false;
}

String _takeDigits(String value, int max) {
  final digits = digitsOnly(value);
  return digits.length > max ? digits.substring(0, max) : digits;
}
