import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/client_match.dart';
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

  Future<void> _pickDate() async {
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
    if (!state.user.isPremium) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PremiumPage()),
      );
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
      if (draft.juros != null) {
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
    showPagoSnack(
      context,
      'Preenchi ${filled.join(', ')}. Confira e salve.',
    );
  }

  Future<void> _save() async {
    final phone = digitsOnly(_whatsapp.text);
    if (_nome.text.trim().isEmpty || _principal <= 0 || _vencimento == null) {
      showPagoSnack(context, 'Preencha nome, valor e vencimento.');
      return;
    }
    if (phone.isNotEmpty && !isValidPhoneBr(phone)) {
      showPagoSnack(context, 'Informe um WhatsApp válido.');
      return;
    }

    final state = context.read<AppController>();
    final existing = widget.debt;
    final blocked = firstBlockingHit(
      debts: state.debts,
      nome: _nome.text,
      telefone: _whatsapp.text,
      ignoreId: existing?.id,
      allowPhone: widget.prefillTelefone,
      allowNome: widget.prefillNome,
    );
    if (blocked != null) {
      showPagoSnack(
        context,
        blocked.phoneTaken
            ? 'Este WhatsApp já é de ${blocked.debt.nome}. Abra a caderneta dele.'
            : '${blocked.debt.nome} já está na caderneta. Abra o contato.',
      );
      return;
    }

    final debt = Debt(
      id: existing?.id ?? state.newId(),
      userId: state.user.id,
      nome: _nome.text.trim(),
      telefone: digitsOnly(_whatsapp.text),
      valorPrincipal: _principal,
      taxaJuros: _taxa,
      dataVencimento: _vencimento!,
      statusPago: existing?.statusPago ?? false,
      clientScore: existing?.clientScore ?? 80,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    await state.upsertDebt(debt);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  ClientHit? _blockedHit(AppController state) {
    return firstBlockingHit(
      debts: state.debts,
      nome: _nome.text,
      telefone: _whatsapp.text,
      ignoreId: widget.debt?.id,
      allowPhone: widget.prefillTelefone,
      allowNome: widget.prefillNome,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final blocked = _blockedHit(state);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.debt == null ? 'Novo lançamento' : 'Editar lançamento'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _VoiceBanner(
                  listening: _listening,
                  heard: _heard,
                  isPremium: context.watch<AppController>().user.isPremium,
                  onTap: _listenVoice,
                ),
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
                  onChanged: (_) => setState(() {}),
                ),
                _ExistingClientHint(
                  nome: _nome.text,
                  telefone: _whatsapp.text,
                  ignoreId: widget.debt?.id,
                  allowPhone: widget.prefillTelefone,
                  allowNome: widget.prefillNome,
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
                            title: 'Valor do lançamento',
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
                        keyboardType: TextInputType.number,
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: [PercentMaskFormatter()],
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Juros só se você quiser. Fiado e venda a prazo ficam em branco.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedDark,
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Data de Vencimento',
                  hint: 'Selecionar data',
                  icon: Icons.event_outlined,
                  readOnly: true,
                  onTap: _pickDate,
                  controller: _date,
                  suffix: IconButton(
                    onPressed: _pickDate,
                    icon: const Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.muted,
                    ),
                  ),
                ),
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
                      Row(
                        children: [
                          Text(
                            _taxa > 0 ? 'Total com juros' : 'Total a receber',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedDark,
                            ),
                          ),
                          const Spacer(),
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                label: blocked == null
                    ? 'Salvar na caderneta'
                    : 'Já existe na caderneta',
                onPressed: blocked == null ? _save : null,
              ),
            ),
          ),
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
        ? (heard.isEmpty
            ? 'Dite nome, valor e vencimento'
            : heard)
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
    final text = hit.phoneTaken
        ? 'Este WhatsApp já é de ${hit.debt.nome}. Não dá para cadastrar outra pessoa com o mesmo número.'
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
          onTap: () {
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
                  blocking
                      ? Icons.block_rounded
                      : Icons.person_search_rounded,
                  color: blocking ? AppColors.danger : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$text Toque para abrir.',
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
