import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/daily_overview.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/pago_logo.dart';
import '../widgets/pago_menu.dart';
import '../widgets/whatsapp_charge.dart';
import '../widgets/whatsapp_mark.dart';
import 'add_debt_page.dart';
import 'bills_page.dart';
import 'caderneta_page.dart';
import 'client_profile_page.dart';
import 'premium_page.dart';
import 'settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DailyFocus _focus = DailyFocus.today;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final pending = state.pendingDebts;
    final selected = debtsForFocus(pending, _focus);
    final firstLoad =
        state.loading && state.debts.isEmpty && state.payments.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context, const AddDebtPage()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo lançamento'),
        tooltip: 'Cadastrar uma venda, fiado ou empréstimo',
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: state.load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(user: state.user),
                      const SizedBox(height: 24),
                      Text(
                        'Meu dia',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'O que entra. O que vence. Tudo no seu controle.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.mutedDark),
                      ),
                      const SizedBox(height: 12),
                      _SyncStatus(state: state),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _LoadError(
                          message: state.errorMessage!,
                          onRetry: state.load,
                        ),
                      ],
                      if (state.loading && !firstLoad) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(
                          semanticsLabel: 'Atualizando os registros',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (firstLoad)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Carregando sua caderneta',
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ReceivablesCard(state: state),
                        const SizedBox(height: 20),
                        const _QuickActions(),
                        const SizedBox(height: 24),
                        _SectionHeading(
                          title: 'Próximo passo',
                          action: 'Ver clientes',
                          onAction: () => _open(context, const CadernetaPage()),
                        ),
                        Text(
                          'Escolha o período para acompanhar os recebimentos.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedDark),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final focus in DailyFocus.values)
                              ChoiceChip(
                                label: Text(focus.label),
                                selected: _focus == focus,
                                onSelected: (_) =>
                                    setState(() => _focus = focus),
                                showCheckmark: false,
                                selectedColor: AppColors.primary,
                                backgroundColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: _focus == focus
                                      ? Colors.white
                                      : AppColors.mutedDark,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: BorderSide(
                                  color: _focus == focus
                                      ? AppColors.primary
                                      : AppColors.line,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
                if (selected.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: _EmptyFocus(
                        focus: _focus,
                        hasPending: pending.isNotEmpty,
                        onShowAll: () =>
                            setState(() => _focus = DailyFocus.all),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.separated(
                      itemCount: selected.length > 6 ? 6 : selected.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final debt = selected[index];
                        return DebtTile(
                          debt: debt,
                          onTap: () =>
                              _open(context, ClientProfilePage(debt: debt)),
                        );
                      },
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selected.length > 6)
                          TextButton(
                            onPressed: () =>
                                _open(context, const CadernetaPage()),
                            child: Text(
                              'Ver os ${selected.length} lançamentos na caderneta',
                            ),
                          ),
                        const SizedBox(height: 26),
                        const _BillsEntry(),
                        const SizedBox(height: 24),
                        _RecentPayments(state: state),
                        if (!state.user.premiumAtivo) ...[
                          const SizedBox(height: 24),
                          const _PremiumEntry(),
                        ],
                        const SizedBox(height: 110),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _open(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

class _Header extends StatelessWidget {
  const _Header({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final name = firstNameOf(user.nome);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Sua caderneta, organizada.' : 'Olá, $name',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.mutedDark),
              ),
              const SizedBox(height: 3),
              Semantics(
                button: true,
                label: 'Abrir menu do Pagô',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showPagoMenu(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 9),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PagoWordmark(markSize: 27, fontSize: 25),
                          SizedBox(width: 4),
                          Icon(
                            Icons.expand_more_rounded,
                            color: AppColors.mutedDark,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Buscar cliente',
          onPressed: () =>
              _open(context, const CadernetaPage(focusSearch: true)),
          icon: const Icon(Icons.search_rounded),
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          tooltip: 'Configurações da conta',
          onPressed: () => _open(context, const SettingsPage()),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.limeSoft,
            foregroundColor: AppColors.text,
          ),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }
}

class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.state});
  final AppController state;

  @override
  Widget build(BuildContext context) {
    final warning = state.syncWarning;
    final syncedAt = state.lastSyncedAt;
    final String label;
    final IconData icon;
    if (state.loading) {
      label = 'Atualizando seus registros…';
      icon = Icons.sync_rounded;
    } else if (warning != null) {
      label = warning;
      icon = Icons.cloud_off_rounded;
    } else if (!state.usesFirestore) {
      label = 'Dados neste aparelho';
      icon = Icons.phone_android_rounded;
    } else if (syncedAt != null) {
      label =
          'Última atualização às ${TimeOfDay.fromDateTime(syncedAt).format(context)} · arraste para atualizar';
      icon = Icons.cloud_done_outlined;
    } else {
      label = 'Arraste para atualizar seus registros';
      icon = Icons.sync_rounded;
    }
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: warning == null ? AppColors.mutedDark : AppColors.warning,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 11, color: AppColors.mutedDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.danger),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _ReceivablesCard extends StatelessWidget {
  const _ReceivablesCard({required this.state});
  final AppController state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.south_west_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'A receber',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                Money.full(state.saldoAberto),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Total em aberto na caderneta. Não é saldo bancário.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 330 ||
                MediaQuery.textScalerOf(context).scale(14) > 20;
            final values = [
              _SmallMetric(
                label: 'Previsto em 7 dias',
                value: Money.full(state.aReceberNaSemana),
                icon: Icons.event_available_outlined,
                color: AppColors.text,
              ),
              _SmallMetric(
                label: 'Vencido a receber',
                value: Money.full(state.aReceberVencido),
                icon: Icons.schedule_rounded,
                color: state.aReceberVencido > 0
                    ? AppColors.danger
                    : AppColors.mutedDark,
              ),
            ];
            if (stacked) {
              return Column(
                children: [values[0], const SizedBox(height: 10), values[1]],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: values[0]),
                const SizedBox(width: 10),
                Expanded(child: values[1]),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 9),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.mutedDark, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: () => _open(context, const CadernetaPage()),
        icon: const Icon(Icons.people_outline_rounded, size: 19),
        label: const Text('Clientes'),
      ),
      OutlinedButton.icon(
        onPressed: () => _open(context, const BillsPage()),
        icon: const Icon(Icons.receipt_long_outlined, size: 19),
        label: const Text('Boletos'),
      ),
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -.4,
        ),
      ),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

class _EmptyFocus extends StatelessWidget {
  const _EmptyFocus({
    required this.focus,
    required this.hasPending,
    required this.onShowAll,
  });
  final DailyFocus focus;
  final bool hasPending;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasPending ? Icons.task_alt_rounded : Icons.menu_book_outlined,
            color: AppColors.primary,
            size: 30,
          ),
          const SizedBox(height: 14),
          Text(
            hasPending ? focus.emptyLabel : 'Sua próxima venda começa aqui',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            hasPending
                ? 'Você pode acompanhar os outros períodos ou abrir todos os clientes.'
                : 'Cadastre um lançamento para acompanhar o que falta receber.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.mutedDark, height: 1.6),
          ),
          const SizedBox(height: 10),
          if (hasPending)
            TextButton(
              onPressed: onShowAll,
              child: const Text('Ver todos em aberto'),
            )
          else
            FilledButton.icon(
              onPressed: () => _open(context, const AddDebtPage()),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Cadastrar primeira venda'),
            ),
        ],
      ),
    );
  }
}

class _BillsEntry extends StatelessWidget {
  const _BillsEntry();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final count = state.pendingBills.length;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _open(context, const BillsPage()),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.north_east_rounded,
                    color: AppColors.text,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A pagar · fornecedores',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.mutedDark,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                Money.full(state.aPagarAberto),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                count == 0
                    ? 'Nenhum boleto em aberto cadastrado.'
                    : '$count ${count == 1 ? 'boleto em aberto' : 'boletos em aberto'}. ${Money.full(state.aPagarNaSemana)} previstos em 7 dias.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.mutedDark, height: 1.5),
              ),
              if (state.aPagarAtrasado > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${Money.full(state.aPagarAtrasado)} vencidos',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (!state.user.premiumAtivo) ...[
                const SizedBox(height: 9),
                const Text(
                  'Premium para cadastrar e editar. Seu histórico continua acessível.',
                  style: TextStyle(fontSize: 11, color: AppColors.mutedDark),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentPayments extends StatelessWidget {
  const _RecentPayments({required this.state});
  final AppController state;

  @override
  Widget build(BuildContext context) {
    final recent = state.payments.toList()
      ..sort(
        (a, b) => (b.estornadoEm ?? b.data).compareTo(a.estornadoEm ?? a.data),
      );
    if (recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(title: 'Últimos registros'),
        const SizedBox(height: 6),
        Text(
          'Pagamentos registrados por você.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.mutedDark),
        ),
        const SizedBox(height: 10),
        for (final payment in recent.take(4))
          _PaymentRow(state: state, payment: payment),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.state, required this.payment});
  final AppController state;
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final debt = state.debts
        .where((item) => item.id == payment.debtId)
        .firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: debt == null
            ? null
            : () => _open(context, ClientProfilePage(debt: debt)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    payment.estornado
                        ? Icons.undo_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 17,
                    color: payment.estornado
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                  Text(
                    debt?.nome ?? 'Pagamento registrado',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${payment.estornado ? 'Estorno' : 'Pagamento'} de ${Money.full(payment.valor)} · ${Dates.full(payment.estornadoEm ?? payment.data)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.mutedDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumEntry extends StatelessWidget {
  const _PremiumEntry();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.limeSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seu tempo também vale.',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Conheça voz, leitura de recibos, mensagens próprias e boletos a pagar.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.mutedDark),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _open(context, const PremiumPage()),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text('Conhecer o Premium'),
        ),
      ],
    ),
  );
}

class DebtTile extends StatelessWidget {
  const DebtTile({super.key, required this.debt, required this.onTap});
  final Debt debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final saldo = context.watch<AppController>().saldoOf(debt);
    final overdue = debt.isOverdue;
    final due = isSameDay(debt.dataVencimento, DateTime.now());
    final label = overdue
        ? 'Vencido em ${Dates.due(debt.dataVencimento)}'
        : due
        ? 'Vence hoje'
        : 'Vence em ${Dates.due(debt.dataVencimento)}';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 15, 8, 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: overdue ? AppColors.dangerBorder : AppColors.line,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.nome,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: overdue ? AppColors.danger : AppColors.mutedDark,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      Money.full(saldo),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Preparar cobrança de ${debt.nome} pelo WhatsApp',
                onPressed: () => chargeOnWhatsApp(context: context, debt: debt),
                icon: const WhatsAppMark(size: 25),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedDark,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
