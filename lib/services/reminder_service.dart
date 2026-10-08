import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';
import '../utils/formatters.dart';
import 'whatsapp_service.dart';

enum ReminderKind { amanha, hoje, atraso }

ReminderKind? reminderKind({
  required DateTime due,
  required DateTime day,
  required bool pago,
}) {
  if (pago) return null;
  final vencimento = DateTime(due.year, due.month, due.day);
  final start = DateTime(day.year, day.month, day.day);
  if (vencimento == start) return ReminderKind.hoje;
  if (vencimento == start.add(const Duration(days: 1))) {
    return ReminderKind.amanha;
  }
  if (vencimento.isBefore(start)) return ReminderKind.atraso;
  return null;
}

enum BoletoAviso { emTresDias, amanha, hoje, vencido }

BoletoAviso? boletoAviso({
  required DateTime due,
  required DateTime day,
  required bool pago,
}) {
  if (pago) return null;
  final vencimento = DateTime(due.year, due.month, due.day);
  final start = DateTime(day.year, day.month, day.day);
  final dias = vencimento.difference(start).inDays;
  if (dias < 0) return BoletoAviso.vencido;
  if (dias == 0) return BoletoAviso.hoje;
  if (dias == 1) return BoletoAviso.amanha;
  if (dias == 3) return BoletoAviso.emTresDias;
  return null;
}

WhatsAppAction whatsAppActionForReminder(ReminderKind kind) {
  switch (kind) {
    case ReminderKind.amanha:
      return WhatsAppAction.preventivo;
    case ReminderKind.hoje:
      return WhatsAppAction.cobrarHoje;
    case ReminderKind.atraso:
      return WhatsAppAction.atraso;
  }
}

class ReminderService {
  ReminderService();

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;
  final _debtsById = <String, Debt>{};
  var _saldos = <String, double>{};
  var _chavePix = '';
  var _customTemplate = '';
  var _isPremium = false;

  bool get _supported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> init() async {
    if (_ready || !_supported) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      } catch (error) {
        debugPrint('Fuso horário indisponível: $error');
        return;
      }
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  Future<void> sync({
    required bool enabled,
    required List<Debt> debts,
    Map<String, double> saldos = const {},
    String chavePix = '',
    String customTemplate = '',
    bool isPremium = false,
    List<Boleto> boletos = const [],
  }) async {
    await init();
    if (!_ready) return;
    await _plugin.cancelAll();
    _debtsById
      ..clear()
      ..addEntries(debts.map((debt) => MapEntry(debt.id, debt)));
    _saldos = Map<String, double>.from(saldos);
    _chavePix = chavePix;
    _customTemplate = customTemplate;
    _isPremium = isPremium;
    if (!enabled) return;

    const androidDetails = AndroidNotificationDetails(
      'cobrancas',
      'Lembretes de cobrança',
      channelDescription: 'Avisos no dia anterior e no vencimento',
      importance: Importance.high,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('depois', 'Agora não'),
        AndroidNotificationAction('enviar', 'Enviar cobrança'),
      ],
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final now = DateTime.now();
    var slot = 0;
    for (var offset = 0; offset < 14; offset++) {
      final day =
          DateTime(now.year, now.month, now.day).add(Duration(days: offset));
      final atNine = DateTime(day.year, day.month, day.day, 9);
      if (!atNine.isAfter(now)) continue;
      final when = tz.TZDateTime(
        tz.local,
        atNine.year,
        atNine.month,
        atNine.day,
        9,
      );

      for (final kind in ReminderKind.values) {
        final group = debts
            .where(
              (debt) =>
                  reminderKind(
                    due: debt.dataVencimento,
                    day: day,
                    pago: debt.statusPago,
                  ) ==
                  kind,
            )
            .toList();
        if (group.isEmpty) continue;
        await _plugin.zonedSchedule(
          slot,
          _title(kind, group),
          _body(group),
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: '${kind.name}|${group.first.id}',
        );
        slot++;
      }

      for (final aviso in BoletoAviso.values) {
        final group = boletos
            .where(
              (boleto) =>
                  boletoAviso(
                    due: boleto.dataVencimento,
                    day: day,
                    pago: boleto.statusPago,
                  ) ==
                  aviso,
            )
            .toList();
        if (group.isEmpty) continue;
        await _plugin.zonedSchedule(
          slot,
          _boletoTitle(aviso, group),
          _boletoBody(group),
          when,
          _boletoDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'boleto|${aviso.name}|${group.first.id}',
        );
        slot++;
      }
    }
  }

  static const _boletoDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'boletos',
      'Boletos a pagar',
      channelDescription: 'Avisos de vencimento dos boletos da empresa',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  String _boletoTitle(BoletoAviso aviso, List<Boleto> boletos) {
    if (boletos.length == 1) {
      final boleto = boletos.first;
      final empresa = boleto.parcelado
          ? '${boleto.empresa} (${boleto.parcela}/${boleto.parcelas})'
          : boleto.empresa;
      switch (aviso) {
        case BoletoAviso.emTresDias:
          return 'Boleto de $empresa vence em 3 dias.';
        case BoletoAviso.amanha:
          return 'Boleto de $empresa vence amanhã.';
        case BoletoAviso.hoje:
          return 'E aí, pagô? Boleto de $empresa vence hoje.';
        case BoletoAviso.vencido:
          return 'Boleto de $empresa está vencido.';
      }
    }
    final n = boletos.length;
    switch (aviso) {
      case BoletoAviso.emTresDias:
        return '$n boletos vencem em 3 dias.';
      case BoletoAviso.amanha:
        return '$n boletos vencem amanhã.';
      case BoletoAviso.hoje:
        return 'E aí, pagô? $n boletos vencem hoje.';
      case BoletoAviso.vencido:
        return '$n boletos vencidos.';
    }
  }

  String _boletoBody(List<Boleto> boletos) {
    final total = boletos.fold<double>(0, (sum, item) => sum + item.valor);
    if (boletos.length == 1) {
      return '${Money.full(total)}. Abra o app para copiar o código.';
    }
    return 'Total ${Money.full(total)}. Abra o app para ver.';
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    if (response.actionId == 'depois') return;
    final payload = response.payload ?? '';
    final parts = payload.split('|');
    if (parts.length < 2) return;
    final kind = ReminderKind.values.where((item) => item.name == parts[0]);
    if (kind.isEmpty) return;
    final debt = _debtsById[parts[1]];
    if (debt == null) return;
    await WhatsAppService.open(
      action: whatsAppActionForReminder(kind.first),
      tone: WhatsAppTone.amigavel,
      debt: debt,
      saldo: _saldos[debt.id] ?? debt.valorPrincipal,
      chavePix: _chavePix,
      customTemplate: _customTemplate,
      isPremium: _isPremium,
    );
  }

  String _title(ReminderKind kind, List<Debt> debts) {
    final nome = debts.first.nome;
    if (debts.length == 1) {
      switch (kind) {
        case ReminderKind.amanha:
          return 'O prazo de $nome se encerra amanhã.';
        case ReminderKind.hoje:
          return 'O prazo de $nome vence hoje.';
        case ReminderKind.atraso:
          return '$nome está em atraso.';
      }
    }
    switch (kind) {
      case ReminderKind.amanha:
        return '${debts.length} prazos se encerram amanhã.';
      case ReminderKind.hoje:
        return '${debts.length} prazos vencem hoje.';
      case ReminderKind.atraso:
        return '${debts.length} cadernetas em atraso.';
    }
  }

  String _body(List<Debt> debts) {
    if (debts.length == 1) {
      return 'Gostaria de mandar uma mensagem?';
    }
    final names = debts.take(3).map((debt) => debt.nome).join(', ');
    if (debts.length <= 3) return names;
    return '$names e mais ${debts.length - 3}';
  }
}
