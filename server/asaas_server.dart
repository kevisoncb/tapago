import 'dart:convert';
import 'dart:io';

/// Servidor do PIX do Premium. A chave do Asaas fica no `.env` da raiz
/// (ou nas variáveis de ambiente). Esse arquivo não entra no Git.
///
/// ASAAS_API_KEY   chave do sandbox ou da produção
/// ASAAS_BASE_URL  padrão https://api-sandbox.asaas.com/v3
/// ASAAS_PORT      padrão 8787
/// ASAAS_WEBHOOK_TOKEN  se definido, o webhook precisa mandar o mesmo valor
///                      no cabeçalho asaas-access-token
Future<Map<String, String>> _loadEnv() async {
  final env = Map<String, String>.from(Platform.environment);
  final file = File('.env');
  if (!await file.exists()) return env;
  for (final raw in await file.readAsLines()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final sep = line.indexOf('=');
    if (sep <= 0) continue;
    final key = line.substring(0, sep).trim();
    var value = line.substring(sep + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    final current = env[key];
    if (current == null || current.isEmpty) env[key] = value;
  }
  return env;
}

Future<void> main() async {
  final env = await _loadEnv();
  final apiKey = env['ASAAS_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    stderr.writeln('Defina ASAAS_API_KEY antes de subir o servidor.');
    exitCode = 1;
    return;
  }

  final asaasBase = (env['ASAAS_BASE_URL'] ?? 'https://api-sandbox.asaas.com/v3')
      .replaceAll(RegExp(r'/+$'), '');
  final port = int.tryParse(env['ASAAS_PORT'] ?? '') ?? 8787;
  final webhookToken = env['ASAAS_WEBHOOK_TOKEN'] ?? '';
  final store = _PaymentStore(File('server/data/payments.json'));
  await store.load();

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('PIX do TáPago em http://localhost:$port');

  await for (final request in server) {
    _cors(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      continue;
    }
    try {
      await _route(
        request,
        asaasBase: asaasBase,
        apiKey: apiKey,
        webhookToken: webhookToken,
        store: store,
      );
    } catch (error) {
      _json(request.response, HttpStatus.badGateway, {
        'message': 'Falha ao falar com o Asaas: $error',
      });
    }
  }
}

Future<void> _route(
  HttpRequest request, {
  required String asaasBase,
  required String apiKey,
  required String webhookToken,
  required _PaymentStore store,
}) async {
  final path = request.uri.path;
  if (request.method == 'POST' && path == '/premium/pix') {
    final body = await _readJson(request);
    final userId = (body['userId'] as String? ?? '').trim();
    final name = (body['name'] as String? ?? '').trim();
    final email = (body['email'] as String? ?? '').trim();
    final cpf = (body['cpf'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
    if (userId.isEmpty || name.isEmpty || !email.contains('@')) {
      return _json(request.response, HttpStatus.badRequest, {
        'message': 'Informe nome, e-mail e a conta.',
      });
    }

    final customerId = await _customerId(
      asaasBase: asaasBase,
      apiKey: apiKey,
      userId: userId,
      name: name,
      email: email,
      cpf: cpf,
    );
    final due = DateTime.now();
    final dueDate =
        '${due.year.toString().padLeft(4, '0')}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
    final payment = await _asaas(
      'POST',
      '$asaasBase/payments',
      apiKey,
      {
        'customer': customerId,
        'billingType': 'PIX',
        'value': 39.90,
        'dueDate': dueDate,
        'description': 'TáPago Premium',
        'externalReference': userId,
      },
    );
    final paymentId = payment['id'] as String? ?? '';
    final qr = await _asaas(
      'GET',
      '$asaasBase/payments/$paymentId/pixQrCode',
      apiKey,
      null,
    );
    await store.save(
      _PaymentRecord(
        paymentId: paymentId,
        userId: userId,
        status: payment['status'] as String? ?? 'PENDING',
      ),
    );
    return _json(request.response, HttpStatus.ok, {
      'paymentId': paymentId,
      'payload': qr['payload'] ?? '',
      'encodedImage': qr['encodedImage'] ?? '',
      'status': payment['status'] ?? 'PENDING',
    });
  }

  if (request.method == 'GET' && path.startsWith('/premium/pix/')) {
    final paymentId = path.substring('/premium/pix/'.length);
    final userId = request.uri.queryParameters['userId'] ?? '';
    final known = store.find(paymentId);
    if (known == null || known.userId != userId) {
      return _json(request.response, HttpStatus.notFound, {
        'message': 'Cobrança não encontrada.',
      });
    }
    if (!_paid(known.status)) {
      final remote = await _asaas(
        'GET',
        '$asaasBase/payments/$paymentId',
        apiKey,
        null,
      );
      final status = remote['status'] as String? ?? known.status;
      await store.save(known.copyWith(status: status));
      return _json(request.response, HttpStatus.ok, {'status': status});
    }
    return _json(request.response, HttpStatus.ok, {'status': known.status});
  }

  if (request.method == 'POST' && path == '/webhooks/asaas') {
    if (webhookToken.isNotEmpty &&
        request.headers.value('asaas-access-token') != webhookToken) {
      return _json(request.response, HttpStatus.unauthorized, {
        'message': 'Webhook recusado.',
      });
    }
    final body = await _readJson(request);
    final payment = body['payment'];
    if (payment is Map) {
      final paymentId = payment['id'] as String? ?? '';
      final status = payment['status'] as String? ?? '';
      final known = store.find(paymentId);
      if (known != null && status.isNotEmpty) {
        await store.save(known.copyWith(status: status));
      }
    }
    return _json(request.response, HttpStatus.ok, {'ok': true});
  }

  return _json(request.response, HttpStatus.notFound, {
    'message': 'Rota não encontrada.',
  });
}

bool _paid(String status) {
  switch (status.toUpperCase()) {
    case 'RECEIVED':
    case 'CONFIRMED':
    case 'RECEIVED_IN_CASH':
      return true;
    default:
      return false;
  }
}

Future<String> _customerId({
  required String asaasBase,
  required String apiKey,
  required String userId,
  required String name,
  required String email,
  required String cpf,
}) async {
  final found = await _asaas(
    'GET',
    '$asaasBase/customers?externalReference=${Uri.encodeQueryComponent(userId)}',
    apiKey,
    null,
  );
  final data = found['data'];
  if (data is List && data.isNotEmpty) {
    final first = data.first;
    if (first is Map && first['id'] is String) return first['id'] as String;
  }
  final created = await _asaas(
    'POST',
    '$asaasBase/customers',
    apiKey,
    {
      'name': name,
      'email': email,
      'externalReference': userId,
      if (cpf.length == 11 || cpf.length == 14) 'cpfCnpj': cpf,
    },
  );
  final id = created['id'] as String?;
  if (id == null || id.isEmpty) {
    throw StateError('O Asaas não devolveu o cliente.');
  }
  return id;
}

Future<Map<String, dynamic>> _asaas(
  String method,
  String url,
  String apiKey,
  Map<String, dynamic>? body,
) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, Uri.parse(url));
    request.headers.set('access_token', apiKey);
    request.headers.set('content-type', 'application/json');
    request.headers.set('user-agent', 'Tapago/2.4.0');
    if (body != null) {
      request.add(utf8.encode(jsonEncode(body)));
    }
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
    final map = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode >= 400) {
      throw StateError(_asaasMessage(map));
    }
    return map;
  } finally {
    client.close();
  }
}

String _asaasMessage(Map<String, dynamic> body) {
  final errors = body['errors'];
  if (errors is List && errors.isNotEmpty && errors.first is Map) {
    final description = errors.first['description'];
    if (description is String && description.isNotEmpty) return description;
  }
  return 'O Asaas recusou a cobrança.';
}

void _cors(HttpResponse response) {
  response.headers.set('access-control-allow-origin', '*');
  response.headers.set('access-control-allow-headers', 'content-type');
  response.headers.set('access-control-allow-methods', 'GET, POST, OPTIONS');
}

Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
  final text = await utf8.decodeStream(request);
  if (text.isEmpty) return {};
  final decoded = jsonDecode(text);
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return {};
}

void _json(HttpResponse response, int status, Map<String, dynamic> body) {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  response.close();
}

class _PaymentRecord {
  const _PaymentRecord({
    required this.paymentId,
    required this.userId,
    required this.status,
  });

  final String paymentId;
  final String userId;
  final String status;

  _PaymentRecord copyWith({String? status}) {
    return _PaymentRecord(
      paymentId: paymentId,
      userId: userId,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
        'paymentId': paymentId,
        'userId': userId,
        'status': status,
      };

  factory _PaymentRecord.fromMap(Map<String, dynamic> map) {
    return _PaymentRecord(
      paymentId: map['paymentId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      status: map['status'] as String? ?? 'PENDING',
    );
  }
}

class _PaymentStore {
  _PaymentStore(this.file);

  final File file;
  final Map<String, _PaymentRecord> _items = {};

  Future<void> load() async {
    if (!await file.exists()) return;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) return;
    for (final item in decoded) {
      if (item is Map) {
        final record = _PaymentRecord.fromMap(Map<String, dynamic>.from(item));
        _items[record.paymentId] = record;
      }
    }
  }

  _PaymentRecord? find(String paymentId) => _items[paymentId];

  Future<void> save(_PaymentRecord record) async {
    _items[record.paymentId] = record;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(_items.values.map((item) => item.toMap()).toList()),
    );
  }
}
