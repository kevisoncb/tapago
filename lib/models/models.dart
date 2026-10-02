class AppUser {
  const AppUser({
    required this.id,
    required this.nome,
    required this.email,
    required this.isPremium,
    required this.chavePix,
    this.notificacoesDiarias = true,
    this.acessoBiometrico = false,
    this.banco = 'Banco Inter',
    this.agencia = '0001',
    this.conta = '12345-6',
    this.premiumVenceEm,
  });

  final String id;
  final String nome;
  final String email;
  final bool isPremium;
  final String chavePix;
  final bool notificacoesDiarias;
  final bool acessoBiometrico;
  final String banco;
  final String agencia;
  final String conta;
  final DateTime? premiumVenceEm;

  AppUser copyWith({
    String? id,
    String? nome,
    String? email,
    bool? isPremium,
    String? chavePix,
    bool? notificacoesDiarias,
    bool? acessoBiometrico,
    String? banco,
    String? agencia,
    String? conta,
    DateTime? premiumVenceEm,
  }) {
    return AppUser(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      isPremium: isPremium ?? this.isPremium,
      chavePix: chavePix ?? this.chavePix,
      notificacoesDiarias: notificacoesDiarias ?? this.notificacoesDiarias,
      acessoBiometrico: acessoBiometrico ?? this.acessoBiometrico,
      banco: banco ?? this.banco,
      agencia: agencia ?? this.agencia,
      conta: conta ?? this.conta,
      premiumVenceEm: premiumVenceEm ?? this.premiumVenceEm,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'is_premium': isPremium,
      'chave_pix': chavePix,
      'notificacoes_diarias': notificacoesDiarias,
      'acesso_biometrico': acessoBiometrico,
      'banco': banco,
      'agencia': agencia,
      'conta': conta,
      'premium_vence_em': premiumVenceEm?.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, {String? id}) {
    return AppUser(
      id: id ?? map['id'] as String? ?? '',
      nome: map['nome'] as String? ?? '',
      email: map['email'] as String? ?? '',
      isPremium: map['is_premium'] as bool? ?? false,
      chavePix: map['chave_pix'] as String? ?? '',
      notificacoesDiarias: map['notificacoes_diarias'] as bool? ?? true,
      acessoBiometrico: map['acesso_biometrico'] as bool? ?? false,
      banco: map['banco'] as String? ?? '',
      agencia: map['agencia'] as String? ?? '',
      conta: map['conta'] as String? ?? '',
      premiumVenceEm: _parseDate(map['premium_vence_em']),
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
