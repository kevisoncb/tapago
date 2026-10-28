import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/client_match.dart';
import '../services/debt_installments.dart';
import '../services/speech_capture.dart';
import '../services/voice_debt_parser.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/input_masks.dart';
import '../utils/masks.dart';
import '../widgets/amount_keypad.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';
import 'contact_history_page.dart';
import 'premium_page.dart';

class AddDebtPage extends StatefulWidget {
  const AddDebtPage({
    super.key,
    this.debt,
    this.prefillNome,
    this.prefillTelefone,
  });

  final Debt? debt;
  final String? prefillNome;
  final String? prefillTelefone;

  @override
  State<AddDebtPage> createState() => _AddDebtPageState();
}

class _AddDebtPageState extends State<AddDebtPage> {
  final _nome = TextEditingController();
  final _whatsapp = TextEditingController();
  final _valor = TextEditingController();
  final _juros = TextEditingController();
  final _date = TextEditingController();
  DateTime? _vencimento;
  bool _listening = false;
  String _heard = '';
  final _voice = SpeechCapture();
  bool _saving = false;
  bool _parcelado = false;
  int _parcelas = 3;
  String? _grupoId;
  final List<String> _newIds = [];
  List<Debt>? _pendingSave;

  @override
  void initState() {
    super.initState();
    final debt = widget.debt;
    if (debt != null) {
      _nome.text = debt.nome;
      _whatsapp.text = formatPhoneBr(debt.telefone);
      _valor.text = Money.full(debt.valorPrincipal);
      if (debt.taxaJuros > 0) {
        final taxa = debt.taxaJuros;
        _juros.text = taxa == taxa.roundToDouble()
            ? taxa.toStringAsFixed(0)
            : taxa.toStringAsFixed(2).replaceAll('.', ',');
      }
      _vencimento = debt.dataVencimento;
      _date.text = Dates.full(debt.dataVencimento);
    } else {
      if (widget.prefillNome != null) {
        _nome.text = widget.prefillNome!;
      }
      if (widget.prefillTelefone != null &&
          widget.prefillTelefone!.trim().isNotEmpty) {
        _whatsapp.text = formatPhoneBr(widget.prefillTelefone!);
      }
    }
  }

  @override
  void dispose() {
    unawaited(_voice.dispose());
    _nome.dispose();
    _whatsapp.dispose();
    _valor.dispose();
    _juros.dispose();
    _date.dispose();
    super.dispose();
  }

  double get _principal => parseMoneyInput(_valor.text);

  double get _taxa => parsePercentInput(_juros.text);

  double get _total => _principal * (1 + _taxa / 100);

  bool _financialLocked(AppController state) {
    final debt = widget.debt;
    return debt != null &&
        (debt.statusPago || state.paymentsFor(debt.id).isNotEmpty);
  }

  List<DebtInstallment> get _preview {
    final date = _vencimento;
    if (!_parcelado || date == null || _principal <= 0) return const [];
    try {
      return splitReceivable(
        total: _principal,
        firstDue: date,
        installments: _parcelas,
      );
    } on ArgumentError {
      return const [];
    }
  }

  Future<void> _setParcelado(bool enabled) async {
    if (_saving || _pendingSave != null) return;
    if (enabled && !context.read<AppController>().user.premiumAtivo) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PremiumPage()));
      return;
    }
    if (enabled && _taxa > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Valor total da venda'),
          content: const Text(
            'No parcelamento, informe o valor total já combinado com o cliente. '
            'Quer zerar o campo de juros para dividir esse total em parcelas?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Manter lançamento único'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Zerar juros e parcelar'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      _juros.clear();
    }
    if (mounted) setState(() => _parcelado = enabled);
  }

  Future<void> _pickDate() async {
    if (_saving ||
        _pendingSave != null ||
        _financialLocked(context.read<AppController>())) {
      return;
    }
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: _vencimento ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Data de Vencimento',
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

  Future<void> _listenVoice() async {
    final state = context.read<AppController>();
    if (_saving || _pendingSave != null || _financialLocked(state)) return;
    if (!state.user.premiumAtivo) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PremiumPage()));
      return;
    }
    if (_listening) {
      await _voice.stop();
      return;
    }

    setState(() {
      _listening = true;
      _heard = '';
    });
    final spoken = await _voice.listenOnce(
      onPartial: (words) {
        if (!mounted) return;
        setState(() => _heard = words);
      },
    );
    if (!mounted) return;
    setState(() => _listening = false);

    final text = spoken?.trim() ?? '';
    if (text.isEmpty) {
      showPagoSnack(
        context,
        'Não ouvi. Permita o microfone e fale, por exemplo: Maria, 200 reais, vence dia 20.',
      );
      return;
    }

    final draft = parseVoiceDebt(text);
    if (!draft.hasAny) {
      showPagoSnack(
        context,
        'Ouvi “$text”, mas não deu para montar o lançamento. Fale o nome, o valor em reais e o vencimento.',
      );
      return;
    }

    setState(() {
      _heard = text;
      if (draft.nome != null && draft.nome!.isNotEmpty) {
        _nome.text = draft.nome!;
      }
      if (draft.telefone != null) {
        _whatsapp.text = formatPhoneBr(draft.telefone!);
      }
      if (draft.valor != null && draft.valor! > 0) {
        _valor.text = Money.full(draft.valor!);
      }
      if (draft.juros != null && !_parcelado) {
        final taxa = draft.juros!;
        _juros.text = taxa == taxa.roundToDouble()
            ? taxa.toStringAsFixed(0)
            : taxa.toStringAsFixed(2).replaceAll('.', ',');
      }
      if (draft.vencimento != null) {
        _vencimento = draft.vencimento;
        _date.text = Dates.full(draft.vencimento!);
      }
    });

    final filled = <String>[
      if (draft.nome != null) 'nome',
      if (draft.telefone != null) 'WhatsApp',
      if (draft.valor != null) 'valor',
      if (draft.juros != null) 'juros',
      if (draft.vencimento != null) 'vencimento',
    ];
    showPagoSnack(context, 'Preenchi ${filled.join(', ')}. Confira e salve.');
  }

  Future<void> _save() async {
    if (_saving) return;
    final state = context.read<AppController>();
    // Após uma falha, reenviar exatamente a mesma operação evita gerar novos
    // lançamentos caso a gravação anterior tenha sido confirmada no servidor.
    final pending = _pendingSave;
    if (pending != null) {
      await _persist(state, pending);
      return;
    }
    final phone = digitsOnly(_whatsapp.text);
    if (_nome.text.trim().isEmpty || _principal <= 0 || _vencimento == null) {
      showPagoSnack(context, 'Preencha nome, valor e vencimento.');
      return;
    }
    if (phone.isNotEmpty && !isValidPhoneBr(phone)) {
      showPagoSnack(context, 'Informe um WhatsApp válido.');
      return;
    }

    final existing = widget.debt;
    final blocked = firstBlockingHit(
      debts: state.debts,
      nome: _nome.text,
      telefone: _whatsapp.text,
      ignoreId: existing?.id,
      allowPhone: widget.debt?.telefone ?? widget.prefillTelefone,
      allowNome: widget.debt?.nome ?? widget.prefillNome,
    );
    if (blocked != null) {
      showPagoSnack(
        context,
        blocked.phoneTaken
            ? phoneTakenMessage
            : '${blocked.debt.nome} já está na caderneta. Abra o contato.',
      );
      return;
    }
    if (!_principal.isFinite || _principal > 100000000 || _taxa > 1000) {
      showPagoSnack(context, 'Confira o valor e a taxa informados.');
      return;
    }
    if (_parcelado && !state.user.premiumAtivo) {
      showPagoSnack(context, 'O parcelamento precisa de Premium ativo.');
      return;
    }
    if (_parcelado && (_preview.isEmpty || _taxa != 0)) {
      showPagoSnack(
        context,
        'Informe o total combinado, sem juros adicionais. Cada parcela precisa ter ao menos R\$ 0,01.',
      );
      return;
    }

    final List<Debt> next;
    if (existing != null) {
      final locked = _financialLocked(state);
      next = [
        existing.copyWith(
          nome: _nome.text.trim(),
          telefone: phone,
          valorPrincipal: locked ? existing.valorPrincipal : _principal,
          taxaJuros: locked ? existing.taxaJuros : _taxa,
          dataVencimento: locked ? existing.dataVencimento : _vencimento!,
        ),
      ];
    } else {
      final count = _parcelado ? _parcelas : 1;
      while (_newIds.length < count) {
        _newIds.add(state.newId());
      }
      final now = DateTime.now();
      _grupoId ??= state.newId();
      final preview = _preview;
      next = [
        for (var i = 0; i < count; i++)
          Debt(
            id: _newIds[i],
            userId: state.user.id,
            nome: _nome.text.trim(),
            telefone: phone,
            valorPrincipal: _parcelado ? preview[i].valor : _principal,
            taxaJuros: _parcelado ? 0 : _taxa,
            dataVencimento: _parcelado ? preview[i].vencimento : _vencimento!,
            statusPago: false,
            clientScore: 80,
            createdAt: now,
            grupoId: _parcelado ? _grupoId! : '',
            parcela: i + 1,
            totalParcelas: count,
          ),
      ];
    }
    _pendingSave = List.unmodifiable(next);
    await _persist(state, next);
  }

  Future<void> _persist(AppController state, List<Debt> next) async {
    setState(() => _saving = true);
    try {
      var firstEver = false;
      if (widget.debt != null) {
        await state.upsertDebt(next.single);
      } else {
        firstEver = state.debts.isEmpty;
        await state.createDebts(next);
      }
      if (!mounted) return;
      if (firstEver && state.canOfferDailyReminders) {
        await _offerDailyReminders(state);
        if (!mounted) return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showPagoSnack(
        context,
        'Não foi possível confirmar o salvamento. Seus dados foram mantidos; tente salvar novamente.',
      );
    }
  }

  /// Depois do primeiro lançamento: o momento em que o aviso faz sentido.
  Future<void> _offerDailyReminders(AppController state) async {
    final accept = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receber o resumo das 9h?'),
        content: const Text(
          'Todo dia às 9h o Pagô avisa quantas cobranças vencem hoje e amanhã e quantas estão atrasadas. Você pode desligar quando quiser em Configurações.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ligar avisos'),
          ),
        ],
      ),
    );
    if (accept != true) return;
    final enabled = await state.enableDailyReminders();
    if (mounted && !enabled) {
      showPagoSnack(
        context,
        'Permissão de notificação não concedida. Ative nas configurações do aparelho.',
      );
    }
  }

  ClientHit? _blockedHit(AppController state) {
    return firstBlockingHit(
      debts: state.debts,
      nome: _nome.text,
      telefone: _whatsapp.text,
      ignoreId: widget.debt?.id,
      allowPhone: widget.debt?.telefone ?? widget.prefillTelefone,
      allowNome: widget.debt?.nome ?? widget.prefillNome,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final blocked = _blockedHit(state);
    final financialLocked = _financialLocked(state);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          widget.debt == null ? 'Novo lançamento' : 'Editar lançamento',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: AbsorbPointer(
              absorbing: _saving || _pendingSave != null,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (financialLocked)
                    _FormNotice(
                      text: 'Este lançamento já tem pagamentos ou está quitado. Valor, juros e vencimento foram preservados para manter o histórico.',
                      icon: Icons.lock_outline_rounded,
                    )
                  else
                    _VoiceBanner(
                      listening: _listening,
                      heard: _heard,
                      isPremium: state.user.premiumAtivo,
                      onTap: _listenVoice,
                    ),
                  if (_pendingSave != null) ...[
                    const SizedBox(height: 12),
                    const _FormNotice(
                      text: 'Há um salvamento sem confirmação. Tente novamente para reenviar os mesmos dados, sem criar outra venda.',
                      icon: Icons.sync_problem_rounded,
                    ),
                  ],
                  const SizedBox(height: 22),
                  AppTextField(
                    label: 'Nome do Cliente',
                    hint: 'Ex: João Silva',
                    icon: Icons.person_outline_rounded,
                    controller: _nome,
                    textCapitalization: TextCapitalization.words,
                    keyboardType: TextInputType.name,
                    autofillHints: const [AutofillHints.name],
                    inputFormatters: [NameMaskFormatter()],
                    textInputAction: TextInputAction.next,
                    maxLength: 80,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'WhatsApp',
                    hint: '(00) 00000-0000',
                    icon: Icons.phone_outlined,
                    controller: _whatsapp,
                    keyboardType: TextInputType.phone,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [PhoneMaskFormatter()],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                  _ExistingClientHint(
                    nome: _nome.text,
                    telefone: _whatsapp.text,
                    ignoreId: widget.debt?.id,
                    allowPhone: widget.debt?.telefone ?? widget.prefillTelefone,
                    allowNome: widget.debt?.nome ?? widget.prefillNome,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: _parcelado ? 'Total da venda' : 'Valor',
                          hint: r'R$ 0,00',
                          icon: Icons.attach_money_rounded,
                          controller: _valor,
                          readOnly: true,
                          onTap: () async {
                            if (financialLocked) return;
                            final value = await showAmountKeypad(
                              context: context,
                              title: _parcelado
                                  ? 'Valor total da venda'
                                  : 'Valor do lançamento',
                              confirmLabel: 'Usar valor',
                            );
                            if (value == null || !mounted) return;
                            setState(() {
                              _valor.text = Money.full(value);
                            });
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          label: 'Juros (%)',
                          hint: '0,00',
                          icon: Icons.percent_rounded,
                          controller: _juros,
                          readOnly: financialLocked || _parcelado,
                          keyboardType: TextInputType.number,
                          autocorrect: false,
                          enableSuggestions: false,
                          inputFormatters: [PercentMaskFormatter()],
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _parcelado
                        ? 'Informe o valor total combinado. O parcelamento não acrescenta juros.'
                        : 'Juros opcionais, aplicados uma vez sobre o valor informado.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedDark,
                    ),
                  ),
                  if (widget.debt == null) ...[
                    const SizedBox(height: 16),
                    _installmentOptions(state),
                  ],
                  const SizedBox(height: 16),
                  AppTextField(
                    label: _parcelado
                        ? 'Primeiro vencimento'
                        : 'Data de Vencimento',
                    hint: 'Selecionar data',
                    icon: Icons.event_outlined,
                    readOnly: true,
                    onTap: _pickDate,
                    controller: _date,
                    suffix: IconButton(
                      tooltip: 'Selecionar data de vencimento',
                      onPressed: financialLocked ? null : _pickDate,
                      icon: const Icon(
                        Icons.calendar_month_outlined,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  if (_parcelado && _preview.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _installmentPreview(),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEEF2F7)),
                    ),
                    child: Column(
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 16,
                          runSpacing: 6,
                          children: [
                            Text(
                              _taxa > 0 ? 'Total com juros' : 'Total a receber',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedDark,
                              ),
                            ),
                            Text(
                              Money.full(_total),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text(
                              'Prazo Inicial',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.mutedDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Hoje',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PrimaryButton(
            label: _saving
                ? 'Salvando…'
                : _pendingSave != null
                ? 'Tentar salvar novamente'
                : blocked != null
                ? 'Já existe na caderneta'
                : _parcelado
                ? 'Salvar $_parcelas parcelas'
                : 'Salvar na caderneta',
            onPressed: !_saving && (blocked == null || _pendingSave != null)
                ? _save
                : null,
          ),
        ),
      ),
    );
  }

  Widget _installmentOptions(AppController state) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(
              'Parcelar a receber',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              state.user.premiumAtivo
                  ? 'Escolha o 1º vencimento e em quantas vezes dividir'
                  : 'Premium · lançamento único continua grátis',
            ),
            value: _parcelado,
            onChanged: _setParcelado,
          ),
          if (_parcelado)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: DropdownButtonFormField<int>(
                initialValue: _parcelas,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Parcelas'),
                items: [
                  for (var i = 2; i <= 12; i++)
                    DropdownMenuItem(value: i, child: Text('$i vezes')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _parcelas = value);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _installmentPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confira antes de salvar',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Parcelado em ${_parcelas}x · vence todo dia ${_vencimento!.day} do mês',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedDark,
            ),
          ),
          const SizedBox(height: 8),
          for (final installment in _preview)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Wrap(
                spacing: 12,
                runSpacing: 2,
                children: [
                  Text(
                    '${installment.parcela} de ${installment.totalParcelas} · ${Dates.full(installment.vencimento)}',
                  ),
                  Text(
                    Money.full(installment.valor),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FormNotice extends StatelessWidget {
  const _FormNotice({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _VoiceBanner extends StatelessWidget {
  const _VoiceBanner({
    required this.listening,
    required this.heard,
    required this.isPremium,
    required this.onTap,
  });

  final bool listening;
  final String heard;
  final bool isPremium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = listening
        ? (heard.isEmpty ? 'Dite nome, valor e vencimento' : heard)
        : isPremium
        ? 'Toque e fale. O app preenche o lançamento.'
        : 'Premium: dite nome, valor e vencimento';

    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: listening ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listening
                          ? 'Ouvindo...'
                          : isPremium
                          ? 'Cadastro por voz'
                          : 'Cadastro por voz · Premium',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.primaryDark,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nunca cita o nome do dono do número nem leva ao perfil dele.
const phoneTakenMessage =
    'Este número de WhatsApp já está sendo usado por outra pessoa. Use outro número.';

class _ExistingClientHint extends StatelessWidget {
  const _ExistingClientHint({
    required this.nome,
    required this.telefone,
    this.ignoreId,
    this.allowPhone,
    this.allowNome,
  });

  final String nome;
  final String telefone;
  final String? ignoreId;
  final String? allowPhone;
  final String? allowNome;

  @override
  Widget build(BuildContext context) {
    final debts = context.watch<AppController>().debts;
    final blocked = firstBlockingHit(
      debts: debts,
      nome: nome,
      telefone: telefone,
      ignoreId: ignoreId,
      allowPhone: allowPhone,
      allowNome: allowNome,
    );
    final nameWarn = blocked == null
        ? findClientHits(
            debts: debts,
            nome: nome,
            telefone: telefone,
            ignoreId: ignoreId,
          ).where((hit) => hit.nameTaken).firstOrNull
        : null;
    final hit = blocked ?? nameWarn;
    if (hit == null) return const SizedBox.shrink();

    final blocking = blocked != null;
    // Número de outra pessoa: só avisa. Sem nome e sem abrir o perfil.
    final canOpen = !hit.phoneTaken;
    final text = hit.phoneTaken
        ? phoneTakenMessage
        : hit.confirmed
        ? '${hit.debt.nome} já está na caderneta. Abra o contato para um novo lançamento.'
        : 'Já existe ${hit.debt.nome}. Confira se o telefone é outro.';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: blocking ? AppColors.dangerSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: !canOpen
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ContactHistoryPage(
                        contactKey: contactKeyOf(hit.debt),
                      ),
                    ),
                  );
                },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Icon(
                  blocking ? Icons.block_rounded : Icons.person_search_rounded,
                  color: blocking ? AppColors.danger : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    canOpen ? '$text Toque para abrir.' : text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: blocking
                          ? AppColors.danger
                          : AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
