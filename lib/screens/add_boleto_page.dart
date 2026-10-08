import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/boleto_code.dart';
import '../utils/formatters.dart';
import '../utils/input_masks.dart';
import '../utils/masks.dart';
import '../widgets/amount_keypad.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

class AddBoletoPage extends StatefulWidget {
  const AddBoletoPage({super.key, this.boleto});

  final Boleto? boleto;

  @override
  State<AddBoletoPage> createState() => _AddBoletoPageState();
}

class _AddBoletoPageState extends State<AddBoletoPage> {
  final _empresa = TextEditingController();
  final _cnpj = TextEditingController();
  final _codigo = TextEditingController();
  final _descricao = TextEditingController();
  final _valor = TextEditingController();
  final _date = TextEditingController();
  DateTime? _vencimento;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final boleto = widget.boleto;
    if (boleto == null) return;
    _empresa.text = boleto.empresa;
    _cnpj.text = formatCnpj(boleto.cnpj);
    _codigo.text = formatBoletoCode(boleto.linhaDigitavel);
    _descricao.text = boleto.descricao;
    _valor.text = Money.full(boleto.valor);
    _vencimento = boleto.dataVencimento;
    _date.text = Dates.full(boleto.dataVencimento);
  }

  @override
  void dispose() {
    _empresa.dispose();
    _cnpj.dispose();
    _codigo.dispose();
    _descricao.dispose();
    _valor.dispose();
    _date.dispose();
    super.dispose();
  }

  double get _valorAtual => parseMoneyInput(_valor.text);

  void _onCodigoChanged(String value) {
    final info = readBoletoCode(value);
    if (info == null) return;
    final filled = <String>[];
    setState(() {
      if (info.valor != null) {
        _valor.text = Money.full(info.valor!);
        filled.add('valor');
      }
      if (info.vencimento != null) {
        _vencimento = info.vencimento;
        _date.text = Dates.full(info.vencimento!);
        filled.add('vencimento');
      }
    });
    if (filled.isNotEmpty) {
      showTapagoSnack(context, 'Li o código: preenchi ${filled.join(' e ')}.');
    }
  }

  Future<void> _pasteCodigo() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (digitsOnly(text).isEmpty) {
      if (mounted) showTapagoSnack(context, 'Nada para colar.');
      return;
    }
    _codigo.text = formatBoletoCode(text);
    _onCodigoChanged(_codigo.text);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: _vencimento ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Vencimento do boleto',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (selected != null) {
      setState(() {
        _vencimento = selected;
        _date.text = Dates.full(selected);
      });
    }
  }

  Future<void> _save() async {
    final cnpj = digitsOnly(_cnpj.text);
    final codigo = digitsOnly(_codigo.text);
    if (_empresa.text.trim().isEmpty || _valorAtual <= 0 || _vencimento == null) {
      showTapagoSnack(context, 'Preencha empresa, valor e vencimento.');
      return;
    }
    if (cnpj.isNotEmpty && !isValidCnpj(cnpj)) {
      showTapagoSnack(context, 'CNPJ inválido. Confira os números.');
      return;
    }
    if (codigo.isNotEmpty && !isValidBoletoCode(codigo)) {
      showTapagoSnack(
        context,
        'Código incompleto. Boleto tem 47 números (contas de consumo, 48).',
      );
      return;
    }

    final state = context.read<AppController>();
    final existing = widget.boleto;
    final boleto = Boleto(
      id: existing?.id ?? state.newId(),
      userId: state.user.id,
      empresa: _empresa.text.trim(),
      cnpj: cnpj,
      descricao: _descricao.text.trim(),
      valor: _valorAtual,
      dataVencimento: _vencimento!,
      linhaDigitavel: codigo,
      statusPago: existing?.statusPago ?? false,
      pagoEm: existing?.pagoEm,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    setState(() => _saving = true);
    try {
      await state.upsertBoleto(boleto);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      showTapagoSnack(context, 'Não deu para salvar o boleto. Tente de novo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.boleto == null ? 'Novo boleto' : 'Editar boleto'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                AppTextField(
                  label: 'Código do boleto',
                  hint: 'Cole ou digite a linha digitável',
                  icon: Icons.qr_code_2_rounded,
                  controller: _codigo,
                  keyboardType: TextInputType.number,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [BoletoCodeMaskFormatter()],
                  maxLines: 2,
                  onChanged: _onCodigoChanged,
                  suffix: IconButton(
                    tooltip: 'Colar',
                    onPressed: _pasteCodigo,
                    icon: const Icon(
                      Icons.content_paste_rounded,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Opcional. Com o código, o valor e o vencimento são preenchidos sozinhos.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedDark,
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Empresa',
                  hint: 'Ex: Distribuidora Silva',
                  icon: Icons.business_rounded,
                  controller: _empresa,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 80,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'CNPJ (opcional)',
                  hint: '00.000.000/0000-00',
                  icon: Icons.badge_outlined,
                  controller: _cnpj,
                  keyboardType: TextInputType.number,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [CnpjMaskFormatter()],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Valor',
                        hint: r'R$ 0,00',
                        icon: Icons.attach_money_rounded,
                        controller: _valor,
                        readOnly: true,
                        onTap: () async {
                          final value = await showAmountKeypad(
                            context: context,
                            title: 'Valor do boleto',
                            confirmLabel: 'Usar valor',
                            initial: _valorAtual > 0 ? _valorAtual : null,
                          );
                          if (value == null || !mounted) return;
                          setState(() => _valor.text = Money.full(value));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: 'Vencimento',
                        hint: 'Selecionar',
                        icon: Icons.event_outlined,
                        readOnly: true,
                        onTap: _pickDate,
                        controller: _date,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Descrição (opcional)',
                  hint: 'Ex: Mercadoria de outubro, aluguel, DAS',
                  icon: Icons.notes_rounded,
                  controller: _descricao,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 120,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Aviso às 9h: 3 dias antes, na véspera, no dia e enquanto estiver vencido.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                label: _saving ? 'Salvando...' : 'Salvar boleto',
                onPressed: _saving ? null : _save,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
