import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/collection_follow_up.dart';
import 'package:pago_app/services/local_repository.dart';
import 'package:pago_app/services/push_service.dart';
import 'package:pago_app/services/reminder_service.dart';
import 'package:pago_app/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fcm extends Fake implements FirebaseMessaging {
  _Fcm({this.status = AuthorizationStatus.notDetermined});

  AuthorizationStatus status;
  final String? token = 'token-abc';
  int asked = 0;

  @override
  Future<NotificationSettings> getNotificationSettings() async => _settings(status);

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    asked++;
    status = AuthorizationStatus.authorized;
    return _settings(status);
  }

  @override
  Future<String?> getToken({String? serviceWorkerScriptPath, String? vapidKey}) async => token;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

NotificationSettings _settings(AuthorizationStatus status) => NotificationSettings(
  alert: AppleNotificationSetting.enabled,
  announcement: AppleNotificationSetting.notSupported,
  authorizationStatus: status,
  badge: AppleNotificationSetting.enabled,
  carPlay: AppleNotificationSetting.notSupported,
  lockScreen: AppleNotificationSetting.enabled,
  notificationCenter: AppleNotificationSetting.enabled,
  showPreviews: AppleShowPreviewSetting.notSupported,
  timeSensitive: AppleNotificationSetting.notSupported,
  criticalAlert: AppleNotificationSetting.notSupported,
  sound: AppleNotificationSetting.enabled,
  providesAppNotificationSettings: AppleNotificationSetting.notSupported,
);

class _Registrar implements PushRegistrar {
  _Registrar(this.result);

  bool result;
  int registers = 0;
  int unregisters = 0;
  bool? askedPermission;

  @override
  Future<bool> register({bool askPermission = false}) async {
    registers++;
    askedPermission = (askedPermission ?? false) || askPermission;
    return result;
  }

  @override
  Future<void> unregister() async => unregisters++;
}

class _Reminders extends Fake implements ReminderService {
  final syncs = <bool>[];
  bool permission = true;

  @override
  Future<bool> requestPermission() async => permission;

  @override
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
    bool serverPush = false,
  }) async {
    syncs.add(serverPush);
  }
}

Future<AppController> _controller(_Reminders reminders, PushRegistrar push) async {
  SharedPreferences.setMockInitialValues({});
  final repository = LocalRepository(userId: 'push-test');
  await repository.init();
  await repository.saveUser(
    const AppUser(
      id: 'push-test',
      nome: 'Loja Teste',
      email: 'teste@example.com',
      isPremium: false,
      chavePix: '',
    ),
  );
  final controller = AppController(repository, reminders: reminders, push: push);
  await controller.load();
  return controller;
}

void main() {
  group('PushService', () {
    final requests = <http.Request>[];
    late http.Client client;
    var status = 200;

    setUp(() {
      requests.clear();
      status = 200;
      client = MockClient((request) async {
        requests.add(request);
        return http.Response('{}', status);
      });
    });

    PushService service(_Fcm fcm) => PushService(
      httpClient: client,
      messaging: fcm,
      baseUrl: 'https://exemplo.test/api/',
      idToken: () async => 'id-token',
      platformName: 'android',
    );

    test('sem permissão e sem pedir, não registra nada', () async {
      final fcm = _Fcm();
      expect(await service(fcm).register(), isFalse);
      expect(fcm.asked, 0);
      expect(requests, isEmpty);
    });

    test('pedindo a permissão, registra o aparelho uma única vez', () async {
      final fcm = _Fcm();
      final push = service(fcm);
      expect(await push.register(askPermission: true), isTrue);
      expect(await push.register(), isTrue);
      expect(fcm.asked, 1);
      expect(requests, hasLength(1));
      expect(requests.single.url.toString(), 'https://exemplo.test/api/devices/register');
      expect(requests.single.headers['Authorization'], 'Bearer id-token');
      expect(jsonDecode(requests.single.body), {'token': 'token-abc', 'platform': 'android'});
    });

    test('falha do servidor não conta como registrado', () async {
      status = 404;
      final fcm = _Fcm(status: AuthorizationStatus.authorized);
      expect(await service(fcm).register(), isFalse);
    });

    test('permissão negada não registra', () async {
      final fcm = _Fcm(status: AuthorizationStatus.denied);
      expect(await service(fcm).register(askPermission: true), isFalse);
      expect(requests, isEmpty);
    });

    test('desregistrar avisa o servidor e esquece o token', () async {
      final fcm = _Fcm(status: AuthorizationStatus.authorized);
      final push = service(fcm);
      await push.register();
      await push.unregister();
      expect(jsonDecode(requests.last.body), {'token': 'token-abc', 'remove': true});
      await push.unregister();
      expect(requests, hasLength(2));
    });
  });

  group('avisos do servidor e do aparelho', () {
    test('com o push confirmado, o aparelho não agenda avisos próprios', () async {
      final reminders = _Reminders();
      final controller = await _controller(reminders, _Registrar(true));
      expect(reminders.syncs.last, isTrue);
      expect(controller.canOfferDailyReminders, isFalse);
    });

    test('sem confirmação do servidor, os avisos locais continuam', () async {
      final reminders = _Reminders();
      final controller = await _controller(reminders, _Registrar(false));
      expect(reminders.syncs.last, isFalse);
      expect(controller.canOfferDailyReminders, isTrue);
    });

    test('ligar os avisos pede permissão e registra o aparelho', () async {
      final reminders = _Reminders();
      final push = _Registrar(true);
      final controller = await _controller(reminders, push);
      push.askedPermission = null;
      expect(await controller.enableDailyReminders(), isTrue);
      expect(push.askedPermission, isTrue);
    });

    test('permissão negada não liga os avisos', () async {
      final reminders = _Reminders()..permission = false;
      final push = _Registrar(true);
      final controller = await _controller(reminders, push);
      push.registers = 0;
      expect(await controller.enableDailyReminders(), isFalse);
      expect(push.registers, 0);
    });

    test('sair da conta desregistra o aparelho', () async {
      final reminders = _Reminders();
      final push = _Registrar(true);
      final controller = await _controller(reminders, push);
      await controller.signOut();
      expect(push.unregisters, 1);
    });
  });
}
