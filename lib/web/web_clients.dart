import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../screens/contact_history_page.dart';
import '../services/client_match.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/masks.dart';
import 'web_widgets.dart';

/// Abre o histórico do cliente (lançamentos, parcelas e pagamentos) num painel
/// por cima da lista, para não perder o lugar na tela.
Future<void> openWebClient(BuildContext context, Debt debt) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: ContactHistoryPage(contactKey: contactKeyOf(debt)),
      ),
    ),
  );
}

enum _Filter {
  todos('Todos'),
  atraso('Em atraso'),
  aberto('Com saldo'),
  quitado('Quitados');

  const _Filter(this.label);

  final String label;
}

class WebClients extends StatefulWidget {
  const WebClients({super.key, required this.onNewSale});

  final VoidCallback onNewSale;

  @override
  State<WebClients> createState() => _WebClientsState();
}

class _WebClientsState extends State<WebClients> {
  final _search = TextEditingController();
  var _filter = _Filter.todos;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final all = groupContacts(state.debts);
    final contacts = all.where((contact) {
      if (!contactMatchesQuery(contact, _search.text)) return false;
      final open = contact.temAberto(state.saldoOf);
      return switch (_filter) {
        _Filter.todos => true,
        _Filter.atraso => contact.temAtraso(state.saldoOf),
        _Filter.aberto => open,
        _Filter.quitado => !open,
      };
    }).toList()
      ..sort((a, b) {
        final late = (b.temAtraso(state.saldoOf) ? 1 : 0) -
            (a.temAtraso(state.saldoOf) ? 1 : 0);
        if (late != 0) return late;
        return b
            .saldoAbertoOf(state.saldoOf)
            .compareTo(a.saldoAbertoOf(state.saldoOf));
      });
    return WebPage(
      title: 'Clientes',
      subtitle: '${all.length} ${all.length == 1 ? 'cliente' : 'clientes'} na caderneta.',
      action: FilledButton.icon(
        onPressed: widget.onNewSale,
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome ou telefone',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primaryMuted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final filter in _Filter.values)
                    ChoiceChip(
                      label: Text(filter.label),
                      selected: _filter == filter,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          WebCard(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: contacts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      state.debts.isEmpty
                          ? 'A caderneta ainda está vazia. Comece por uma nova venda.'
                          : 'Nenhum cliente encontrado.',
                      style: webText(14.5, color: AppColors.mutedDark),
                    ),
                  )
                : Column(
                    children: [
                      const _HeaderRow(),
                      for (final contact in contacts)
                        _ClientRow(contact: contact),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = webText(12.5, weight: FontWeight.w700, color: AppColors.mutedDark);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('CLIENTE', style: style)),
          Expanded(flex: 3, child: Text('WHATSAPP', style: style)),
          Expanded(flex: 2, child: Text('SITUAÇÃO', style: style)),
          SizedBox(
            width: 130,
            child: Text('SALDO', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({required this.contact});

  final CadernetaContact contact;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final late = contact.temAtraso(state.saldoOf);
    final open = contact.temAberto(state.saldoOf);
    final (label, color) = late
        ? ('Em atraso', AppColors.danger)
        : open
            ? ('Em aberto', AppColors.warning)
            : ('Quitado', AppColors.success);
    return InkWell(
      onTap: () => openWebClient(context, contact.debts.first),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.primarySoft)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                contact.nome,
                overflow: TextOverflow.ellipsis,
                style: webText(15, weight: FontWeight.w700),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                contact.telefone.isEmpty
                    ? '—'
                    : formatPhoneBr(contact.telefone),
                style: webText(14, weight: FontWeight.w500, color: AppColors.mutedDark),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(label, style: webText(13.5, weight: FontWeight.w700, color: color)),
            ),
            SizedBox(
              width: 130,
              child: Text(
                Money.full(contact.saldoAbertoOf(state.saldoOf)),
                textAlign: TextAlign.right,
                style: webText(15, weight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
