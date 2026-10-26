import 'package:flutter/material.dart';

/// Abertura de marca: o quadrado entra, o ✓ é desenhado, o ponto aparece e o
/// nome fecha a sequência. Cobre o app por cerca de 2 segundos na abertura a
/// frio e depois se dissolve, chamando [onDone]. Não toca em dados nem pede
/// permissões. Com "reduzir movimento" mostra o quadro final e só faz o fade.
class BrandSplash extends StatefulWidget {
  const BrandSplash({super.key, required this.onDone, this.reduceMotion});

  final VoidCallback onDone;

  /// Sobrescreve a preferência do sistema; usado nos testes.
  final bool? reduceMotion;

  static const total = Duration(milliseconds: 1900);
  static const fade = Duration(milliseconds: 450);
  static const reducedHold = Duration(milliseconds: 700);
  static const reducedFade = Duration(milliseconds: 200);

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF2F6BFF);

  AnimationController? _controller;
  bool _reduced = false;
  bool _fading = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced =
        widget.reduceMotion ??
        MediaQueryData.fromView(View.of(context)).disableAnimations;
    _run();
  }

  Future<void> _run() async {
    if (_reduced) {
      await Future<void>.delayed(BrandSplash.reducedHold);
    } else {
      final controller = AnimationController(
        vsync: this,
        duration: BrandSplash.total,
      );
      _controller = controller;
      await controller.forward();
    }
    if (!mounted) return;
    setState(() => _fading = true);
    await Future<void>.delayed(
      _reduced ? BrandSplash.reducedFade : BrandSplash.fade,
    );
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final scene = controller == null
        ? const _Scene(t: 1)
        : AnimatedBuilder(
            animation: controller,
            builder: (context, _) => _Scene(t: controller.value),
          );
    return Semantics(
      label: 'Pagô',
      container: true,
      child: IgnorePointer(
        ignoring: _fading,
        child: AnimatedOpacity(
          opacity: _fading ? 0 : 1,
          duration: _reduced ? BrandSplash.reducedFade : BrandSplash.fade,
          curve: Curves.easeOut,
          child: ColoredBox(
            color: _blue,
            child: Center(child: ExcludeSemantics(child: scene)),
          ),
        ),
      ),
    );
  }
}

double _span(double t, double startMs, double endMs, [Curve? curve]) {
  const totalMs = 1900.0;
  final v = ((t * totalMs - startMs) / (endMs - startMs)).clamp(0.0, 1.0);
  return (curve ?? Curves.linear).transform(v);
}

class _Scene extends StatelessWidget {
  const _Scene({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final tile = _span(t, 100, 600, Curves.easeOutBack);
    final tick = _span(t, 550, 1100, Curves.easeInOutCubic);
    final dot = _span(t, 1000, 1350, Curves.easeOutBack);
    final word = _span(t, 1050, 1500, Curves.easeOut);
    final tag = _span(t, 1300, 1750, Curves.easeOut);
    final halo = _span(t, 50, 1150, Curves.easeOut);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Opacity(
          opacity: halo,
          child: Transform.scale(
            scale: 0.3 + 0.7 * halo,
            child: Container(
              width: 520,
              height: 520,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)],
                  stops: [0, 0.62],
                ),
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: tile.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.6 + 0.4 * tile,
                child: SizedBox(
                  width: 132,
                  height: 132,
                  child: CustomPaint(
                    painter: _MarkPainter(tick: tick, dot: dot),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Opacity(
              opacity: word,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - word)),
                child: const Text(
                  'Pagô',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w800,
                    fontSize: 34,
                    letterSpacing: -0.7,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Opacity(
              opacity: tag,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - tag)),
                child: const Text(
                  'E aí, pagô?',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFFB6F23A),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.tick, required this.dot});

  final double tick;
  final double dot;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 512;
    canvas.save();
    canvas.scale(k);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 512, 512),
        const Radius.circular(114),
      ),
      Paint()..color = Colors.white,
    );

    if (tick > 0) {
      final path = Path()
        ..moveTo(132, 268)
        ..lineTo(228, 364)
        ..lineTo(348, 176);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * tick),
        Paint()
          ..color = const Color(0xFF2F6BFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 58
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (dot > 0) {
      canvas.drawCircle(
        const Offset(402, 110),
        32 * dot.clamp(0.0, 1.2),
        Paint()..color = const Color(0xFF2F6BFF),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.tick != tick || old.dot != dot;
}
