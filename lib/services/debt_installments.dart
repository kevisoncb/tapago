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
/// [firstDue] é o primeiro vencimento. As demais datas avançam [intervalDays]
/// dias de calendário, preservando a data mesmo em mudanças de horário de
/// verão. Não há aplicação de juros ou recebimento automático.
List<DebtInstallment> splitReceivable({
  required double total,
  required DateTime firstDue,
  required int installments,
  int intervalDays = 30,
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
  if (intervalDays < 1 || intervalDays > 365) {
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
        vencimento: DateTime(
          firstDue.year,
          firstDue.month,
          firstDue.day + i * intervalDays,
        ),
      ),
  ]);
}
