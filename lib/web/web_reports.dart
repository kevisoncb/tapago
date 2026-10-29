import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/business_report.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'web_widgets.dart';

/// Relatório do período em cartões lado a lado, com a lista dos pagamentos
/// recebidos e a idade dos atrasos.
class WebReports extends StatefulWidget {
  const WebReports({super.key});

  @override
  State<WebReports> createState() => _WebReportsState();
}

class _WebReportsState extends State<WebReports> {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  Future<void> _pickRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      initialDateRange: _range,
      helpText: 'Período do relatório',
      saveText: 'Aplicar',
    );
    if (selected != null && mounted) setState(() => _range = selected);
  }

  bool _inRange(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(_range.start.year, _range.start.month, _range.start.day);
    final end = DateTime(_range.end.year, _range.end.month, _range.end.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  String _count(int count, String one, String many) =>
      count == 1 ? '1 $one' : '$count $many';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final report = buildBusinessReport(
      debts: state.debts,
      payments: state.payments,
      bills: state.bills,
      start: _range.start,
      end: _range.end,
    );
    final names = {for (final debt in state.debts) debt.id: debt.nome};
    final received = state.payments
        .where((item) => !item.estornado && _inRange(item.data))
        .toList()
      ..sort((a, b) => b.data.compareTo(a.data));
    return WebPage(
      title: 'Relatórios',
      subtitle: 'Recebimentos e boletos do período escolhido.',
      action: OutlinedButton.icon(
        onPressed: _pickRange,
        icon: const Icon(Icons.date_range_outlined),
        label: Text('${Dates.full(_range.start)} a ${Dates.full(_range.end)}'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recebimentos de clientes', style: webText(18, weight: FontWeight.w800)),
          const SizedBox(height: 12),
          _grid(context, [
            _Metric(
              'Recebido no período',
              report.receivedCents,
              _count(report.receivedCount, 'pagamento', 'pagamentos'),
              AppColors.success,
            ),
            _Metric(
              'Previsto no período',
              report.forecastCents,
              '${_count(report.forecastCount, 'lançamento', 'lançamentos')} em aberto',
              AppColors.primary,
            ),
            _Metric(
              'Vencido hoje',
              report.overdueCents,
              _count(report.overdueCount, 'lançamento', 'lançamentos'),
              AppColors.danger,
            ),
          ]),
          const SizedBox(height: 28),
          Text('Boletos de fornecedores', style: webText(18, weight: FontWeight.w800)),
          const SizedBox(height: 12),
          _grid(context, [
            _Metric(
              'Pago no período',
              report.supplierPaidCents,
              _count(report.supplierPaidCount, 'boleto', 'boletos'),
              AppColors.text,
            ),
            _Metric(
              'A pagar no período',
              report.supplierDueCents,
              '${_count(report.supplierDueCount, 'boleto', 'boletos')} em aberto',
              AppColors.warning,
            ),
            _Metric(
              'Atrasados hoje',
              report.supplierOverdueCents,
              _count(report.supplierOverdueCount, 'boleto', 'boletos'),
              AppColors.danger,
            ),
          ]),
          if (report.overdueCount > 0) ...[
            const SizedBox(height: 28),
            WebCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Idade dos atrasos', style: webText(17, weight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final bucket in report.aging)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(bucket.label, style: webText(14.5)),
                          ),
                          Text(
                            _count(bucket.count, 'lançamento', 'lançamentos'),
                            style: webText(13.5, weight: FontWeight.w500, color: AppColors.mutedDark),
                          ),
                          SizedBox(
                            width: 130,
                            child: Text(
                              Money.full(bucket.cents / 100),
                              textAlign: TextAlign.right,
                              style: webText(15, weight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          WebCard(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pagamentos recebidos', style: webText(17, weight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (received.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'Nenhum pagamento neste período.',
                      style: webText(14, color: AppColors.mutedDark),
                    ),
                  )
                else
                  for (final payment in received.take(50))
                    _PaymentRow(payment: payment, nome: names[payment.debtId] ?? 'Cliente'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '“Recebido” considera pagamentos registrados e não estornados. '
            '“Previsto” mostra valores em aberto com vencimento no período. '
            'Não são saldo bancário nem lucro.',
            style: webText(13, weight: FontWeight.w500, color: AppColors.mutedDark),
          ),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, List<_Metric> items) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 760 ? 3 : 1;
        final width = (box.maxWidth - 16 * (cols - 1)) / cols;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: WebCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: webText(13.5, color: AppColors.mutedDark)),
                      const SizedBox(height: 6),
                      Text(
                        Money.full(item.cents / 100),
                        style: webText(24, weight: FontWeight.w800, color: item.color),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.detail,
                        style: webText(13, weight: FontWeight.w500, color: AppColors.mutedDark),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Metric {
  const _Metric(this.title, this.cents, this.detail, this.color);

  final String title;
  final int cents;
  final String detail;
  final Color color;
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.nome});

  final Payment payment;
  final String nome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.primarySoft)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              nome,
              overflow: TextOverflow.ellipsis,
              style: webText(15, weight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              payment.descricao,
              overflow: TextOverflow.ellipsis,
              style: webText(13.5, weight: FontWeight.w500, color: AppColors.mutedDark),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              Dates.full(payment.data),
              style: webText(13.5, weight: FontWeight.w500, color: AppColors.mutedDark),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              Money.full(payment.valor),
              textAlign: TextAlign.right,
              style: webText(15, weight: FontWeight.w800, color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}
