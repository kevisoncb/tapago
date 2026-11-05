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
  return openWebPanel(context, ContactHistoryPage(contactKey: contactKeyOf(debt)));
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
  const WebClients({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<WebClients> createState() => _WebClientsState();
}

class _WebClientsState extends State<WebClients> {
  late final _search = TextEditingController(text: widget.initialQuery);
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
    final head = WebTableHeader.style;
    return WebPage(
      title: 'Clientes',
      subtitle: '${all.length} ${all.length == 1 ? 'cliente' : 'clientes'} na caderneta.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              WebSearchField(
                controller: _search,
                hint: 'Filtrar por nome ou telefone',
                onChanged: (_) => setState(() {}),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
          const SizedBox(height: 14),
          WebCard(
            padding: EdgeInsets.zero,
            child: contacts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: WebEmpty(
                      state.debts.isEmpty
                          ? 'A caderneta ainda está vazia. Comece por um novo lançamento.'
                          : 'Nenhum cliente encontrado.',
                    ),
                  )
                : Column(
                    children: [
                      WebTableHeader(
                        children: [
                          Expanded(flex: 4, child: Text('CLIENTE', style: head)),
                          Expanded(flex: 3, child: Text('WHATSAPP', style: head)),
                          Expanded(flex: 2, child: Text('SITUAÇÃO', style: head)),
                          SizedBox(
                            width: 130,
                            child: Text('SALDO', textAlign: TextAlign.right, style: head),
                          ),
                        ],
                      ),
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
    return WebTableRow(
      onTap: () => openWebClient(context, contact.debts.first),
      children: [
        Expanded(
          flex: 4,
          child: Text(
            contact.nome,
            overflow: TextOverflow.ellipsis,
            style: webText(13.5, weight: FontWeight.w700),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            contact.telefone.isEmpty
                ? '—'
                : formatPhoneBr(contact.telefone),
            style: webText(13, weight: FontWeight.w500, color: AppColors.mutedDark),
          ),
        ),
        Expanded(flex: 2, child: WebBadge(label, color: color)),
        SizedBox(
          width: 130,
          child: Text(
            Money.full(contact.saldoAbertoOf(state.saldoOf)),
            textAlign: TextAlign.right,
            style: webText(13.5, weight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
