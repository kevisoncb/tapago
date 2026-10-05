import 'package:intl/intl.dart';

class Money {
  static final _full = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$',
    decimalDigits: 2,
  );

  static String full(num value) => _full.format(value);

  static String compact(num value) {
    return NumberFormat.currency(
      locale: 'pt_BR',
      symbol: r'R$',
      decimalDigits: 0,
    ).format(value.round());
  }
}

class Dates {
  static final _short = DateFormat('dd/MM/yy', 'pt_BR');
  static final _dayMonth = DateFormat("dd MMM yyyy", 'pt_BR');
  static final _full = DateFormat('dd/MM/yyyy', 'pt_BR');

  static String due(DateTime date) => _short.format(date);

  static String history(DateTime date) {
    final raw = _dayMonth.format(date);
    return raw
        .replaceAll('.', '')
        .split(' ')
        .map((part) {
          if (part.length >= 3 && part.contains(RegExp(r'[A-Za-z]'))) {
            return '${part[0].toUpperCase()}${part.substring(1)}';
          }
          return part;
        })
        .join(' ');
  }

  static String full(DateTime date) => _full.format(date);
}

String firstNameOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return name;
  return parts.first;
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

String paymentKindLabel(String descricao) {
  switch (descricao) {
    case 'Juros':
      return 'Somente juros do mês';
    case 'Abatimento':
      return 'Parte do valor';
    case 'Quitação':
      return 'Valor total';
    default:
      return descricao;
  }
}

String paymentKindHint(String descricao) {
  switch (descricao) {
    case 'Juros':
      return 'Não baixa o principal';
    case 'Abatimento':
      return 'Baixa juros e depois o principal';
    case 'Quitação':
      return 'Caderneta quitada';
    default:
      return '';
  }
}
