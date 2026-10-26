import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/customer_statement.dart';
import '../services/export_share.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

class AccountExportPage extends StatefulWidget {
  const AccountExportPage({super.key});

  @override
  State<AccountExportPage> createState() => _AccountExportPageState();
}

class _AccountExportPageState extends State<AccountExportPage> {
  bool _busy = false;

  Future<void> _export({required bool json}) async {
    if (_busy) return;
    final state = context.read<AppController>();
    final now = DateTime.now();
    final data = json
        ? const JsonEncoder.withIndent('  ').convert({
            'format': 'pago-account-export',
            'version': 1,
            'generated_at': now.toIso8601String(),
            'scope': 'Registros carregados nesta sessão. Não contém senha, tokens de acesso ou imagens de comprovantes.',
            'user': state.user.toMap(),
            'debts': state.debts.map((entry) => entry.toMap()).toList(),
            'payments': state.payments.map((entry) => entry.toMap()).toList(),
            'bills': state.bills.map((entry) => entry.toMap()).toList(),
          })
        : accountCsv(
            debts: state.debts,
            payments: state.payments,
            bills: state.bills,
          );
    setState(() => _busy = true);
    try {
      await shareExport(
        context,
        bytes: Uint8List.fromList(utf8.encode(data)),
        filename:
            'pago-meus-dados-${now.toIso8601String().substring(0, 10)}.${json ? 'json' : 'csv'}',
        mimeType: json ? 'application/json' : 'text/csv',
        subject: 'Meus registros do Pagô',
      );
    } catch (_) {
      if (mounted) {
        showPagoSnack(
          context,
          'Não foi possível exportar. Seus registros continuam no app. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Exportar meus dados')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.file_download_outlined,
            size: 44,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Sua caderneta com você',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            'Prepare uma cópia dos registros carregados nesta sessão. Confira a sincronização e atualize os dados antes de exportar.',
          ),
          const SizedBox(height: 12),
          Text(
            '${state.debts.length} lançamentos · ${state.payments.length} pagamentos · ${state.bills.length} boletos',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'O arquivo contém nomes, contatos e informações financeiras. O JSON também inclui os dados do seu perfil. Escolha um destino seguro e confira com quem está compartilhando. Não inclui senha nem tokens de acesso.',
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _busy || state.loading
                ? null
                : () async {
                    await state.load();
                    if (!context.mounted) return;
                    if (state.errorMessage != null) {
                      showPagoSnack(context, state.errorMessage!);
                    }
                  },
            icon: state.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: const Text('Atualizar registros'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy || state.loading
                ? null
                : () => _export(json: false),
            icon: const Icon(Icons.table_view_outlined),
            label: Text(_busy ? 'Preparando…' : 'Exportar planilha CSV'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy || state.loading
                ? null
                : () => _export(json: true),
            icon: const Icon(Icons.data_object_outlined),
            label: const Text('Exportar dados completos em JSON'),
          ),
          const SizedBox(height: 16),
          const Text(
            'CSV é uma planilha de vendas, pagamentos e boletos. JSON guarda os campos dos registros e do perfil. A exportação não verifica movimentações bancárias nem substitui o backup do serviço. A importação automática desses arquivos ainda não faz parte deste fluxo.',
            style: TextStyle(fontSize: 12, color: AppColors.mutedDark),
          ),
        ],
      ),
    );
  }
}
