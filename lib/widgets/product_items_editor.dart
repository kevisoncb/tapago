import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../services/product_report.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'amount_keypad.dart';
import 'common.dart';
import 'fields.dart';

/// Lista de produtos levados (ex.: 5 × Skol Beats 550ml a R$ 8,00). A soma vira
/// o valor do lançamento; a data e a hora de cada item são gravadas sozinhas.
class ProductItemsEditor extends StatelessWidget {
  const ProductItemsEditor({
    super.key,
    required this.itens,
    required this.onAdd,
    required this.onRemove,
  });

  final List<DebtItem> itens;
  final ValueChanged<DebtItem> onAdd;
  final ValueChanged<int> onRemove;

  double get total => itens.fold(0.0, (sum, item) => sum + item.total);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < itens.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itens[i].nome,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${quantityLabel(itens[i].quantidade)} × ${Money.full(itens[i].valorUnitario)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.mutedDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Money.full(itens[i].total),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  tooltip: 'Remover item',
                  onPressed: () => onRemove(i),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: () async {
            final item = await showAddItemSheet(context);
            if (item != null) onAdd(item);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar item'),
        ),
        if (itens.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total dos itens',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  Text(
                    Money.full(total),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Future<DebtItem?> showAddItemSheet(BuildContext context) {
  return showModalBottomSheet<DebtItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _AddItemSheet(),
  );
}

class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet();

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _nome = TextEditingController();
  final _qtd = TextEditingController(text: '1');
  final _valor = TextEditingController();
  double _unit = 0;

  @override
  void dispose() {
    _nome.dispose();
    _qtd.dispose();
    _valor.dispose();
    super.dispose();
  }

  double get _quantidade =>
      double.tryParse(_qtd.text.trim().replaceAll(',', '.')) ?? 0;

  void _save() {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      showPagoSnack(context, 'Informe o nome do produto.');
      return;
    }
    if (_quantidade <= 0 || _quantidade > 9999) {
      showPagoSnack(context, 'Informe a quantidade.');
      return;
    }
    if (_unit <= 0) {
      showPagoSnack(context, 'Informe o valor de cada unidade.');
      return;
    }
    Navigator.pop(
      context,
      DebtItem(
        nome: nome,
        quantidade: _quantidade,
        valorUnitario: _unit,
        em: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Produto',
              hint: 'Ex.: Skol Beats 550ml',
              icon: Icons.shopping_basket_outlined,
              controller: _nome,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(60)],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Quantidade',
                    hint: '1',
                    icon: Icons.numbers_rounded,
                    controller: _qtd,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    label: 'Valor un.',
                    hint: r'R$ 0,00',
                    icon: Icons.attach_money_rounded,
                    controller: _valor,
                    readOnly: true,
                    onTap: () async {
                      final value = await showAmountKeypad(
                        context: context,
                        title: 'Valor de cada unidade',
                        confirmLabel: 'Usar valor',
                      );
                      if (value == null || !mounted) return;
                      setState(() {
                        _unit = value;
                        _valor.text = Money.full(value);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _unit > 0 && _quantidade > 0
                    ? 'Subtotal ${Money.full((_quantidade * _unit * 100).round() / 100)}'
                    : 'A data e a hora ficam registradas sozinhas.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedDark,
                ),
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(label: 'Adicionar', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
