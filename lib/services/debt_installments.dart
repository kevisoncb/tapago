/// Uma parcela de uma venda a prazo. O total é dividido em centavos inteiros;
/// qualquer diferença fica na última parcela.
class DebtInstallment {
  const DebtInstallment({
    required this.parcela,
    required this.totalParcelas,
    required this.valor,
    required this.vencimento,
  });

  final int parcela;
  final int totalParcelas;
  final double valor;
  final DateTime vencimento;
}

/// Divide o valor já combinado de uma venda em 2 a 12 parcelas não nulas.
///
/// [firstDue] é o primeiro vencimento. Por padrão as demais parcelas vencem
/// no mesmo dia dos meses seguintes; em meses mais curtos vale o último dia
/// (31/01 → 28/02 → 31/03). Com [intervalDays] as datas avançam essa
/// quantidade de dias corridos. Não há aplicação de juros nem recebimento
/// automático.
List<DebtInstallment> splitReceivable({
  required double total,
  required DateTime firstDue,
  required int installments,
  int? intervalDays,
}) {
  if (!total.isFinite || total <= 0 || total > 100000000) {
    throw ArgumentError.value(total, 'total', 'Informe um valor válido.');
  }
  if (installments < 2 || installments > 12) {
    throw ArgumentError.value(
      installments,
      'installments',
      'Use 2 a 12 parcelas.',
    );
  }
  if (intervalDays != null && (intervalDays < 1 || intervalDays > 365)) {
    throw ArgumentError.value(
      intervalDays,
      'intervalDays',
      'Use 1 a 365 dias.',
    );
  }
  final cents = (total * 100).round();
  if (cents < installments) {
    throw ArgumentError('Cada parcela precisa ter pelo menos R\$ 0,01.');
  }
  final each = cents ~/ installments;
  return List<DebtInstallment>.unmodifiable([
    for (var i = 0; i < installments; i++)
      DebtInstallment(
        parcela: i + 1,
        totalParcelas: installments,
        valor:
            (i == installments - 1 ? cents - each * (installments - 1) : each) /
            100,
        vencimento: intervalDays == null
            ? _sameDayOfMonth(firstDue, i)
            : DateTime(
                firstDue.year,
                firstDue.month,
                firstDue.day + i * intervalDays,
              ),
      ),
  ]);
}

/// Mesmo dia, [months] meses depois, limitado ao último dia do mês de destino.
DateTime _sameDayOfMonth(DateTime from, int months) {
  final target = DateTime(from.year, from.month + months);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(
    target.year,
    target.month,
    from.day > lastDay ? lastDay : from.day,
  );
}
