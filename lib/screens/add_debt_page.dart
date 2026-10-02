import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

class AddDebtPage extends StatefulWidget {
  const AddDebtPage({super.key, this.debt});

  final Debt? debt;

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

  @override
  void initState() {
    super.initState();
    final debt = widget.debt;
    if (debt != null) {
      _nome.text = debt.nome;
      _whatsapp.text = debt.telefone;
      _valor.text = debt.valorPrincipal.toStringAsFixed(2).replaceAll('.', ',');
      _juros.text = debt.taxaJuros.toStringAsFixed(2).replaceAll('.', ',');
      _vencimento = debt.dataVencimento;
      _date.text = Dates.full(debt.dataVencimento);
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _whatsapp.dispose();
    _valor.dispose();
    _juros.dispose();
    _date.dispose();
    super.dispose();
  }

  double get _principal => _parse(_valor.text);

  double get _taxa => _parse(_juros.text);

  double get _total => _principal * (1 + _taxa / 100);

  double _parse(String raw) {
    final normalized = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

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
    setState(() => _listening = true);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() {
      _nome.text = 'João Silva';
      _whatsapp.text = '(11) 98888-1234';
      _valor.text = '750,00';
      _juros.text = '5,00';
      _vencimento = DateTime.now().add(const Duration(days: 30));
      _date.text = Dates.full(_vencimento!);
      _listening = false;
    });
    showTapagoSnack(context, 'Dados capturados por voz com IA.');
  }

  Future<void> _save() async {
    if (_nome.text.trim().isEmpty || _principal <= 0 || _vencimento == null) {
      showTapagoSnack(context, 'Preencha nome, valor e vencimento.');
      return;
    }

    final state = context.read<AppController>();
    final existing = widget.debt;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.debt == null ? 'Novo Débito' : 'Editar Débito'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _VoiceBanner(listening: _listening, onTap: _listenVoice),
                const SizedBox(height: 22),
                AppTextField(
                  label: 'Nome do Cliente',
                  hint: 'Ex: João Silva',
                  icon: Icons.person_outline_rounded,
                  controller: _nome,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'WhatsApp',
                  hint: '(00) 00000-0000',
                  icon: Icons.phone_outlined,
                  controller: _whatsapp,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Valor Principal',
                        hint: r'R$ 0,00',
                        icon: Icons.attach_money_rounded,
                        controller: _valor,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: 'Juros (%)',
                        hint: '% 0,00',
                        icon: Icons.percent_rounded,
                        controller: _juros,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
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
                            'Total com Juros',
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
              child: PrimaryButton(label: 'Salvar Débito', onPressed: _save),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceBanner extends StatelessWidget {
  const _VoiceBanner({required this.listening, required this.onTap});

  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                      listening ? 'Ouvindo...' : 'Cadastro por Voz (AI)',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      listening
                          ? 'Dite nome, valor e vencimento'
                          : 'Toque para ditando os dados do cliente',
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
