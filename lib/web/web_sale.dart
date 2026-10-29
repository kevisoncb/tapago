import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../screens/add_debt_page.dart' show phoneTakenMessage;
import '../services/client_match.dart';
import '../services/debt_installments.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/input_masks.dart';
import '../utils/masks.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';
import '../widgets/product_items_editor.dart';
import 'web_widgets.dart';

/// Lançamento de venda a prazo pelo computador: cliente, valor (ou produtos),
/// vencimento e parcelas. Grava pelo mesmo caminho do aplicativo.
class WebSale extends StatefulWidget {
  const WebSale({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<WebSale> createState() => _WebSaleState();
}

class _WebSaleState extends State<WebSale> {
  final _nome = TextEditingController();
  final _nomeFocus = FocusNode();
  final _whatsapp = TextEditingController();
  final _valor = TextEditingController();
  final _juros = TextEditingController();
  final _date = TextEditingController();
  final List<DebtItem> _itens = [];
  DateTime? _vencimento;
  var _parcelas = 1;
  var _produto = false;
  var _saving = false;

  @override
  void dispose() {
    _nome.dispose();
    _nomeFocus.dispose();
    _whatsapp.dispose();
    _valor.dispose();
    _juros.dispose();
    _date.dispose();
    super.dispose();
  }

  double get _principal => parseMoneyInput(_valor.text);
  double get _taxa => parsePercentInput(_juros.text);
  bool get _parcelado => _parcelas > 1;

  List<DebtInstallment> get _preview {
    final date = _vencimento;
    if (!_parcelado || date == null || _principal <= 0) return const [];
    try {
      return splitReceivable(
        total: _principal,
        firstDue: date,
        installments: _parcelas,
      );
    } catch (_) {
      return const [];
    }
  }

  void _syncItems() {
    final total = _itens.fold(0.0, (sum, item) => sum + item.total);
    _valor.text = total > 0 ? Money.full(total) : '';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _vencimento ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _vencimento = picked;
      _date.text = Dates.full(picked);
    });
  }

  void _fillFrom(CadernetaContact contact) {
    setState(() {
      _nome.text = contact.nome;
      _whatsapp.text = formatPhoneBr(contact.telefone);
    });
  }

  Future<void> _save(AppController state) async {
    if (_saving) return;
    final phone = digitsOnly(_whatsapp.text);
    if (_nome.text.trim().isEmpty || _principal <= 0 || _vencimento == null) {
      showPagoSnack(context, 'Informe o cliente, o valor e o vencimento.');
      return;
    }
    if (phone.isNotEmpty && phone.length < 10) {
      showPagoSnack(context, 'Confira o WhatsApp (com DDD) ou deixe em branco.');
      return;
    }
    final contact = groupContacts(state.debts)
        .where((item) => foldClientName(item.nome) == foldClientName(_nome.text))
        .firstOrNull;
    final blocked = firstBlockingHit(
      debts: state.debts,
      nome: _nome.text,
      telefone: _whatsapp.text,
      allowPhone: contact?.telefone,
      allowNome: contact?.nome,
    );
    if (blocked != null) {
      showPagoSnack(
        context,
        blocked.phoneTaken
            ? phoneTakenMessage
            : '${blocked.debt.nome} já está na caderneta.',
      );
      return;
    }
    if (!_principal.isFinite || _principal > 100000000 || _taxa > 1000) {
      showPagoSnack(context, 'Confira o valor e a taxa informados.');
      return;
    }
    if ((_parcelado || _produto) && !state.user.premiumAtivo) {
      showPagoSnack(
        context,
        'Parcelamento e lançamento por produto precisam de Premium ativo.',
      );
      return;
    }
    if (_produto && _itens.isEmpty) {
      showPagoSnack(context, 'Adicione ao menos um produto ou desligue "Foi produto?".');
      return;
    }
    final preview = _preview;
    if (_parcelado && (preview.isEmpty || _taxa != 0)) {
      showPagoSnack(
        context,
        'No parcelamento informe o total combinado, sem juros adicionais.',
      );
      return;
    }

    final count = _parcelado ? _parcelas : 1;
    final grupo = _parcelado ? state.newId() : '';
    final now = DateTime.now();
    final next = [
      for (var i = 0; i < count; i++)
        Debt(
          id: state.newId(),
          userId: state.user.id,
          nome: _nome.text.trim(),
          telefone: phone,
          valorPrincipal: _parcelado ? preview[i].valor : _principal,
          taxaJuros: _parcelado ? 0 : _taxa,
          dataVencimento: _parcelado ? preview[i].vencimento : _vencimento!,
          statusPago: false,
          clientScore: 80,
          createdAt: now,
          grupoId: grupo,
          parcela: i + 1,
          totalParcelas: count,
          itens: i == 0 && _produto ? List.of(_itens) : const [],
        ),
    ];
    setState(() => _saving = true);
    try {
      await state.createDebts(next);
      if (!mounted) return;
      showPagoSnack(context, 'Venda lançada para ${_nome.text.trim()}.');
      widget.onDone();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showPagoSnack(
        context,
        'Não foi possível confirmar o salvamento. Tente novamente.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final premium = state.user.premiumAtivo;
    final contacts = groupContacts(state.debts);
    final preview = _preview;
    return WebPage(
      title: 'Venda',
      subtitle: 'Lance uma venda a prazo para um cliente.',
      maxWidth: 720,
      child: WebCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RawAutocomplete<CadernetaContact>(
              textEditingController: _nome,
              focusNode: _nomeFocus,
              displayStringForOption: (option) => option.nome,
              optionsBuilder: (value) {
                final needle = foldClientName(value.text.trim());
                if (needle.isEmpty) return const Iterable.empty();
                return contacts
                    .where((c) => foldClientName(c.nome).contains(needle))
                    .take(6);
              },
              onSelected: _fillFrom,
              fieldViewBuilder: (context, controller, focus, onSubmit) {
                return AppTextField(
                  label: 'Cliente',
                  hint: 'Nome do cliente',
                  icon: Icons.person_outline_rounded,
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 80,
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: [
                          for (final option in options)
                            ListTile(
                              dense: true,
                              title: Text(option.nome),
                              subtitle: option.telefone.isEmpty
                                  ? null
                                  : Text(formatPhoneBr(option.telefone)),
                              onTap: () => onSelected(option),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'WhatsApp (opcional)',
              hint: '(00) 00000-0000',
              icon: Icons.phone_outlined,
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneMaskFormatter()],
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _produto,
              onChanged: (on) {
                if (on && !premium) {
                  showPagoSnack(context, 'Lançamento por produto é do Premium.');
                  return;
                }
                setState(() {
                  _produto = on;
                  if (!on) {
                    _itens.clear();
                  }
                });
              },
              title: Text('Foi produto?', style: webText(15, weight: FontWeight.w700)),
              subtitle: Text(
                premium
                    ? 'Anote o que o cliente levou; a soma vira o valor.'
                    : 'Premium: anote o que o cliente levou.',
                style: webText(13, weight: FontWeight.w500, color: AppColors.mutedDark),
              ),
            ),
            if (_produto)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ProductItemsEditor(
                  itens: _itens,
                  onAdd: (item) => setState(() {
                    _itens.add(item);
                    _syncItems();
                  }),
                  onRemove: (index) => setState(() {
                    _itens.removeAt(index);
                    _syncItems();
                  }),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: _parcelado ? 'Total combinado' : 'Valor',
                    hint: 'R\$ 0,00',
                    icon: Icons.attach_money_rounded,
                    controller: _valor,
                    readOnly: _produto,
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyMaskFormatter()],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AppTextField(
                    label: _parcelado ? '1º vencimento' : 'Vencimento',
                    hint: 'dd/mm/aaaa',
                    icon: Icons.event_outlined,
                    controller: _date,
                    readOnly: true,
                    onTap: _pickDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _parcelas,
                    decoration: const InputDecoration(labelText: 'Parcelas'),
                    items: [
                      for (var i = 1; i <= 12; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(i == 1 ? 'À vista (1x)' : '${i}x'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      if (value > 1 && !premium) {
                        showPagoSnack(context, 'Parcelamento é do Premium.');
                        return;
                      }
                      setState(() => _parcelas = value);
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AppTextField(
                    label: 'Juros (%)',
                    hint: '0',
                    icon: Icons.percent_rounded,
                    controller: _juros,
                    readOnly: _parcelado || _produto,
                    keyboardType: TextInputType.number,
                    inputFormatters: [PercentMaskFormatter()],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final item in preview)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    '${item.parcela} de ${item.totalParcelas} · ${Money.full(item.valor)} · ${Dates.full(item.vencimento)}',
                    style: webText(14, weight: FontWeight.w500, color: AppColors.mutedDark),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : () => _save(state),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
              ),
              child: Text(_saving ? 'Salvando…' : 'Lançar venda'),
            ),
          ],
        ),
      ),
    );
  }
}
