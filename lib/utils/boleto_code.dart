import 'formatters.dart';

/// Dados que dá pra tirar do código do boleto sem consultar banco.
class BoletoCodeInfo {
  const BoletoCodeInfo({this.valor, this.vencimento});

  final double? valor;
  final DateTime? vencimento;
}

/// Boleto bancário: 47 dígitos (linha) ou 44 (barras).
/// Conta de consumo / tributo (começa com 8): 48 dígitos (linha) ou 44 (barras).
bool isBoletoArrecadacao(String digits) => digits.startsWith('8');

bool isValidBoletoCode(String value) {
  final digits = digitsOnly(value);
  if (digits.length == 44) return true;
  if (isBoletoArrecadacao(digits)) return digits.length == 48;
  return digits.length == 47;
}

String formatBoletoCode(String value) {
  final raw = digitsOnly(value);
  final arrecadacao = isBoletoArrecadacao(raw);
  final max = arrecadacao ? 48 : 47;
  final digits = raw.length > max ? raw.substring(0, max) : raw;
  final seps = arrecadacao ? _arrecadacaoSeps : _bancarioSeps;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final sep = seps[i];
    if (i > 0 && sep != null) buffer.write(sep);
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

const _bancarioSeps = {
  5: '.',
  10: ' ',
  15: '.',
  21: ' ',
  26: '.',
  32: ' ',
  33: ' ',
};

const _arrecadacaoSeps = {
  11: '-',
  12: ' ',
  23: '-',
  24: ' ',
  35: '-',
  36: ' ',
  47: '-',
};

BoletoCodeInfo? readBoletoCode(String value) {
  final digits = digitsOnly(value);
  if (isBoletoArrecadacao(digits)) {
    final String barcode;
    if (digits.length == 48) {
      barcode = digits.substring(0, 11) +
          digits.substring(12, 23) +
          digits.substring(24, 35) +
          digits.substring(36, 47);
    } else if (digits.length == 44) {
      barcode = digits;
    } else {
      return null;
    }
    final valorEmReais = barcode[2] == '6' || barcode[2] == '8';
    if (!valorEmReais) return const BoletoCodeInfo();
    return BoletoCodeInfo(valor: _cents(barcode.substring(4, 15)));
  }

  final String fator;
  final String valor;
  if (digits.length == 47) {
    fator = digits.substring(33, 37);
    valor = digits.substring(37, 47);
  } else if (digits.length == 44) {
    fator = digits.substring(5, 9);
    valor = digits.substring(9, 19);
  } else {
    return null;
  }
  return BoletoCodeInfo(
    valor: _cents(valor),
    vencimento: boletoDueFromFactor(int.parse(fator)),
  );
}

/// Fator de vencimento FEBRABAN. Voltou a 1000 em 22/02/2025.
DateTime? boletoDueFromFactor(int fator) {
  if (fator < 1000) return null;
  return DateTime(2025, 2, 22 + (fator - 1000));
}

double? _cents(String digits) {
  final cents = int.tryParse(digits) ?? 0;
  if (cents <= 0) return null;
  return cents / 100;
}
