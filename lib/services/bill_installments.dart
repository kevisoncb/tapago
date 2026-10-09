class BillInstallment {
  const BillInstallment({
    required this.parcela,
    required this.valor,
    required this.vencimento,
  });

  final int parcela;
  final double valor;
  final DateTime vencimento;
}

const billPresets = <List<int>>[
  [15, 30, 45],
  [30, 45, 60],
  [30, 60, 90],
];

/// Só números. Vazio é aceito; preenchido precisa ter 44 a 48 dígitos (barras ou linha digitável).
String? normalizeBoletoCode(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.length < 44 || digits.length > 48) return null;
  return digits;
}

String prazosLabel(List<int> prazos) => prazos.join('/');

/// Lê "30/60/90", "30 60 90" ou "30,60,90". Prazos em dias, crescentes, 1 a 12 parcelas.
List<int>? parsePrazos(String raw) {
  final parts = raw
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.isNotEmpty)
      .map(int.parse)
      .toList();
  if (parts.isEmpty || parts.length > 12) return null;
  for (var i = 0; i < parts.length; i++) {
    if (parts[i] <= 0 || parts[i] > 720) return null;
    if (i > 0 && parts[i] <= parts[i - 1]) return null;
  }
  return parts;
}

/// Divide em centavos; a diferença do arredondamento fica na última parcela.
List<BillInstallment> splitBill({
  required double total,
  required DateTime base,
  required List<int> prazos,
}) {
  if (prazos.isEmpty || total <= 0) return const [];
  final cents = (total * 100).round();
  final each = cents ~/ prazos.length;
  return [
    for (var i = 0; i < prazos.length; i++)
      BillInstallment(
        parcela: i + 1,
        valor: (i == prazos.length - 1
                ? cents - each * (prazos.length - 1)
                : each) /
            100,
        vencimento: DateTime(base.year, base.month, base.day + prazos[i]),
      ),
  ];
}
