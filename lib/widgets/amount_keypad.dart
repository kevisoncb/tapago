import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../services/debt_balance.dart';

Future<AbateKind?> showAbateKindSheet({
  required BuildContext context,
  required double jurosEmAberto,
  required double saldo,
}) {
  final temJuros = jurosEmAberto > 0.009;
  return showModalBottomSheet<AbateKind>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'O que o cliente pagou?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Só você vê isso. O cliente não recebe essa pergunta.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.mutedDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              _AbateKindTile(
                title: 'Valor total',
                subtitle: 'Quita a caderneta. ${Money.full(saldo)}',
                onTap: () => Navigator.pop(sheetContext, AbateKind.total),
              ),
              const SizedBox(height: 8),
              _AbateKindTile(
                title: 'Parte do valor',
                subtitle: 'Entrou um pedaço do combinado.',
                onTap: () => Navigator.pop(sheetContext, AbateKind.parcial),
              ),
              if (temJuros) ...[
                const SizedBox(height: 8),
                _AbateKindTile(
                  title: 'Somente o juros do mês',
                  subtitle: 'Não baixa o principal. ${Money.full(jurosEmAberto)}',
                  onTap: () => Navigator.pop(sheetContext, AbateKind.juros),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _AbateKindTile extends StatelessWidget {
  const _AbateKindTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEEF2F7)),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

Future<double?> showAmountKeypad({
  required BuildContext context,
  required String title,
  String confirmLabel = 'Confirmar',
  double? max,
  String? maxLabel,
  double? initial,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AmountKeypadSheet(
      title: title,
      confirmLabel: confirmLabel,
      max: max,
      maxLabel: maxLabel,
      initial: initial,
    ),
  );
}

class _AmountKeypadSheet extends StatefulWidget {
  const _AmountKeypadSheet({
    required this.title,
    required this.confirmLabel,
    this.max,
    this.maxLabel,
    this.initial,
  });

  final String title;
  final String confirmLabel;
  final double? max;
  final String? maxLabel;
  final double? initial;

  @override
  State<_AmountKeypadSheet> createState() => _AmountKeypadSheetState();
}

class _AmountKeypadSheetState extends State<_AmountKeypadSheet> {
  late int _cents;

  @override
  void initState() {
    super.initState();
    final start = widget.initial ?? 0;
    _cents = start <= 0 ? 0 : (start * 100).round();
  }

  double get _value {
    final amount = _cents / 100;
    final max = widget.max;
    if (max != null && amount > max) return max;
    return amount;
  }

  void _push(int digit) {
    if (_cents >= 99999999) return;
    setState(() => _cents = _cents * 10 + digit);
  }

  void _back() {
    setState(() => _cents = _cents ~/ 10);
  }

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE6EAF0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (widget.max != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.maxLabel ?? 'Saldo ${Money.full(widget.max!)}',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.mutedDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              Money.full(_value),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              children: [
                for (final key in keys)
                  if (key.isEmpty)
                    const SizedBox.shrink()
                  else
                    InkWell(
                      onTap: () {
                        if (key == '⌫') {
                          _back();
                        } else {
                          _push(int.parse(key));
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: Text(
                          key,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: key == '⌫' ? 22 : 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _value <= 0
                    ? null
                    : () => Navigator.pop(context, _value),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: const Color(0xFFE8EEF6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  widget.confirmLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
