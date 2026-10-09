import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/bill_installments.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/amount_keypad.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

class AddBillPage extends StatefulWidget {
  const AddBillPage({super.key});

  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> {
  final _fornecedor = TextEditingController();
  final _valor = TextEditingController();
  final _date = TextEditingController();
  final _base = TextEditingController();
  final _codigo = TextEditingController();
  final _prazosCustom = TextEditingController();
  double _total = 0;
  bool _parcelado = false;
  DateTime? _vencimento;
  DateTime _dataCompra = DateTime.now();
  List<int>? _preset = billPresets.first;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _base.text = Dates.full(_dataCompra);
  }

  @override
  void dispose() {
    _fornecedor.dispose();
    _valor.dispose();
    _date.dispose();
    _base.dispose();
    _codigo.dispose();
    _prazosCustom.dispose();
    super.dispose();
  }

  List<int>? get _prazos => _preset ?? parsePrazos(_prazosCustom.text);

  List<BillInstallment> get _parcelas {
    final prazos = _prazos;
    if (prazos == null) return const [];
    return splitBill(total: _total, base: _dataCompra, prazos: prazos);
  }

  Future<DateTime?> _pick(DateTime initial, String help) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: help,
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
  }

  Future<void> _pickVencimento() async {
    final selected = await _pick(
      _vencimento ?? DateTime.now().add(const Duration(days: 7)),
      'Vencimento do boleto',
    );
    if (selected == null) return;
    setState(() {
      _vencimento = selected;
      _date.text = Dates.full(selected);
    });
  }

  Future<void> _pickBase() async {
    final selected = await _pick(_dataCompra, 'Data da compra');
    if (selected == null) return;
    setState(() {
      _dataCompra = selected;
      _base.text = Dates.full(selected);
    });
  }

  Future<void> _save() async {
    final fornecedor = _fornecedor.text.trim();
    if (fornecedor.isEmpty || _total <= 0) {
      showPagoSnack(context, 'Preencha fornecedor e valor.');
      return;
    }
    final state = context.read<AppController>();
    final grupoId = state.newId();
    final now = DateTime.now();
    final List<Bill> bills;

    if (_parcelado) {
      final parcelas = _parcelas;
      if (parcelas.isEmpty) {
        showPagoSnack(context, 'Escolha os prazos, ex.: 30/60/90.');
        return;
      }
      bills = [
        for (final item in parcelas)
          Bill(
            id: state.newId(),
            userId: state.user.id,
            fornecedor: fornecedor,
            valor: item.valor,
            dataVencimento: item.vencimento,
            grupoId: grupoId,
            parcela: item.parcela,
            totalParcelas: parcelas.length,
            createdAt: now,
          ),
      ];
    } else {
      if (_vencimento == null) {
        showPagoSnack(context, 'Escolha o vencimento.');
        return;
      }
      final codigo = normalizeBoletoCode(_codigo.text);
      if (codigo == null) {
        showPagoSnack(context, 'O código do boleto tem 47 ou 48 números.');
        return;
      }
      bills = [
        Bill(
          id: state.newId(),
          userId: state.user.id,
          fornecedor: fornecedor,
          valor: _total,
          dataVencimento: _vencimento!,
          codigo: codigo,
          grupoId: grupoId,
          createdAt: now,
        ),
      ];
    }

    setState(() => _saving = true);
    try {
      await state.addBills(bills);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showPagoSnack(context, 'Não foi possível salvar. Confira o Premium e a conexão.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcelas = _parcelado ? _parcelas : const <BillInstallment>[];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Novo boleto'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                AppTextField(
                  label: 'Fornecedor',
                  hint: 'Ex: Distribuidora Silva',
                  icon: Icons.storefront_outlined,
                  controller: _fornecedor,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 80,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: _parcelado ? 'Valor total' : 'Valor',
                  hint: r'R$ 0,00',
                  icon: Icons.attach_money_rounded,
                  controller: _valor,
                  readOnly: true,
                  onTap: () async {
                    final value = await showAmountKeypad(
                      context: context,
                      title: 'Valor do boleto',
                      confirmLabel: 'Usar valor',
                    );
                    if (value == null || !mounted) return;
                    setState(() {
                      _total = value;
                      _valor.text = Money.full(value);
                    });
                  },
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('À vista')),
                    ButtonSegment(value: true, label: Text('Parcelado')),
                  ],
                  selected: {_parcelado},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _parcelado = value.first),
                ),
                const SizedBox(height: 16),
                if (!_parcelado) ...[
                  AppTextField(
                    label: 'Vencimento',
                    hint: 'Selecionar data',
                    icon: Icons.event_outlined,
                    readOnly: true,
                    onTap: _pickVencimento,
                    controller: _date,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Código do boleto (opcional)',
                    hint: 'Cole a linha digitável',
                    icon: Icons.qr_code_2_rounded,
                    controller: _codigo,
                    keyboardType: TextInputType.number,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 60,
                  ),
                  const SizedBox(height: 8),
                  _Hint('Na hora de pagar, um toque copia o código para o app do banco.'),
                ] else ...[
                  AppTextField(
                    label: 'Data da compra',
                    hint: 'Selecionar data',
                    icon: Icons.event_outlined,
                    readOnly: true,
                    onTap: _pickBase,
                    controller: _base,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Prazos (dias)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in billPresets)
                        ChoiceChip(
                          label: Text(prazosLabel(preset)),
                          selected: _preset == preset,
                          onSelected: (_) => setState(() => _preset = preset),
                        ),
                      ChoiceChip(
                        label: const Text('Outro'),
                        selected: _preset == null,
                        onSelected: (_) => setState(() => _preset = null),
                      ),
                    ],
                  ),
                  if (_preset == null) ...[
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Seus prazos',
                      hint: 'Ex: 28/56/84',
                      icon: Icons.date_range_outlined,
                      controller: _prazosCustom,
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9/ ,]')),
                      ],
                      maxLength: 40,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (parcelas.isNotEmpty && _total > 0)
                    _Preview(parcelas: parcelas)
                  else
                    _Hint('Digite o valor e os prazos para ver as parcelas.'),
                  const SizedBox(height: 8),
                  _Hint('O código de cada parcela você cola depois, na lista de boletos.'),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                label: _parcelado && parcelas.length > 1
                    ? 'Salvar ${parcelas.length} parcelas'
                    : 'Salvar boleto',
                onPressed: _saving ? null : _save,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.mutedDark,
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.parcelas});

  final List<BillInstallment> parcelas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (final item in parcelas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(
                    '${item.parcela} de ${parcelas.length}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    Dates.full(item.vencimento),
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.mutedDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Money.full(item.valor),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
