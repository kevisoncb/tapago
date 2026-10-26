import '../models/models.dart';
import 'debt_balance.dart';

/// A statement reflects entries recorded by the merchant. It is not a bank
/// confirmation and never infers payment from an image or a WhatsApp message.
class CustomerStatement {
  const CustomerStatement({
    required this.name,
    required this.phone,
    required this.generatedAt,
    required this.debts,
    required this.payments,
    required this.entries,
    required this.contractedCents,
    required this.receivedCents,
    required this.balanceCents,
    required this.legacyAdjustmentCents,
  });

  final String name;
  final String phone;
  final DateTime generatedAt;
  final List<Debt> debts;
  final List<Payment> payments;
  final List<StatementEntry> entries;
  final int contractedCents;
  final int receivedCents;
  final int balanceCents;

  /// Difference between the recorded ledger and historical paid flags. Kept
  /// explicit so old manually-settled records do not look like bank payments.
  final int legacyAdjustmentCents;

  static CustomerStatement build({
    required String name,
    required String phone,
    required Iterable<Debt> debts,
    required Iterable<Payment> payments,
    DateTime? generatedAt,
  }) {
    final loans = debts.toList(growable: false);
    final ids = loans.map((debt) => debt.id).toSet();
    final ledger = payments
        .where((payment) => ids.contains(payment.debtId))
        .toList(growable: false);
    final byId = {for (final debt in loans) debt.id: debt};
    var contracted = 0;
    var balance = 0;
    final entries = <StatementEntry>[];
    for (final debt in loans) {
      final debtPayments =
          ledger
              .where(
                (payment) => payment.debtId == debt.id && !payment.estornado,
              )
              .toList()
            ..sort((a, b) => a.data.compareTo(b.data));
      final amount = (debt.valorAtualizado * 100).round();
      contracted += amount;
      final current = debtBalance(
        principal: debt.valorPrincipal,
        taxaPercent: debt.taxaJuros,
        quitado: debt.statusPago,
        lancamentos: [
          for (final payment in debtPayments)
            LedgerPay(
              valor: payment.valor,
              somenteJuros: payment.descricao == 'Juros',
            ),
        ],
      );
      balance += (current.saldo * 100).round();
      entries.add(
        StatementEntry(
          id: 'debt_${debt.id}',
          debtId: debt.id,
          kind: StatementEntryKind.sale,
          date: debt.createdAt ?? debt.dataVencimento,
          description: debt.createdAt == null
              ? 'Lançamento antigo (data de vencimento)'
              : 'Venda registrada',
          cents: amount,
          due: debt.dataVencimento,
          installment: debt.totalParcelas > 1
              ? '${debt.parcela}/${debt.totalParcelas}'
              : '',
        ),
      );
    }
    var received = 0;
    for (final payment in ledger) {
      final debt = byId[payment.debtId]!;
      final amount = (payment.valor * 100).round();
      if (!payment.estornado) received += amount;
      final installment = debt.totalParcelas > 1
          ? '${debt.parcela}/${debt.totalParcelas}'
          : '';
      entries.add(
        StatementEntry(
          id: 'payment_${payment.id}',
          debtId: debt.id,
          kind: StatementEntryKind.payment,
          date: payment.data,
          description: '${payment.descricao} registrado pelo comerciante',
          cents: -amount,
          installment: installment,
        ),
      );
      if (payment.estornado) {
        entries.add(
          StatementEntry(
            id: 'reversal_${payment.id}',
            debtId: debt.id,
            kind: StatementEntryKind.reversal,
            date: payment.estornadoEm!,
            description:
                'Estorno: ${payment.estornoMotivo ?? 'Correção de registro'}',
            cents: amount,
            installment: installment,
          ),
        );
      }
    }
    entries.sort((a, b) {
      final date = a.date.compareTo(b.date);
      if (date != 0) return date;
      final kind = a.kind.index.compareTo(b.kind.index);
      return kind != 0 ? kind : a.id.compareTo(b.id);
    });
    return CustomerStatement(
      name: name,
      phone: phone,
      generatedAt: generatedAt ?? DateTime.now(),
      debts: loans,
      payments: ledger,
      entries: List.unmodifiable(entries),
      contractedCents: contracted,
      receivedCents: received,
      balanceCents: balance,
      legacyAdjustmentCents: balance - (contracted - received),
    );
  }
}

enum StatementEntryKind { sale, payment, reversal }

extension StatementEntryKindLabel on StatementEntryKind {
  String get label => switch (this) {
    StatementEntryKind.sale => 'Venda',
    StatementEntryKind.payment => 'Pagamento',
    StatementEntryKind.reversal => 'Estorno',
  };
}

class StatementEntry {
  const StatementEntry({
    required this.id,
    required this.debtId,
    required this.kind,
    required this.date,
    required this.description,
    required this.cents,
    this.installment = '',
    this.due,
  });

  final String id;
  final String debtId;
  final StatementEntryKind kind;
  final DateTime date;
  final String description;
  final int cents;
  final String installment;
  final DateTime? due;
}

/// Spreadsheet cells are quoted and text beginning with formula operators is
/// prefixed. Escaping quotes alone does not prevent spreadsheet execution.
String csvCell(Object? value) {
  var text = (value ?? '').toString();
  if (RegExp(r'^\s*[=+\-@\t\r]').hasMatch(text) &&
      !RegExp(r'^-?\d+(?:,\d{1,2})?$').hasMatch(text)) {
    text = "'$text";
  }
  return '"${text.replaceAll('"', '""')}"';
}

String csvDocument(Iterable<List<Object?>> rows) =>
    '\uFEFF${rows.map((row) => row.map(csvCell).join(';')).join('\r\n')}\r\n';

String statementCsv(CustomerStatement statement) => csvDocument([
  ['Pagô — extrato de registros do comerciante'],
  ['Cliente', statement.name],
  ['Telefone', statement.phone],
  ['Gerado em', statement.generatedAt.toIso8601String()],
  ['Vendas (R\$)', decimalCents(statement.contractedCents)],
  ['Recebimentos não estornados (R\$)', decimalCents(statement.receivedCents)],
  ['Saldo atual (R\$)', decimalCents(statement.balanceCents)],
  if (statement.legacyAdjustmentCents != 0)
    [
      'Diferença de registros históricos (R\$)',
      decimalCents(statement.legacyAdjustmentCents),
    ],
  [
    'Não comprova movimentação bancária. Confira os registros com o comerciante.',
  ],
  [],
  [
    'Tipo',
    'Data do registro',
    'Descrição',
    'Parcela',
    'Vencimento',
    'Valor no saldo (R\$)',
    'Lançamento',
  ],
  for (final entry in statement.entries)
    [
      entry.kind.label,
      entry.date.toIso8601String(),
      entry.description,
      entry.installment,
      entry.due?.toIso8601String() ?? '',
      decimalCents(entry.cents),
      entry.debtId,
    ],
]);

String accountCsv({
  required Iterable<Debt> debts,
  required Iterable<Payment> payments,
  required Iterable<Bill> bills,
}) => csvDocument([
  [
    'Tipo',
    'ID',
    'Lançamento/grupo',
    'Nome/descrição',
    'Telefone',
    'Data',
    'Vencimento',
    'Principal/valor (R\$)',
    'Juros (%)',
    'Situação',
    'Parcela',
    'Estornado em',
    'Motivo do estorno',
  ],
  for (final debt in debts)
    [
      'Venda',
      debt.id,
      debt.grupoId,
      debt.nome,
      debt.telefone,
      debt.createdAt?.toIso8601String() ?? '',
      debt.dataVencimento.toIso8601String(),
      decimalCents((debt.valorPrincipal * 100).round()),
      debt.taxaJuros.toString(),
      debt.statusPago ? 'Quitado' : 'Em aberto',
      '${debt.parcela}/${debt.totalParcelas}',
      '',
      '',
    ],
  for (final payment in payments)
    [
      'Pagamento',
      payment.id,
      payment.debtId,
      payment.descricao,
      '',
      payment.data.toIso8601String(),
      '',
      decimalCents((payment.valor * 100).round()),
      '',
      payment.estornado ? 'Estornado' : 'Registrado',
      '',
      payment.estornadoEm?.toIso8601String() ?? '',
      payment.estornoMotivo ?? '',
    ],
  for (final bill in bills)
    [
      'Boleto a pagar',
      bill.id,
      bill.grupoId,
      bill.fornecedor,
      '',
      bill.createdAt?.toIso8601String() ?? '',
      bill.dataVencimento.toIso8601String(),
      decimalCents((bill.valor * 100).round()),
      '',
      bill.pago ? 'Pago' : 'Em aberto',
      '${bill.parcela}/${bill.totalParcelas}',
      '',
      '',
    ],
]);

String decimalCents(int cents) {
  final absolute = cents.abs();
  return '${cents < 0 ? '-' : ''}${absolute ~/ 100},${(absolute % 100).toString().padLeft(2, '0')}';
}
