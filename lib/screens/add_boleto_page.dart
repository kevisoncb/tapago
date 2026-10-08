import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/boleto_code.dart';
import '../utils/boleto_prazo.dart';
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

enum _Prazo { avista, p15, p30, outro }

const _prazoLabels = {
  _Prazo.avista: 'À vista',
  _Prazo.p15: '15/30/45',
  _Prazo.p30: '30/45/60',
  _Prazo.outro: 'Outro',
};

class _AddBoletoPageState extends State<AddBoletoPage> {
  final _prazoDias = TextEditingController();
  var _prazo = _Prazo.avista;
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
    _prazoDias.dispose();
    _empresa.dispose();
    _cnpj.dispose();
    _codigo.dispose();
    _descricao.dispose();
    _valor.dispose();
    _date.dispose();
    super.dispose();
  }

  double get _valorAtual => parseMoneyInput(_valor.text);

  bool get _parcelado => widget.boleto == null && _prazo != _Prazo.avista;

  List<int>? get _dias {
    switch (_prazo) {
      case _Prazo.avista:
        return null;
      case _Prazo.p15:
        return const [15, 30, 45];
      case _Prazo.p30:
        return const [30, 45, 60];
      case _Prazo.outro:
        return parsePrazoDias(_prazoDias.text);
    }
  }

  void _setPrazo(_Prazo prazo) {
    setState(() {
      _prazo = prazo;
      if (prazo != _Prazo.avista && _vencimento == null) {
        final now = DateTime.now();
        _vencimento = DateTime(now.year, now.month, now.day);
        _date.text = Dates.full(_vencimento!);
      }
    });
  }

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
      helpText: _parcelado ? 'Data da compra' : 'Vencimento do boleto',
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
    if (_empresa.text.trim().isEmpty ||
        _valorAtual <= 0 ||
        _vencimento == null) {
      showTapagoSnack(context, 'Preencha empresa, valor e vencimento.');
      return;
    }
    if (cnpj.isNotEmpty && !isValidCnpj(cnpj)) {
      showTapagoSnack(context, 'CNPJ inválido. Confira os números.');
      return;
    }
    if (_parcelado) {
      await _saveParcelas(cnpj);
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
      parcela: existing?.parcela ?? 0,
      parcelas: existing?.parcelas ?? 0,
      grupoId: existing?.grupoId ?? '',
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

  Future<void> _saveParcelas(String cnpj) async {
    final dias = _dias;
    if (dias == null) {
      showTapagoSnack(context, 'Digite os dias do prazo, ex: 28/56/84.');
      return;
    }
    if (_valorAtual < dias.length / 100) {
      showTapagoSnack(context, 'Valor pequeno demais para dividir.');
      return;
    }
    final state = context.read<AppController>();
    final grupo = state.newId();
    final valores = dividirParcelas(_valorAtual, dias.length);
    final datas = vencimentosParcelas(_vencimento!, dias);
    final now = DateTime.now();
    final novos = [
      for (var i = 0; i < dias.length; i++)
        Boleto(
          id: state.newId(),
          userId: state.user.id,
          empresa: _empresa.text.trim(),
          cnpj: cnpj,
          descricao: _descricao.text.trim(),
          valor: valores[i],
          dataVencimento: datas[i],
          createdAt: now,
          parcela: dias.length > 1 ? i + 1 : 0,
          parcelas: dias.length > 1 ? dias.length : 0,
          grupoId: dias.length > 1 ? grupo : '',
        ),
    ];
    setState(() => _saving = true);
    try {
      await state.addBoletos(novos);
      if (!mounted) return;
      Navigator.of(context).pop();
      showTapagoSnack(
        context,
        novos.length == 1
            ? 'Boleto salvo.'
            : '${novos.length} parcelas criadas. Toque em cada uma para colar o código.',
      );
    } catch (_) {
      if (!mounted) return;
      showTapagoSnack(
        context,
        'Não deu para salvar as parcelas. Tente de novo.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dias = _dias;
    final preview =
        _parcelado && dias != null && _vencimento != null && _valorAtual > 0
        ? (
            valores: dividirParcelas(_valorAtual, dias.length),
            datas: vencimentosParcelas(_vencimento!, dias),
          )
        : null;
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
                if (widget.boleto == null) ...[
                  Text(
                    'Prazo de pagamento',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final prazo in _Prazo.values)
                        ChoiceChip(
                          label: Text(_prazoLabels[prazo]!),
                          selected: _prazo == prazo,
                          onSelected: (_) => _setPrazo(prazo),
                          selectedColor: AppColors.primarySoft,
                          labelStyle: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: _prazo == prazo
                                ? AppColors.primary
                                : AppColors.text,
                          ),
                        ),
                    ],
                  ),
                  if (_prazo == _Prazo.outro) ...[
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Dias depois da compra',
                      hint: 'Ex: 28/56/84',
                      icon: Icons.date_range_outlined,
                      controller: _prazoDias,
                      keyboardType: TextInputType.datetime,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: 80,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: 18),
                ],
                if (!_parcelado) ...[
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
                ],
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
                        label: _parcelado ? 'Valor total' : 'Valor',
                        hint: r'R$ 0,00',
                        icon: Icons.attach_money_rounded,
                        controller: _valor,
                        readOnly: true,
                        onTap: () async {
                          final value = await showAmountKeypad(
                            context: context,
                            title: _parcelado
                                ? 'Valor total da compra'
                                : 'Valor do boleto',
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
                        label: _parcelado ? 'Data da compra' : 'Vencimento',
                        hint: 'Selecionar',
                        icon: Icons.event_outlined,
                        readOnly: true,
                        onTap: _pickDate,
                        controller: _date,
                      ),
                    ),
                  ],
                ),
                if (preview != null) ...[
                  const SizedBox(height: 16),
                  _ParcelasPreview(
                    valores: preview.valores,
                    datas: preview.datas,
                  ),
                ] else if (_prazo == _Prazo.outro && dias == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Separe os dias por barra, em ordem crescente. Ex: 30/60/90.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedDark,
                    ),
                  ),
                ],
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
                label: _saving
                    ? 'Salvando...'
                    : _parcelado && (dias?.length ?? 0) > 1
                    ? 'Criar ${dias!.length} parcelas'
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

class _ParcelasPreview extends StatelessWidget {
  const _ParcelasPreview({required this.valores, required this.datas});

  final List<double> valores;
  final List<DateTime> datas;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.plusJakartaSans(
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < valores.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Text(
                    valores.length == 1 ? 'Vence' : '${i + 1}ª parcela',
                    style: style.copyWith(color: AppColors.mutedDark),
                  ),
                  const Spacer(),
                  Text(Dates.full(datas[i]), style: style),
                  const SizedBox(width: 14),
                  Text(
                    Money.full(valores[i]),
                    style: style.copyWith(
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
