import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/asaas_client.dart';
import '../services/pix_status.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/input_masks.dart';
import '../utils/masks.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

class PixCheckoutPage extends StatefulWidget {
  const PixCheckoutPage({super.key, this.client});

  final AsaasClient? client;

  @override
  State<PixCheckoutPage> createState() => _PixCheckoutPageState();
}

class _PixCheckoutPageState extends State<PixCheckoutPage> {
  late final AsaasClient _client = widget.client ?? AsaasClient();
  final _cpf = TextEditingController();
  Timer? _poll;
  PixCharge? _charge;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _poll?.cancel();
    _cpf.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final cpf = digitsOnly(_cpf.text);
    if (!isValidCpfOrCnpj(cpf)) {
      setState(() => _error = 'Informe um CPF ou CNPJ válido.');
      return;
    }
    final state = context.read<AppController>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final charge = await _client.createPix(
        userId: state.user.id,
        name: state.user.nome,
        email: state.user.email,
        cpf: cpf,
      );
      if (!mounted) return;
      setState(() {
        _charge = charge;
        _busy = false;
      });
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
    } on AsaasException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Não foi possível gerar o PIX.';
      });
    }
  }

  Future<void> _refresh() async {
    final charge = _charge;
    if (charge == null || !mounted) return;
    try {
      final status = await _client.status(
        paymentId: charge.paymentId,
        userId: context.read<AppController>().user.id,
      );
      if (!mounted) return;
      if (!pixStatusGrantsPremium(status)) return;
      _poll?.cancel();
      await context.read<AppController>().grantConfirmedPix(charge.paymentId);
      if (!mounted) return;
      showTapagoSnack(context, 'PIX confirmado. Premium ativado.');
      Navigator.of(context).pop(true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final charge = _charge;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('PIX'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Pagô! Premium',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${AppConstants.premiumPriceLabel} pelo Asaas. O Premium entra quando o PIX compensar.',
            style: GoogleFonts.plusJakartaSans(color: AppColors.mutedDark),
          ),
          const SizedBox(height: 22),
          if (charge == null) ...[
            AppTextField(
              label: 'CPF ou CNPJ',
              hint: '000.000.000-00',
              icon: Icons.badge_outlined,
              controller: _cpf,
              keyboardType: TextInputType.number,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [CpfCnpjMaskFormatter()],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: _busy ? 'Gerando PIX...' : 'Gerar PIX',
              onPressed: _busy ? null : _create,
            ),
          ] else ...[
            if (charge.encodedImage.isNotEmpty)
              Center(
                child: Image.memory(
                  base64Decode(charge.encodedImage),
                  width: 220,
                  height: 220,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Aguardando o pagamento',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              charge.payload,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.mutedDark,
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Copiar código PIX',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: charge.payload));
                if (!context.mounted) return;
                showTapagoSnack(context, 'Código PIX copiado.');
              },
            ),
          ],
        ],
      ),
    );
  }
}
