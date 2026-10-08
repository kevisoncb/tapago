import 'package:flutter/services.dart';

import 'boleto_code.dart';
import 'masks.dart';

class _FnMaskFormatter extends TextInputFormatter {
  _FnMaskFormatter(this.format);

  final String Function(String value) format;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = format(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class PhoneMaskFormatter extends _FnMaskFormatter {
  PhoneMaskFormatter() : super(formatPhoneBr);
}

class CpfCnpjMaskFormatter extends _FnMaskFormatter {
  CpfCnpjMaskFormatter() : super(formatCpfCnpj);
}

class CnpjMaskFormatter extends _FnMaskFormatter {
  CnpjMaskFormatter() : super(formatCnpj);
}

class BoletoCodeMaskFormatter extends _FnMaskFormatter {
  BoletoCodeMaskFormatter() : super(formatBoletoCode);
}

class MoneyMaskFormatter extends _FnMaskFormatter {
  MoneyMaskFormatter() : super(formatMoneyInput);
}

class PercentMaskFormatter extends _FnMaskFormatter {
  PercentMaskFormatter() : super(formatPercentInput);
}

class DateMaskFormatter extends _FnMaskFormatter {
  DateMaskFormatter() : super(formatDateBr);
}

class AgencyMaskFormatter extends _FnMaskFormatter {
  AgencyMaskFormatter() : super(formatAgency);
}

class AccountMaskFormatter extends _FnMaskFormatter {
  AccountMaskFormatter() : super(formatAccount);
}

class PixMaskFormatter extends _FnMaskFormatter {
  PixMaskFormatter() : super(formatPixKey);
}

class EmailMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = sanitizeEmail(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class NameMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text.replaceAll(
      RegExp(r"[^A-Za-zÀ-ÿ'\- ]"),
      '',
    );
    if (filtered.length > 80) {
      return oldValue;
    }
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}

class NoSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\s'), '');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
