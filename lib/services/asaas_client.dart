import 'dart:convert';

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
      headers: {'content-type': 'application/json'},
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
    final response = await _http.get(uri);
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw AsaasException(_message(data) ?? 'Não foi possível consultar o PIX.');
    }
    return data['status'] as String? ?? 'PENDING';
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
