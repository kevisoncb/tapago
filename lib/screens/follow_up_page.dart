import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/collection_follow_up.dart';
import '../state/app_controller.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class FollowUpPage extends StatefulWidget {
  const FollowUpPage({
    super.key,
    required this.contactKey,
    required this.clientName,
  });

  final String contactKey;
  final String clientName;

  @override
  State<FollowUpPage> createState() => _FollowUpPageState();
}

class _FollowUpPageState extends State<FollowUpPage> {
  final _note = TextEditingController();
  final _amount = TextEditingController();
  late CollectionFollowUpStore _store;
  DateTime? _contacted;
  DateTime? _nextDate;
  var _loading = true;
  var _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppController>();
    _store = CollectionFollowUpStore(
      usesFirestore: state.usesFirestore,
      userId: state.user.id,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final value = await _store.get(widget.contactKey);
      if (!mounted) return;
      _note.text = value?.note ?? '';
      _amount.text =
          value?.promisedAmount?.toStringAsFixed(2).replaceAll('.', ',') ?? '';
      _contacted = value?.lastContactedAt;
      _nextDate = value?.nextContactAt;
    } catch (_) {
      _loadError = 'Não foi possível carregar o acompanhamento. Confira a conexão e tente novamente.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _loadError != null) return;
    final raw = _amount.text.trim();
    final validFormat = RegExp(
      r'^(?:[0-9]+|[0-9]{1,3}(?:\.[0-9]{3})+)(?:,[0-9]{1,2})?$',
    ).hasMatch(raw);
    final amount = raw.isEmpty || !validFormat
        ? null
        : double.tryParse(raw.replaceAll('.', '').replaceAll(',', '.'));
    if (raw.isNotEmpty &&
        (amount == null ||
            !amount.isFinite ||
            amount <= 0 ||
            amount > 100000000)) {
      showPagoSnack(
        context,
        'Informe um valor combinado válido, ou deixe em branco.',
      );
      return;
    }
    if (amount != null && _nextDate == null) {
      showPagoSnack(
        context,
        'Escolha a data combinada para acompanhar a promessa.',
      );
      return;
    }
    setState(() => _saving = true);
    final state = context.read<AppController>();
    try {
      await _store.save(
        CollectionFollowUp(
          userId: state.user.id,
          contactKey: widget.contactKey,
          clientName: widget.clientName,
          note: _note.text.trim(),
          lastContactedAt: _contacted,
          nextContactAt: _nextDate,
          promisedAmount: amount == null ? null : (amount * 100).round() / 100,
        ),
      );
      await state.refreshReminders();
      if (!mounted) return;
      showPagoSnack(
        context,
        'Acompanhamento salvo. Nenhuma baixa foi registrada.',
      );
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        showPagoSnack(
          context,
          'Não foi possível salvar. Sua anotação continua aqui para tentar novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _nextDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Data combinada ou próximo contato',
    );
    if (mounted && date != null) setState(() => _nextDate = date);
  }

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Acompanhar conversa')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _loadError != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.clientName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Anote o combinado com o cliente. Isso não envia mensagens, não confirma entrega e não altera o saldo.',
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(
                  _contacted == null
                      ? 'Sem contato registrado'
                      : 'Contato registrado em ${Dates.full(_contacted!)}',
                ),
                subtitle: const Text(
                  'Marque apenas depois de conversar com o cliente.',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() => _contacted = DateTime.now()),
                icon: const Icon(Icons.check),
                label: const Text('Marcar que conversei hoje'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _note,
                maxLength: 1000,
                minLines: 3,
                maxLines: 6,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Anotação privada',
                  hintText: 'Ex.: combinamos de conversar na sexta.',
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _nextDate == null
                      ? 'Escolher próximo contato ou data combinada'
                      : 'Combinado para ${Dates.full(_nextDate!)}',
                ),
              ),
              if (_nextDate != null)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _nextDate = null;
                          _amount.clear();
                        }),
                  child: const Text('Remover data combinada'),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Valor prometido (opcional)',
                  prefixText: 'R\$ ',
                  helperText: 'Uma promessa não é uma baixa na caderneta.',
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Salvando…' : 'Salvar acompanhamento'),
              ),
            ],
          ),
  );
}
