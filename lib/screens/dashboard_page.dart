import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/tapago_logo.dart';
import '../widgets/whatsapp_mark.dart';
import 'add_debt_page.dart';
import 'caderneta_page.dart';
import 'client_profile_page.dart';
import 'premium_page.dart';
import 'settings_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final pending = state.pendingDebts;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _NewDebtFab(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddDebtPage()),
          );
        },
      ),
      body: SafeArea(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Header(user: state.user),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  icon: Icons.trending_up_rounded,
                                  label: 'Saldo aberto',
                                  value: Money.compact(state.saldoAberto),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricCard(
                                  icon: Icons.calendar_month_rounded,
                                  label: 'A Receber',
                                  value: Money.compact(state.aReceberNaSemana),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _MetricCard(
                            icon: Icons.payments_outlined,
                            label: 'Na rua',
                            value: Money.compact(state.dinheiroNaRua),
                            compact: true,
                          ),
                          if (!state.user.isPremium) ...[
                            const SizedBox(height: 16),
                            const _PremiumBanner(),
                          ],
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Text(
                                'Na caderneta',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => _openAll(context),
                                child: Text(
                                  'Ver todos',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (pending.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Nada na caderneta. Toque em Novo lançamento para começar.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.mutedDark,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 108),
                      sliver: SliverList.separated(
                        itemCount: pending.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final debt = pending[index];
                          return DebtTile(
                            debt: debt,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ClientProfilePage(debt: debt),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  void _openAll(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CadernetaPage()),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olá, ${user.nome.split(' ').first}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedDark,
                ),
              ),
              const SizedBox(height: 4),
              const TapagoWordmark(markSize: 28, fontSize: 24),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
          icon: const Icon(Icons.settings_outlined),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
          child: CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary,
            child: Text(
              initialsOf(user.nome),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, compact ? 14 : 18, 18, compact ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: compact ? 20 : 22),
          SizedBox(height: compact ? 8 : 18),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: compact ? 22 : 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: AppColors.text),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assine o Premium',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Voz e leitura de recibos na caderneta',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: AppColors.mutedDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PremiumPage()),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
            child: const Text('Ver Planos'),
          ),
        ],
      ),
    );
  }
}

class _NewDebtFab extends StatelessWidget {
  const _NewDebtFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.38),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 22),
            const SizedBox(width: 6),
            Text(
              'Novo lançamento',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DebtTile extends StatelessWidget {
  const DebtTile({super.key, required this.debt, required this.onTap});

  final Debt debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final saldo = context.watch<AppController>().saldoOf(debt);
    final overdue = debt.isOverdue;
    final accent = overdue ? AppColors.danger : AppColors.primary;
    final bg = overdue ? AppColors.dangerSoft : Colors.white;
    final border = overdue ? AppColors.dangerBorder : const Color(0xFFF0F3F8);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: overdue
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Icon(Icons.error_rounded, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.nome,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vence em ${Dates.due(debt.dataVencimento)}   Score: ${debt.scoreStars}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppColors.mutedDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                Money.full(saldo),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: overdue ? AppColors.danger : AppColors.text,
                ),
              ),
              const SizedBox(width: 10),
              const WhatsAppMark(size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
