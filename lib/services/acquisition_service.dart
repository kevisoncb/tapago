import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// De onde veio a instalação (utm_source, utm_medium, utm_campaign do link da
/// Play). Serve só para o painel mostrar quanto cada canal rende. O app envia
/// uma vez por conta e não leva dado pessoal.
class AcquisitionSource {
  const AcquisitionSource({
    required this.source,
    required this.medium,
    required this.campaign,
    this.content = '',
    this.term = '',
  });

  final String source;
  final String medium;
  final String campaign;
  final String content;
  final String term;

  /// Interpreta o texto do Install Referrer, por exemplo
  /// `utm_source=instagram&utm_medium=cpc&utm_campaign=lancamento`.
  /// Sem parâmetros utm, a origem é orgânica.
  factory AcquisitionSource.parse(String? referrer) {
    final params = <String, String>{};
    final raw = (referrer ?? '').trim();
    if (raw.isNotEmpty) {
      try {
        params.addAll(Uri.splitQueryString(raw));
      } catch (_) {}
    }
    String field(String key) {
      final text = (params[key] ?? '')
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9._-]'), '');
      return text.length > 64 ? text.substring(0, 64) : text;
    }

    final source = field('utm_source');
    if (source.isEmpty) {
      return const AcquisitionSource(
        source: 'organico',
        medium: 'organico',
        campaign: '',
      );
    }
    return AcquisitionSource(
      source: source,
      medium: field('utm_medium').isEmpty ? 'indefinido' : field('utm_medium'),
      campaign: field('utm_campaign'),
      content: field('utm_content'),
      term: field('utm_term'),
    );
  }

  Map<String, String> toJson() => {
    'source': source,
    'medium': medium,
    'campaign': campaign,
    'content': content,
    'term': term,
  };
}

class AcquisitionService {
  AcquisitionService({
    http.Client? httpClient,
    String? baseUrl,
    Future<String?> Function()? idToken,
    Future<String?> Function()? readReferrer,
  }) : _http = httpClient ?? http.Client(),
       _base = (baseUrl ?? AppConstants.asaasApiBase).replaceAll(
         RegExp(r'/+$'),
         '',
       ),
       _idToken = idToken ?? _firebaseIdToken,
       _readReferrer = readReferrer ?? _playReferrer;

  static final instance = AcquisitionService();

  final http.Client _http;
  final String _base;
  final Future<String?> Function() _idToken;
  final Future<String?> Function() _readReferrer;

  static Future<String?> _firebaseIdToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _playReferrer() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final details = await PlayInstallReferrer.installReferrer;
      return details.installReferrer;
    } catch (_) {
      return null;
    }
  }

  /// Registra a origem da conta no servidor, no máximo uma vez por aparelho e
  /// conta. Falhas são silenciosas e tentadas de novo no próximo acesso.
  Future<bool> registerOnce(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'pago_acquisition_$uid';
      if (prefs.getBool(key) == true) return true;
      final source = AcquisitionSource.parse(await _readReferrer());
      final token = await _idToken();
      if (token == null || token.isEmpty) return false;
      final response = await _http.post(
        Uri.parse('$_base/acquisition/register'),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          ...source.toJson(),
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        }),
      );
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (ok) await prefs.setBool(key, true);
      return ok;
    } catch (error) {
      debugPrint('Origem da conta: $error');
      return false;
    }
  }
}
