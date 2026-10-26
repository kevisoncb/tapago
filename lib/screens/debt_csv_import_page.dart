import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/debt_csv_import.dart';
import '../services/export_share.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class DebtCsvImportPage extends StatefulWidget {
  const DebtCsvImportPage({super.key});

  @override
  State<DebtCsvImportPage> createState() => _DebtCsvImportPageState();
}

class _DebtCsvImportPageState extends State<DebtCsvImportPage> {
  DebtCsvPreview? _preview;
  List<Debt>? _pending;
  String? _filename;
  String? _error;
  var _busy = false;

  Future<void> _shareTemplate() async {
    try {
      await shareExport(
        context,
        bytes: Uint8List.fromList(utf8.encode(debtCsvTemplate)),
        filename: 'pago-modelo-lancamentos.csv',
        mimeType: 'text/csv',
        subject: 'Modelo de importação do Pagô',
      );
    } catch (_) {
      if (mounted) {
        showPagoSnack(context, 'Não foi possível compartilhar o modelo.');
      }
    }
  }

  Future<void> _selectFile() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (file == null || !mounted) return;
      final length = await file.length();
      if (length != null && length > 1024 * 1024) {
        throw const FormatException('Escolha um CSV de até 1 MB.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > 1024 * 1024) {
        throw const FormatException('Escolha um CSV de até 1 MB.');
      }
      final text = utf8.decode(bytes);
      if (!mounted) return;
      final state = context.read<AppController>();
      setState(() {
        _filename = file.name;
        _preview = previewDebtCsv(text, existing: state.debts);
        _pending = null;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível ler o arquivo. Salve-o como CSV UTF-8 e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (_busy || preview == null || !preview.canImport) return;
    final state = context.read<AppController>();
    _pending ??= [
      for (final row in preview.validRows)
        Debt(
          id: state.newId(),
          userId: state.user.id,
          nome: row.nome,
          telefone: row.telefone,
          valorPrincipal: row.valorCents! / 100,
          taxaJuros: row.juros!,
          dataVencimento: row.vencimento!,
          statusPago: false,
          clientScore: 80,
          createdAt: DateTime.now(),
        ),
    ];
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.createDebts(_pending!);
      if (!mounted) return;
      showPagoSnack(context, '${_pending!.length} lançamentos importados.');
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível confirmar a importação. Os mesmos lançamentos serão usados ao tentar novamente.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Importar lançamentos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Traga até 12 lançamentos por vez',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Baixe o modelo, preencha sem mudar os nomes das colunas e confira a prévia. Nada é gravado antes da confirmação.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _shareTemplate,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Compartilhar arquivo-modelo'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _selectFile,
            icon: const Icon(Icons.file_open_outlined),
            label: Text(
              _filename == null ? 'Escolher arquivo CSV' : 'Trocar arquivo CSV',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _Message(text: _error!, danger: true),
          ],
          if (preview != null) ...[
            const SizedBox(height: 20),
            Text(
              _filename ?? 'Arquivo selecionado',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${preview.validRows.length} prontos · ${preview.duplicateCount} duplicados · ${preview.invalidCount} com erro',
              style: const TextStyle(color: AppColors.mutedDark),
            ),
            for (final error in preview.errors) ...[
              const SizedBox(height: 10),
              _Message(text: error, danger: true),
            ],
            const SizedBox(height: 14),
            for (final row in preview.rows) _PreviewRow(row: row),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy || !preview.canImport ? null : _import,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                _busy
                    ? 'Importando…'
                    : 'Confirmar ${preview.validRows.length} lançamentos',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.row});

  final DebtCsvRow row;

  @override
  Widget build(BuildContext context) {
    final problem = row.duplicate
        ? 'Duplicado — não será importado'
        : row.errors.join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: row.valid ? AppColors.line : AppColors.dangerBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Linha ${row.line} · ${row.nome.isEmpty ? 'Sem nome' : row.nome}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (row.valid) ...[
            const SizedBox(height: 4),
            Text(
              '${Money.full(row.valorCents! / 100)} · vence ${Dates.full(row.vencimento!)} · juros ${row.juros!.toStringAsFixed(2).replaceAll('.', ',')}%',
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(problem, style: const TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.danger});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: danger ? AppColors.dangerSoft : AppColors.primarySoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(text),
  );
}
