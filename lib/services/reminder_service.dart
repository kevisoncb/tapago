import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';
import '../utils/formatters.dart';
import 'collection_follow_up.dart';
import 'whatsapp_service.dart';

enum ReminderKind { amanha, hoje, atraso }

/// Identificador de navegação, sem nome, valor ou chave PIX no payload.
class ReminderTarget {
  const ReminderTarget({
    required this.id,
    required this.isBill,
    this.isFollowUp = false,
    this.userId,
  });

  final String id;
  final bool isBill;
  final bool isFollowUp;
  final String? userId;

  static ReminderTarget? parse(String? payload) {
    final parts = (payload ?? '').split('|');
    if (parts.length < 2 || parts.length > 3 || parts[1].isEmpty) return null;
    if (parts[1].contains('/') || parts[1].length > 100) return null;
    final bill = parts[0] == 'boleto';
    final followUp = parts[0] == 'acompanhamento';
    if (!bill &&
        !followUp &&
        !ReminderKind.values.any((kind) => kind.name == parts[0])) {
      return null;
    }
    return ReminderTarget(
      id: parts[1],
      isBill: bill,
      isFollowUp: followUp,
      userId: parts.length == 3 && parts[2].isNotEmpty ? parts[2] : null,
    );
  }
}

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

enum BillReminderKind { tresDias, amanha, hoje, atraso }

BillReminderKind? billReminderKind({
  required DateTime due,
  required DateTime day,
  required bool pago,
}) {
  if (pago) return null;
  final vencimento = DateTime(due.year, due.month, due.day);
  final start = DateTime(day.year, day.month, day.day);
  if (vencimento.isBefore(start)) return BillReminderKind.atraso;
  final dias = DateTime.utc(
    vencimento.year,
    vencimento.month,
    vencimento.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  switch (dias) {
    case 0:
      return BillReminderKind.hoje;
    case 1:
      return BillReminderKind.amanha;
    case 3:
      return BillReminderKind.tresDias;
  }
  return null;
}

String billReminderTitle(BillReminderKind kind, List<Bill> bills) {
  if (bills.length == 1) {
    final fornecedor = bills.first.fornecedor;
    switch (kind) {
      case BillReminderKind.tresDias:
        return 'Boleto de $fornecedor vence em 3 dias.';
      case BillReminderKind.amanha:
        return 'Boleto de $fornecedor vence amanhã.';
      case BillReminderKind.hoje:
        return 'Boleto de $fornecedor vence hoje.';
      case BillReminderKind.atraso:
        return 'Boleto de $fornecedor está atrasado.';
    }
  }
  switch (kind) {
    case BillReminderKind.tresDias:
      return '${bills.length} boletos vencem em 3 dias.';
    case BillReminderKind.amanha:
      return '${bills.length} boletos vencem amanhã.';
    case BillReminderKind.hoje:
      return '${bills.length} boletos vencem hoje.';
    case BillReminderKind.atraso:
      return '${bills.length} boletos atrasados.';
  }
}

String billReminderBody(List<Bill> bills) {
  final total = bills.fold<double>(0, (sum, bill) => sum + bill.valor);
  return 'Total ${Money.full(total)}. Toque para abrir.';
}

class ReminderService {
  ReminderService({this.onOpen});

  final Future<void> Function(ReminderTarget target)? onOpen;

  // Agenda limitada pelo SO. Ela é refeita ao carregar/retomar o app; não é
  // uma promessa de renovação em background sem execução do aplicativo.
  static const scheduleHorizonDays = 14;
  static const maxScheduledNotifications = 60;

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;
  Future<void>? _initializing;
  Future<void> _syncWork = Future.value();
  bool get _supported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> init() {
    if (_ready || !_supported) return Future.value();
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
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
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response != null) {
      await _onNotificationResponse(response);
    }
  }

  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  Future<void> sync({
    required bool enabled,
    bool followUpsEnabled = false,
    required List<Debt> debts,
    List<CollectionFollowUp> followUps = const [],
    Map<String, double> saldos = const {},
    String chavePix = '',
    String customTemplate = '',
    bool isPremium = false,
    List<Bill> bills = const [],
  }) {
    // Atualizações de perfil e lançamentos podem chegar juntas. Serializar
    // evita cancelAll de uma chamada apagar a agenda da chamada seguinte.
    final debtSnapshot = List<Debt>.of(debts);
    final billSnapshot = List<Bill>.of(bills);
    final followUpSnapshot = List<CollectionFollowUp>.of(followUps);
    _syncWork = _syncWork
        .catchError((Object _) {})
        .then(
          (_) => _performSync(
            enabled: enabled,
            followUpsEnabled: followUpsEnabled,
            debts: debtSnapshot,
            bills: billSnapshot,
            followUps: followUpSnapshot,
          ),
        );
    return _syncWork;
  }

  Future<void> _performSync({
    required bool enabled,
    required bool followUpsEnabled,
    required List<Debt> debts,
    required List<Bill> bills,
    required List<CollectionFollowUp> followUps,
  }) async {
    await init();
    if (!_ready) return;
    await _plugin.cancelAll();
    if (!enabled && !followUpsEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'cobrancas',
      'Lembretes de cobrança',
      channelDescription: 'Avisos no dia anterior e no vencimento',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('depois', 'Agora não'),
        AndroidNotificationAction(
          'enviar',
          'Ver cobrança',
          showsUserInterface: true,
        ),
      ],
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    const billDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'boletos',
        'Boletos a pagar',
        channelDescription: 'Avisos de boletos que você precisa pagar',
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.private,
      ),
      iOS: DarwinNotificationDetails(),
    );
    const followUpDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'acompanhamentos',
        'Acompanhamentos combinados',
        channelDescription: 'Avisos de contatos e datas combinadas por você',
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.private,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final now = DateTime.now();
    var slot = 0;
    for (var offset = 0; offset < scheduleHorizonDays; offset++) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: offset));
      final atNine = DateTime(day.year, day.month, day.day, 9);
      if (!atNine.isAfter(now)) continue;
      final when = tz.TZDateTime(
        tz.local,
        atNine.year,
        atNine.month,
        atNine.day,
        9,
      );

      if (enabled) {
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
          if (slot >= maxScheduledNotifications) return;
          await _plugin.zonedSchedule(
            slot,
            _title(kind, group),
            _body(group),
            when,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: '${kind.name}|${group.first.id}|${group.first.userId}',
          );
          slot++;
        }
      }

      if (enabled) {
        for (final kind in BillReminderKind.values) {
          final group = bills
              .where(
                (bill) =>
                    billReminderKind(
                      due: bill.dataVencimento,
                      day: day,
                      pago: bill.pago,
                    ) ==
                    kind,
              )
              .toList();
          if (group.isEmpty) continue;
          if (slot >= maxScheduledNotifications) return;
          await _plugin.zonedSchedule(
            slot,
            billReminderTitle(kind, group),
            billReminderBody(group),
            when,
            billDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'boleto|${group.first.id}|${group.first.userId}',
          );
          slot++;
        }
      }

      if (followUpsEnabled) {
        final scheduled = followUps
            .where(
              (item) =>
                  item.nextContactAt != null &&
                  item.timingAt(day) == FollowUpTiming.today,
            )
            .toList();
        if (scheduled.isNotEmpty) {
          if (slot >= maxScheduledNotifications) return;
          await _plugin.zonedSchedule(
            slot,
            scheduled.length == 1
                ? 'Você combinou um acompanhamento para hoje.'
                : '${scheduled.length} acompanhamentos combinados para hoje.',
            'Toque para abrir sua agenda. Nenhuma mensagem será enviada.',
            when,
            followUpDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'acompanhamento|agenda|${scheduled.first.userId}',
          );
          slot++;
        }
      }
    }
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    if (response.actionId == 'depois') return;
    final target = ReminderTarget.parse(response.payload);
    if (target == null) return;
    // Tocar abre o contexto no app; jamais dispara WhatsApp automaticamente,
    // especialmente antes de confirmar a conta e desbloquear a interface.
    await onOpen?.call(target);
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
