import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/biometric_service.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';

class BiometricLock extends StatefulWidget {
  const BiometricLock({super.key, required this.child});

  final Widget child;

  @override
  State<BiometricLock> createState() => _BiometricLockState();
}

class _BiometricLockState extends State<BiometricLock>
    with WidgetsBindingObserver {
  final _biometrics = BiometricService();
  var _unlocked = false;
  var _asking = false;
  var _prompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAsk());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _enabled => context.read<AppController>().user.acessoBiometrico;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled) return;
    if (state == AppLifecycleState.paused) {
      setState(() {
        _unlocked = false;
        _prompted = false;
      });
    } else if (state == AppLifecycleState.resumed && !_unlocked) {
      _maybeAsk();
    }
  }

  void _maybeAsk() {
    if (!mounted || _prompted || _unlocked || !_enabled) return;
    _prompted = true;
    _ask();
  }

  Future<void> _ask() async {
    if (_asking || !mounted) return;
    _asking = true;
    final ok = !await _biometrics.canLock || await _biometrics.authenticate();
    _asking = false;
    if (!mounted) return;
    setState(() => _unlocked = ok);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = context.watch<AppController>().user.acessoBiometrico;
    if (enabled && !_unlocked && !_prompted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAsk());
    }
    final locked = enabled && !_unlocked;
    return Stack(
      children: [
        widget.child,
        if (locked)
          Positioned.fill(child: _LockScreen(onUnlock: _ask)),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint_rounded, size: 72, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Pagô bloqueado',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Confirme sua digital ou reconhecimento facial para continuar.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.mutedDark),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onUnlock,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                  child: const Text('Desbloquear'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
