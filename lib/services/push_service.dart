import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/constants.dart';

/// Lembretes enviados pelo servidor todo dia às 9h (Brasília), para todos.
///
/// O aparelho só informa o próprio token ao servidor. O texto do aviso leva
/// apenas contagens; nada de nome, valor ou chave PIX.
abstract class PushRegistrar {
  /// Registra o aparelho. Com [askPermission] pede a permissão ao usuário;
  /// sem ele só registra se a permissão já foi dada. Retorna `true` quando o
  /// servidor confirmou o registro.
  Future<bool> register({bool askPermission = false});

  /// Remove o aparelho do usuário atual (sair da conta ou desligar os avisos).
  Future<void> unregister();
}

class PushService implements PushRegistrar {
  PushService({
    http.Client? httpClient,
    this._messaging,
    String? baseUrl,
    Future<String?> Function()? idToken,
    this._platformName,
  }) : _http = httpClient ?? http.Client(),
       _base = (baseUrl ?? AppConstants.asaasApiBase).replaceAll(
         RegExp(r'/+$'),
         '',
       ),
       _idToken = idToken ?? _firebaseIdToken;

  final http.Client _http;
  FirebaseMessaging? _messaging;
  final String _base;
  final Future<String?> Function() _idToken;
  final String? _platformName;

  String? _registeredToken;
  StreamSubscription<String>? _refresh;

  FirebaseMessaging get _fcm => _messaging ??= FirebaseMessaging.instance;

  String? get _platform {
    final forced = _platformName;
    if (forced != null) return forced;
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return null;
    }
  }

  static Future<String?> _firebaseIdToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> register({bool askPermission = false}) async {
    final platform = _platform;
    if (platform == null) return false;
    try {
      var settings = await _fcm.getNotificationSettings();
      if (askPermission &&
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await _fcm.requestPermission();
      }
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) return false;

      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) return false;
      if (token == _registeredToken) return true;
      if (!await _send({'token': token, 'platform': platform})) return false;
      _registeredToken = token;
      _refresh ??= _fcm.onTokenRefresh.listen((next) async {
        if (await _send({'token': next, 'platform': platform})) {
          _registeredToken = next;
        }
      });
      return true;
    } catch (error) {
      debugPrint('Push: $error');
      return false;
    }
  }

  @override
  Future<void> unregister() async {
    final token = _registeredToken;
    _registeredToken = null;
    await _refresh?.cancel();
    _refresh = null;
    if (token == null) return;
    try {
      await _send({'token': token, 'remove': true});
    } catch (error) {
      debugPrint('Push: $error');
    }
  }

  Future<bool> _send(Map<String, Object?> body) async {
    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) return false;
    final response = await _http.post(
      Uri.parse('$_base/devices/register'),
      headers: {
        'content-type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(body),
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }
}
