import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/business_report.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Relatórios')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              '${Dates.full(_range.start)} a ${Dates.full(_range.end)}',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Recebimentos de clientes',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: 'Recebido no período',
            valueCents: report.receivedCents,
            detail: _records(report.receivedCount, 'pagamento'),
            color: AppColors.success,
            icon: Icons.south_west_rounded,
          ),
          const SizedBox(height: 10),
          _MetricCard(
            title: 'Previsto no período',
            valueCents: report.forecastCents,
            detail:
                '${_records(report.forecastCount, 'lançamento')} ainda em aberto',
            color: AppColors.primary,
            icon: Icons.event_available_outlined,
          ),
          const SizedBox(height: 10),
          _MetricCard(
            title: 'Vencido hoje',
            valueCents: report.overdueCents,
            detail:
                '${_records(report.overdueCount, 'lançamento')} fora do período selecionado ou dentro dele',
            color: AppColors.danger,
            icon: Icons.schedule_rounded,
          ),
          if (report.overdueCount > 0) ...[
            const SizedBox(height: 18),
            Text(
              'Idade dos atrasos',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final bucket in report.aging) _AgingRow(bucket: bucket),
          ],
          const SizedBox(height: 24),
          Text(
            'Boletos de fornecedores',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: 'Pago no período',
            valueCents: report.supplierPaidCents,
            detail: _records(report.supplierPaidCount, 'boleto'),
            color: AppColors.text,
            icon: Icons.north_east_rounded,
          ),
          const SizedBox(height: 10),
          _MetricCard(
            title: 'A pagar no período',
            valueCents: report.supplierDueCents,
            detail:
                '${_records(report.supplierDueCount, 'boleto')} ainda em aberto',
            color: AppColors.warning,
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 10),
          _MetricCard(
            title: 'Boletos atrasados hoje',
            valueCents: report.supplierOverdueCents,
            detail: _records(report.supplierOverdueCount, 'boleto'),
            color: AppColors.danger,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              '“Recebido” considera pagamentos registrados e não estornados. “Previsto” mostra valores atualmente em aberto com vencimento no período. Estes números não são saldo bancário nem lucro.',
            ),
          ),
        ],
      ),
    );
  }
}

String _records(int count, String singular) {
  if (count == 1) return '1 $singular';
  final plural = singular == 'boleto'
      ? 'boletos'
      : singular == 'pagamento'
      ? 'pagamentos'
      : 'lançamentos';
  return '$count $plural';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.valueCents,
    required this.detail,
    required this.color,
    required this.icon,
  });

  final String title;
  final int valueCents;
  final String detail;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          Money.full(valueCents / 100),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 3),
        Text(detail, style: const TextStyle(color: AppColors.mutedDark)),
      ],
    ),
  );
}

class _AgingRow extends StatelessWidget {
  const _AgingRow({required this.bucket});

  final AgingBucket bucket;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(bucket.label)),
        Text(
          '${bucket.count} · ${Money.full(bucket.cents / 100)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
