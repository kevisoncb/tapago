import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../utils/constants.dart';

class PixCharge {
  const PixCharge({
    required this.paymentId,
    required this.payload,
    required this.encodedImage,
    required this.status,
  });

  final String paymentId;
  final String payload;
  final String encodedImage;
  final String status;
}

class AsaasClient {
  AsaasClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _base = (baseUrl ?? AppConstants.asaasApiBase).replaceAll(RegExp(r'/+$'), '');

  final http.Client _http;
  final String _base;

  bool get isConfigured => _base.isNotEmpty;

  Future<PixCharge> createPix({
    required String userId,
    required String name,
    required String email,
    String? cpf,
  }) async {
    final response = await _http.post(
      Uri.parse('$_base/premium/pix'),
      headers: await _headers(),
      body: jsonEncode({
        'userId': userId,
        'name': name,
        'email': email,
        if (cpf != null && cpf.isNotEmpty) 'cpf': cpf,
      }),
    );
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw AsaasException(_message(data) ?? 'Não foi possível gerar o PIX.');
    }
    return PixCharge(
      paymentId: data['paymentId'] as String? ?? '',
      payload: data['payload'] as String? ?? '',
      encodedImage: data['encodedImage'] as String? ?? '',
      status: data['status'] as String? ?? 'PENDING',
    );
  }

  Future<String> status({
    required String paymentId,
    required String userId,
  }) async {
    final uri = Uri.parse('$_base/premium/pix/$paymentId').replace(
      queryParameters: {'userId': userId},
    );
    final response = await _http.get(uri, headers: await _headers());
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw AsaasException(_message(data) ?? 'Não foi possível consultar o PIX.');
    }
    return data['status'] as String? ?? 'PENDING';
  }

  Future<void> confirmPlayPurchase({String? transactionId}) async {
    final response = await _http.post(
      Uri.parse('$_base/play/confirm'),
      headers: await _headers(),
      body: jsonEncode({
        if (transactionId != null && transactionId.isNotEmpty)
          'transactionId': transactionId,
      }),
    );
    if (response.statusCode >= 400) {
      final data = _decode(response);
      throw AsaasException(
        _message(data) ?? 'Não foi possível confirmar a compra na loja.',
      );
    }
  }

  Future<Map<String, String>> _headers() async {
    final headers = {'content-type': 'application/json'};
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  String? _message(Map<String, dynamic> data) {
    final message = data['message'];
    if (message is String && message.isNotEmpty) return message;
    return null;
  }
}

class AsaasException implements Exception {
  AsaasException(this.message);
  final String message;

  @override
  String toString() => message;
}
