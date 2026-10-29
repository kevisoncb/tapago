import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/daily_overview.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'web_clients.dart';
import 'web_shell.dart';
import 'web_widgets.dart';

/// Resumo do dia: números do caixa e o que precisa de cobrança agora.
class WebHome extends StatelessWidget {
  const WebHome({super.key, required this.onGo});

  final ValueChanged<WebSection> onGo;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final pending = state.pendingDebts;
    final overdue = debtsForFocus(pending, DailyFocus.overdue);
    final soon = debtsForFocus(pending, DailyFocus.upcoming);
    final first = state.user.nome.trim().split(' ').first;
    return WebPage(
      title: first.isEmpty ? 'Início' : 'Olá, $first',
      subtitle: 'Resumo da sua caderneta hoje.',
      action: FilledButton.icon(
        onPressed: () => onGo(WebSection.venda),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova venda'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size(0, 48),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final cards = [
                WebStat(
                  label: 'Total a receber',
                  value: Money.full(state.saldoAberto),
                ),
                WebStat(
                  label: 'Em atraso',
                  value: Money.full(state.aReceberVencido),
                  color: state.aReceberVencido > 0
                      ? AppColors.danger
                      : AppColors.text,
                ),
                WebStat(
                  label: 'Vence em 7 dias',
                  value: Money.full(state.aReceberNaSemana),
                ),
                WebStat(
                  label: 'Boletos a pagar',
                  value: Money.full(state.aPagarAberto),
                ),
              ];
              final cols = box.maxWidth >= 900 ? 4 : 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final card in cards)
                    SizedBox(
                      width: (box.maxWidth - 16 * (cols - 1)) / cols,
                      child: card,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          _DebtTable(
            title: 'Em atraso',
            empty: 'Nenhum recebimento em atraso.',
            debts: overdue,
          ),
          const SizedBox(height: 20),
          _DebtTable(
            title: 'Vencem nos próximos 7 dias',
            empty: 'Nenhum vencimento nos próximos 7 dias.',
            debts: soon,
          ),
        ],
      ),
    );
  }
}

class _DebtTable extends StatelessWidget {
  const _DebtTable({
    required this.title,
    required this.empty,
    required this.debts,
  });

  final String title;
  final String empty;
  final List<Debt> debts;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final shown = debts.take(10).toList();
    return WebCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title${debts.isEmpty ? '' : ' (${debts.length})'}',
            style: webText(17, weight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                empty,
                style: webText(14, color: AppColors.mutedDark),
              ),
            )
          else
            for (final debt in shown)
              InkWell(
                onTap: () => openWebClient(context, debt),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          debt.nome,
                          overflow: TextOverflow.ellipsis,
                          style: webText(15, weight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          debt.parcelado ? debt.parcelaLabel : 'À vista',
                          style: webText(13.5, color: AppColors.mutedDark),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          Dates.full(debt.dataVencimento),
                          style: webText(13.5, color: AppColors.mutedDark),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(
                          Money.full(state.saldoOf(debt)),
                          textAlign: TextAlign.right,
                          style: webText(15, weight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
