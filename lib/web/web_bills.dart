import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../screens/add_bill_page.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'web_widgets.dart';

const _actionsWidth = 180.0;

enum _BillFilter {
  abertos('Em aberto'),
  atrasados('Atrasados'),
  pagos('Pagos'),
  todos('Todos');

  const _BillFilter(this.label);

  final String label;
}

/// Boletos a pagar em tabela: filtro, busca por fornecedor e baixa com um
/// clique. O cadastro abre o mesmo formulário do aplicativo num painel. Como no
/// aplicativo, cadastrar e alterar boletos é do Premium.
class WebBills extends StatefulWidget {
  const WebBills({super.key, required this.onPremium});

  final VoidCallback onPremium;

  @override
  State<WebBills> createState() => _WebBillsState();
}

class _WebBillsState extends State<WebBills> {
  static const _compactTable = 720.0;

  final _search = TextEditingController();
  var _filter = _BillFilter.abertos;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _delete(AppController state, Bill bill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir boleto?'),
        content: Text('${bill.fornecedor} · ${Money.full(bill.valor)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await state.deleteBill(bill);
    } catch (_) {
      if (mounted) showPagoSnack(context, 'Não foi possível excluir agora.');
    }
  }

  Future<void> _toggle(AppController state, Bill bill) async {
    try {
      await state.setBillPaid(bill, !bill.pago);
    } catch (_) {
      if (mounted) showPagoSnack(context, 'Não foi possível salvar agora.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final premium = state.user.premiumAtivo;
    final needle = _search.text.trim().toLowerCase();
    final bills = state.bills.where((bill) {
      if (needle.isNotEmpty && !bill.fornecedor.toLowerCase().contains(needle)) {
        return false;
      }
      return switch (_filter) {
        _BillFilter.abertos => !bill.pago,
        _BillFilter.atrasados => bill.isOverdue,
        _BillFilter.pagos => bill.pago,
        _BillFilter.todos => true,
      };
    }).toList()
      ..sort((a, b) => _filter == _BillFilter.pagos
          ? (b.pagoEm ?? b.dataVencimento).compareTo(a.pagoEm ?? a.dataVencimento)
          : a.dataVencimento.compareTo(b.dataVencimento));
    return WebPage(
      title: 'Boletos',
      subtitle: 'Contas a pagar aos seus fornecedores.',
      action: WebPrimaryButton(
        label: 'Novo boleto',
        icon: premium ? Icons.add_rounded : Icons.lock_outline_rounded,
        onPressed: premium
            ? () => openWebPanel(context, const AddBillPage())
            : widget.onPremium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebGrid(
            minItemWidth: 170,
            maxColumns: 3,
            children: [
              WebStat(
                label: 'A pagar',
                value: Money.full(state.aPagarAberto),
              ),
              WebStat(
                label: 'Vence em 7 dias',
                value: Money.full(state.aPagarNaSemana),
              ),
              WebStat(
                label: 'Atrasados',
                value: Money.full(state.aPagarAtrasado),
                color: state.aPagarAtrasado > 0
                    ? AppColors.danger
                    : AppColors.text,
              ),
            ],
          ),
          if (!premium) ...[
            const SizedBox(height: 14),
            WebCard(
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Boletos a pagar é do Premium.',
                    style: webText(14.5, weight: FontWeight.w800),
                  ),
                  OutlinedButton(
                    onPressed: widget.onPremium,
                    child: const Text('Ver o Premium'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              WebSearchField(
                controller: _search,
                hint: 'Buscar fornecedor',
                onChanged: (_) => setState(() {}),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in _BillFilter.values)
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
            child: bills.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: WebEmpty(
                      state.bills.isEmpty
                          ? (premium
                              ? 'Nenhum boleto cadastrado. Use "Novo boleto".'
                              : 'Nenhum boleto cadastrado.')
                          : 'Nenhum boleto neste filtro.',
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, box) {
                      final compact = box.maxWidth < _compactTable;
                      return Column(
                        children: [
                          if (!compact) const _BillHeader(),
                          for (final bill in bills)
                            _BillRow(
                              bill: bill,
                              compact: compact,
                              editable: premium,
                              onToggle: () => _toggle(state, bill),
                              onDelete: () => _delete(state, bill),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BillHeader extends StatelessWidget {
  const _BillHeader();

  @override
  Widget build(BuildContext context) {
    final style = WebTableHeader.style;
    return WebTableHeader(
      children: [
        Expanded(flex: 4, child: Text('FORNECEDOR', style: style)),
        Expanded(flex: 2, child: Text('PARCELA', style: style)),
        Expanded(flex: 2, child: Text('VENCIMENTO', style: style)),
        Expanded(flex: 2, child: Text('SITUAÇÃO', style: style)),
        SizedBox(
          width: 110,
          child: Text('VALOR', textAlign: TextAlign.right, style: style),
        ),
        const SizedBox(width: _actionsWidth),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.bill,
    required this.compact,
    required this.editable,
    required this.onToggle,
    required this.onDelete,
  });

  final Bill bill;
  final bool compact;
  final bool editable;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final (label, color) = bill.pago
        ? ('Pago', AppColors.success)
        : bill.isOverdue
            ? ('Atrasado', AppColors.danger)
            : ('A vencer', AppColors.warning);
    final parcela = bill.parcelado ? '${bill.parcela}/${bill.totalParcelas}' : '—';
    final actions = SizedBox(
      width: _actionsWidth,
      child: !editable
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onToggle,
                  child: Text(bill.pago ? 'Desfazer' : 'Marcar pago'),
                ),
                IconButton(
                  tooltip: 'Excluir',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppColors.mutedDark,
                ),
              ],
            ),
    );
    final value = SizedBox(
      width: 110,
      child: Text(
        Money.full(bill.valor),
        textAlign: TextAlign.right,
        style: webText(13.5, weight: FontWeight.w800),
      ),
    );
    final name = Text(
      bill.fornecedor,
      overflow: TextOverflow.ellipsis,
      style: webText(13.5, weight: FontWeight.w700),
    );
    final muted = webText(13, weight: FontWeight.w500, color: AppColors.mutedDark);
    if (compact) {
      return WebTableRow(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  name,
                  const SizedBox(height: 2),
                  Text(
                    bill.parcelado
                        ? '$parcela · ${Dates.full(bill.dataVencimento)}'
                        : Dates.full(bill.dataVencimento),
                    style: muted,
                  ),
                  const SizedBox(height: 4),
                  WebBadge(label, color: color),
                ],
              ),
            ),
          ),
          value,
          actions,
        ],
      );
    }
    return WebTableRow(
      children: [
        Expanded(flex: 4, child: name),
        Expanded(flex: 2, child: Text(parcela, style: muted)),
        Expanded(flex: 2, child: Text(Dates.full(bill.dataVencimento), style: muted)),
        Expanded(flex: 2, child: WebBadge(label, color: color)),
        value,
        actions,
      ],
    );
  }
}
