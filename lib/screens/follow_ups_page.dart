import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/client_match.dart';
import '../services/collection_follow_up.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/whatsapp_charge.dart';
import '../widgets/whatsapp_mark.dart';
import 'follow_up_page.dart';

enum _FollowUpFilter { all, overdue, today, upcoming, noContact }

extension on _FollowUpFilter {
  String get label => switch (this) {
    _FollowUpFilter.all => 'Todos',
    _FollowUpFilter.overdue => 'Atrasados',
    _FollowUpFilter.today => 'Hoje',
    _FollowUpFilter.upcoming => 'Próximos',
    _FollowUpFilter.noContact => 'Sem contato',
  };
}

class FollowUpsPage extends StatefulWidget {
  const FollowUpsPage({super.key});

  @override
  State<FollowUpsPage> createState() => _FollowUpsPageState();
}

class _FollowUpsPageState extends State<FollowUpsPage> {
  final _search = TextEditingController();
  Future<List<CollectionFollowUp>>? _records;
  String? _userId;
  var _filter = _FollowUpFilter.all;

  Future<List<CollectionFollowUp>> _load(AppController state) =>
      CollectionFollowUpStore(
        usesFirestore: state.usesFirestore,
        userId: state.user.id,
      ).list();

  void _ensureLoaded(AppController state) {
    if (_userId == state.user.id && _records != null) return;
    _userId = state.user.id;
    _records = _load(state);
  }

  Future<void> _refresh(AppController state) async {
    await state.load();
    final next = _load(state);
    setState(() => _records = next);
    await next;
  }

  Future<void> _open(AppController state, CadernetaContact contact) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            FollowUpPage(contactKey: contact.key, clientName: contact.nome),
      ),
    );
    if (mounted) setState(() => _records = _load(state));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    _ensureLoaded(state);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Acompanhamentos')),
      body: FutureBuilder<List<CollectionFollowUp>>(
        future: _records,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando acompanhamentos',
              ),
            );
          }
          if (snapshot.hasError) {
            return _LoadFailure(
              onRetry: () => setState(() => _records = _load(state)),
            );
          }
          final all = _buildItems(state, snapshot.data ?? const []);
          final visible = all
              .where((item) => item.matches(_filter))
              .where((item) => contactMatchesQuery(item.contact, _search.text))
              .toList();
          return RefreshIndicator(
            onRefresh: () => _refresh(state),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const Text(
                  'Organize conversas e datas combinadas. Nada aqui altera o saldo da caderneta.',
                  style: TextStyle(color: AppColors.mutedDark, height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Buscar acompanhamento',
                    hintText: 'Nome ou WhatsApp',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in _FollowUpFilter.values) ...[
                        ChoiceChip(
                          label: Text('${filter.label} ${_count(all, filter)}'),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                          showCheckmark: false,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (visible.isEmpty)
                  _EmptyResult(hasQuery: _search.text.trim().isNotEmpty)
                else
                  for (final item in visible) ...[
                    _FollowUpCard(
                      item: item,
                      onOpen: () => _open(state, item.contact),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

int _count(List<_FollowUpItem> items, _FollowUpFilter filter) =>
    items.where((item) => item.matches(filter)).length;

List<_FollowUpItem> _buildItems(
  AppController state,
  List<CollectionFollowUp> records,
) {
  final byContact = {for (final item in records) item.contactKey: item};
  final now = DateTime.now();
  final items = <_FollowUpItem>[];
  for (final contact in groupContacts(state.debts)) {
    final record = byContact[contact.key];
    final open =
        contact.debts.where((debt) => state.saldoOf(debt) > 0.009).toList()
          ..sort((a, b) => a.dataVencimento.compareTo(b.dataVencimento));
    final overdue = open.any((debt) => debt.isOverdue);
    if (record == null && !overdue) continue;
    items.add(
      _FollowUpItem(
        contact: contact,
        record: record,
        representative: open.firstOrNull ?? contact.debts.first,
        hasOpenBalance: open.isNotEmpty,
        hasOverdueBalance: overdue,
        now: now,
      ),
    );
  }
  items.sort((a, b) {
    final priority = a.priority.compareTo(b.priority);
    if (priority != 0) return priority;
    final left = a.record?.nextContactAt ?? a.representative.dataVencimento;
    final right = b.record?.nextContactAt ?? b.representative.dataVencimento;
    return left.compareTo(right);
  });
  return items;
}

class _FollowUpItem {
  const _FollowUpItem({
    required this.contact,
    required this.record,
    required this.representative,
    required this.hasOpenBalance,
    required this.hasOverdueBalance,
    required this.now,
  });

  final CadernetaContact contact;
  final CollectionFollowUp? record;
  final Debt representative;
  final bool hasOpenBalance;
  final bool hasOverdueBalance;
  final DateTime now;

  FollowUpTiming? get timing => record?.timingAt(now);
  bool get withoutContact =>
      hasOverdueBalance && record?.lastContactedAt == null;

  bool matches(_FollowUpFilter filter) => switch (filter) {
    _FollowUpFilter.all => true,
    _FollowUpFilter.overdue => timing == FollowUpTiming.overdue,
    _FollowUpFilter.today => timing == FollowUpTiming.today,
    _FollowUpFilter.upcoming => timing == FollowUpTiming.upcoming,
    _FollowUpFilter.noContact => withoutContact,
  };

  int get priority {
    if (timing == FollowUpTiming.overdue) return 0;
    if (withoutContact) return 1;
    if (timing == FollowUpTiming.today) return 2;
    if (timing == FollowUpTiming.upcoming) return 3;
    return 4;
  }

  String get status {
    if (!hasOpenBalance) return 'Sem saldo em aberto';
    final promise = record?.promisedAmount != null;
    switch (timing) {
      case FollowUpTiming.overdue:
        return promise ? 'Promessa vencida' : 'Contato atrasado';
      case FollowUpTiming.today:
        return promise ? 'Promessa para hoje' : 'Retomar contato hoje';
      case FollowUpTiming.upcoming:
        final date = record!.nextContactAt!;
        return promise
            ? 'Promessa para ${Dates.due(date)}'
            : 'Retomar em ${Dates.due(date)}';
      case null:
        return 'Em atraso · sem contato registrado';
    }
  }

  Color get color => !hasOpenBalance
      ? AppColors.success
      : timing == FollowUpTiming.overdue || withoutContact
      ? AppColors.danger
      : timing == FollowUpTiming.today
      ? AppColors.warning
      : AppColors.primary;
}

class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({required this.item, required this.onOpen});

  final _FollowUpItem item;
  final VoidCallback onOpen;

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
        Text(
          item.contact.nome,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          item.status,
          style: TextStyle(color: item.color, fontWeight: FontWeight.w700),
        ),
        if (item.record?.lastContactedAt != null) ...[
          const SizedBox(height: 6),
          Text(
            'Último contato: ${Dates.full(item.record!.lastContactedAt!)}',
            style: const TextStyle(color: AppColors.mutedDark),
          ),
        ],
        if (item.record?.promisedAmount != null) ...[
          const SizedBox(height: 4),
          Text(
            'Combinado: ${Money.full(item.record!.promisedAmount!)} · não altera o saldo',
            style: const TextStyle(color: AppColors.mutedDark),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (item.hasOpenBalance && item.contact.telefone.trim().isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => chargeOnWhatsApp(
                  context: context,
                  debt: item.representative,
                ),
                icon: const WhatsAppMark(size: 18),
                label: const Text('Abrir WhatsApp'),
              ),
            TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.event_note_outlined, size: 18),
              label: const Text('Atualizar'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.hasQuery});
  final bool hasQuery;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        const Icon(Icons.task_alt_rounded, size: 38, color: AppColors.primary),
        const SizedBox(height: 12),
        Text(
          hasQuery
              ? 'Nenhum acompanhamento encontrado'
              : 'Nada pendente neste filtro',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Não foi possível carregar os acompanhamentos.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
