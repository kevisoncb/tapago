import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FirstUsePage extends StatefulWidget {
  const FirstUsePage({super.key});

  @override
  State<FirstUsePage> createState() => _FirstUsePageState();
}

class _FirstUsePageState extends State<FirstUsePage> {
  final _controller = PageController();
  var _index = 0;

  static const _steps = [
    _GuideStep(
      icon: Icons.today_rounded,
      title: 'Seu dinheiro a receber, no controle',
      body: 'Veja o que vence hoje, o que está atrasado e o que entra nos próximos dias.',
    ),
    _GuideStep(
      icon: Icons.receipt_long_rounded,
      title: 'Uma caderneta que mostra o histórico',
      body: 'Registre vendas e pagamentos. Se algo estiver errado, faça um estorno sem apagar o que aconteceu.',
    ),
    _GuideStep(
      icon: Icons.touch_app_rounded,
      title: 'Você decide quais atalhos usar',
      body: 'Voz, câmera, biometria e notificações são opcionais. O Pagô só pede cada permissão quando você usar a função.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _steps.length - 1) {
      Navigator.pop(context, true);
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Agora não'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) => _GuideStepView(
                  step: _steps[index],
                  position: index + 1,
                  total: _steps.length,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < _steps.length; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _index ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == _index
                          ? AppColors.primary
                          : AppColors.primaryMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _next,
                child: Text(
                  _index == _steps.length - 1
                      ? 'Criar primeiro lançamento'
                      : 'Próximo',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GuideStep {
  const _GuideStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _GuideStepView extends StatelessWidget {
  const _GuideStepView({
    required this.step,
    required this.position,
    required this.total,
  });

  final _GuideStep step;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Etapa $position de $total',
    child: Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(step.icon, size: 54, color: AppColors.primary),
            ),
            const SizedBox(height: 32),
            Text(
              step.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
            ),
            const SizedBox(height: 14),
            Text(
              step.body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.mutedDark, height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
}
