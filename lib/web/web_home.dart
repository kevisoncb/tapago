import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/daily_overview.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/whatsapp_charge.dart';
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
      action: WebPrimaryButton(
        label: 'Nova venda',
        icon: Icons.add_rounded,
        onPressed: () => onGo(WebSection.venda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.debts.isEmpty) ...[
            WebCard(
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Primeira vez por aqui? Veja como começar.',
                    style: webText(15.5, weight: FontWeight.w800),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onGo(WebSection.ajuda),
                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                    label: const Text('Ver o passo a passo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          WebGrid(
            children: [
              WebStat(
                label: 'Total a receber',
                value: Money.full(state.saldoAberto),
                onTap: () => onGo(WebSection.clientes),
              ),
              WebStat(
                label: 'Em atraso',
                value: Money.full(state.aReceberVencido),
                color: state.aReceberVencido > 0
                    ? AppColors.danger
                    : AppColors.text,
                onTap: () => onGo(WebSection.clientes),
              ),
              WebStat(
                label: 'Vence em 7 dias',
                value: Money.full(state.aReceberNaSemana),
                onTap: () => onGo(WebSection.clientes),
              ),
              WebStat(
                label: 'Boletos a pagar',
                value: Money.full(state.aPagarAberto),
                onTap: () => onGo(WebSection.boletos),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _DebtTable(
            title: 'Em atraso',
            empty: 'Nenhum recebimento em atraso.',
            debts: overdue,
            onSeeAll: () => onGo(WebSection.clientes),
          ),
          const SizedBox(height: 20),
          _DebtTable(
            title: 'Vencem nos próximos 7 dias',
            empty: 'Nenhum vencimento nos próximos 7 dias.',
            debts: soon,
            onSeeAll: () => onGo(WebSection.clientes),
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
    required this.onSeeAll,
  });

  static const _limit = 10;

  final String title;
  final String empty;
  final List<Debt> debts;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final shown = debts.take(_limit).toList();
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
                  padding: const EdgeInsets.symmetric(vertical: 6),
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
                      SizedBox(
                        width: 48,
                        child: debt.telefone.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Cobrar no WhatsApp',
                                onPressed: () => chargeOnWhatsApp(
                                  context: context,
                                  debt: debt,
                                ),
                                icon: const Icon(Icons.chat_outlined, size: 20),
                                color: AppColors.primary,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
          if (debts.length > _limit)
            TextButton(
              onPressed: onSeeAll,
              child: Text('Ver todos os ${debts.length} em Clientes'),
            ),
        ],
      ),
    );
  }
}
