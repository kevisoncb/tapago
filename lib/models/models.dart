import '../utils/premium_access.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.nome,
    required this.email,
    required this.isPremium,
    required this.chavePix,
    this.telefone,
    this.whatsappConectado = false,
    this.notificacoesDiarias = true,
    this.acessoBiometrico = false,
    this.banco = '',
    this.agencia = '',
    this.conta = '',
    this.mensagemCobranca = '',
    this.premiumVenceEm,
    this.premiumTransactionId,
    this.aceiteTermosEm,
    this.aceitePrivacidadeEm,
  });

  final String id;
  final String nome;
  final String email;
  final bool isPremium;
  final String chavePix;
  final String? telefone;
  final bool whatsappConectado;
  final bool notificacoesDiarias;
  final bool acessoBiometrico;
  final String banco;
  final String agencia;
  final String conta;
  final String mensagemCobranca;
  final DateTime? premiumVenceEm;
  final String? premiumTransactionId;
  final DateTime? aceiteTermosEm;
  final DateTime? aceitePrivacidadeEm;

  bool get premiumAtivo => premiumIsActive(
        isPremium: isPremium,
        until: premiumVenceEm,
        now: DateTime.now(),
      );

  AppUser copyWith({
    String? id,
    String? nome,
    String? email,
    bool? isPremium,
    String? chavePix,
    String? telefone,
    bool? whatsappConectado,
    bool? notificacoesDiarias,
    bool? acessoBiometrico,
    String? banco,
    String? agencia,
    String? conta,
    String? mensagemCobranca,
    DateTime? premiumVenceEm,
    String? premiumTransactionId,
    DateTime? aceiteTermosEm,
    DateTime? aceitePrivacidadeEm,
  }) {
    return AppUser(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      isPremium: isPremium ?? this.isPremium,
      chavePix: chavePix ?? this.chavePix,
      telefone: telefone ?? this.telefone,
      whatsappConectado: whatsappConectado ?? this.whatsappConectado,
      notificacoesDiarias: notificacoesDiarias ?? this.notificacoesDiarias,
      acessoBiometrico: acessoBiometrico ?? this.acessoBiometrico,
      banco: banco ?? this.banco,
      agencia: agencia ?? this.agencia,
      conta: conta ?? this.conta,
      mensagemCobranca: mensagemCobranca ?? this.mensagemCobranca,
      premiumVenceEm: premiumVenceEm ?? this.premiumVenceEm,
      premiumTransactionId: premiumTransactionId ?? this.premiumTransactionId,
      aceiteTermosEm: aceiteTermosEm ?? this.aceiteTermosEm,
      aceitePrivacidadeEm: aceitePrivacidadeEm ?? this.aceitePrivacidadeEm,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'is_premium': isPremium,
      'chave_pix': chavePix,
      'telefone': telefone,
      'whatsapp_conectado': whatsappConectado,
      'notificacoes_diarias': notificacoesDiarias,
      'acesso_biometrico': acessoBiometrico,
      'banco': banco,
      'agencia': agencia,
      'conta': conta,
      'mensagem_cobranca': mensagemCobranca,
      'premium_vence_em': premiumVenceEm?.toIso8601String(),
      'premium_transaction_id': premiumTransactionId,
      'aceite_termos_em': aceiteTermosEm?.toIso8601String(),
      'aceite_privacidade_em': aceitePrivacidadeEm?.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, {String? id}) {
    return AppUser(
      id: id ?? map['id'] as String? ?? '',
      nome: map['nome'] as String? ?? '',
      email: map['email'] as String? ?? '',
      isPremium: map['is_premium'] as bool? ?? false,
      chavePix: map['chave_pix'] as String? ?? '',
      telefone: map['telefone'] as String?,
      whatsappConectado: map['whatsapp_conectado'] as bool? ?? false,
      notificacoesDiarias: map['notificacoes_diarias'] as bool? ?? true,
      acessoBiometrico: map['acesso_biometrico'] as bool? ?? false,
      banco: map['banco'] as String? ?? '',
      agencia: map['agencia'] as String? ?? '',
      conta: map['conta'] as String? ?? '',
      mensagemCobranca: map['mensagem_cobranca'] as String? ?? '',
      premiumVenceEm: _parseDate(map['premium_vence_em']),
      premiumTransactionId: map['premium_transaction_id'] as String?,
      aceiteTermosEm: _parseDate(map['aceite_termos_em']),
      aceitePrivacidadeEm: _parseDate(map['aceite_privacidade_em']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}

class Debt {
  const Debt({
    required this.id,
    required this.userId,
    required this.nome,
    required this.telefone,
    required this.valorPrincipal,
    required this.taxaJuros,
    required this.dataVencimento,
    required this.statusPago,
    required this.clientScore,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String nome;
  final String telefone;
  final double valorPrincipal;
  final double taxaJuros;
  final DateTime dataVencimento;
  final bool statusPago;
  final int clientScore;
  final DateTime? createdAt;

  double get valorAtualizado =>
      valorPrincipal * (1 + (taxaJuros / 100));

  bool get isOverdue {
    if (statusPago) return false;
    final today = DateTime.now();
    final due = DateTime(
      dataVencimento.year,
      dataVencimento.month,
      dataVencimento.day,
    );
    final start = DateTime(today.year, today.month, today.day);
    return due.isBefore(start);
  }

  bool get isDueThisWeek {
    if (statusPago) return false;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 7));
    final due = DateTime(
      dataVencimento.year,
      dataVencimento.month,
      dataVencimento.day,
    );
    return !due.isBefore(start) && due.isBefore(end);
  }

  int get scoreStars => ((clientScore / 20).round()).clamp(1, 5);

  Debt copyWith({
    String? id,
    String? userId,
    String? nome,
    String? telefone,
    double? valorPrincipal,
    double? taxaJuros,
    DateTime? dataVencimento,
    bool? statusPago,
    int? clientScore,
    DateTime? createdAt,
  }) {
    return Debt(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nome: nome ?? this.nome,
      telefone: telefone ?? this.telefone,
      valorPrincipal: valorPrincipal ?? this.valorPrincipal,
      taxaJuros: taxaJuros ?? this.taxaJuros,
      dataVencimento: dataVencimento ?? this.dataVencimento,
      statusPago: statusPago ?? this.statusPago,
      clientScore: clientScore ?? this.clientScore,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'nome': nome,
      'telefone': telefone,
      'valor_principal': valorPrincipal,
      'taxa_juros': taxaJuros,
      'data_vencimento': dataVencimento.toIso8601String(),
      'status_pago': statusPago,
      'client_score': clientScore,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'nome': nome,
      'telefone': telefone,
      'valor_principal': valorPrincipal,
      'taxa_juros': taxaJuros,
      'data_vencimento': dataVencimento,
      'status_pago': statusPago,
      'client_score': clientScore,
      'created_at': createdAt ?? DateTime.now(),
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map, {String? id}) {
    return Debt(
      id: id ?? map['id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      nome: map['nome'] as String? ?? '',
      telefone: map['telefone'] as String? ?? '',
      valorPrincipal: (map['valor_principal'] as num?)?.toDouble() ?? 0,
      taxaJuros: (map['taxa_juros'] as num?)?.toDouble() ?? 0,
      dataVencimento: _parseDate(map['data_vencimento']) ?? DateTime.now(),
      statusPago: map['status_pago'] as bool? ?? false,
      clientScore: map['client_score'] as int? ?? 80,
      createdAt: _parseDate(map['created_at']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}

class Bill {
  const Bill({
    required this.id,
    required this.userId,
    required this.fornecedor,
    required this.valor,
    required this.dataVencimento,
    this.codigo = '',
    this.pago = false,
    this.pagoEm,
    this.grupoId = '',
    this.parcela = 1,
    this.totalParcelas = 1,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String fornecedor;
  final double valor;
  final DateTime dataVencimento;
  final String codigo;
  final bool pago;
  final DateTime? pagoEm;
  final String grupoId;
  final int parcela;
  final int totalParcelas;
  final DateTime? createdAt;

  bool get parcelado => totalParcelas > 1;

  String get parcelaLabel => 'Parcela $parcela de $totalParcelas';

  bool get isOverdue {
    if (pago) return false;
    final today = DateTime.now();
    final due = DateTime(
      dataVencimento.year,
      dataVencimento.month,
      dataVencimento.day,
    );
    return due.isBefore(DateTime(today.year, today.month, today.day));
  }

  bool get isDueThisWeek {
    if (pago) return false;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final due = DateTime(
      dataVencimento.year,
      dataVencimento.month,
      dataVencimento.day,
    );
    return !due.isBefore(start) &&
        due.isBefore(start.add(const Duration(days: 7)));
  }

  Bill copyWith({
    String? fornecedor,
    double? valor,
    DateTime? dataVencimento,
    String? codigo,
    bool? pago,
    DateTime? pagoEm,
    bool clearPagoEm = false,
  }) {
    return Bill(
      id: id,
      userId: userId,
      fornecedor: fornecedor ?? this.fornecedor,
      valor: valor ?? this.valor,
      dataVencimento: dataVencimento ?? this.dataVencimento,
      codigo: codigo ?? this.codigo,
      pago: pago ?? this.pago,
      pagoEm: clearPagoEm ? null : pagoEm ?? this.pagoEm,
      grupoId: grupoId,
      parcela: parcela,
      totalParcelas: totalParcelas,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'fornecedor': fornecedor,
      'valor': valor,
      'data_vencimento': dataVencimento.toIso8601String(),
      'codigo': codigo,
      'pago': pago,
      'pago_em': pagoEm?.toIso8601String(),
      'grupo_id': grupoId,
      'parcela': parcela,
      'total_parcelas': totalParcelas,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'fornecedor': fornecedor,
      'valor': valor,
      'data_vencimento': dataVencimento,
      'codigo': codigo,
      'pago': pago,
      'pago_em': pagoEm,
      'grupo_id': grupoId,
      'parcela': parcela,
      'total_parcelas': totalParcelas,
      'created_at': createdAt ?? DateTime.now(),
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map, {String? id}) {
    return Bill(
      id: id ?? map['id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      fornecedor: map['fornecedor'] as String? ?? '',
      valor: (map['valor'] as num?)?.toDouble() ?? 0,
      dataVencimento: Debt._parseDate(map['data_vencimento']) ?? DateTime.now(),
      codigo: map['codigo'] as String? ?? '',
      pago: map['pago'] as bool? ?? false,
      pagoEm: Debt._parseDate(map['pago_em']),
      grupoId: map['grupo_id'] as String? ?? '',
      parcela: (map['parcela'] as num?)?.toInt() ?? 1,
      totalParcelas: (map['total_parcelas'] as num?)?.toInt() ?? 1,
      createdAt: Debt._parseDate(map['created_at']),
    );
  }
}

class Payment {
  const Payment({
    required this.id,
    required this.debtId,
    required this.userId,
    required this.valor,
    required this.data,
    this.descricao = 'Pagamento Recebido',
  });

  final String id;
  final String debtId;
  final String userId;
  final double valor;
  final DateTime data;
  final String descricao;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'debt_id': debtId,
      'user_id': userId,
      'valor': valor,
      'data': data.toIso8601String(),
      'descricao': descricao,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'debt_id': debtId,
      'user_id': userId,
      'valor': valor,
      'data': data,
      'descricao': descricao,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map, {String? id}) {
    return Payment(
      id: id ?? map['id'] as String? ?? '',
      debtId: map['debt_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      valor: (map['valor'] as num?)?.toDouble() ?? 0,
      data: Debt._parseDate(map['data']) ?? DateTime.now(),
      descricao: map['descricao'] as String? ?? 'Pagamento Recebido',
    );
  }
}
