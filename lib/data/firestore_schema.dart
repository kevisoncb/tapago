/// Schema Firestore do TáPago.
///
/// Coleção `Users` (documentId = uid)
/// - email: string
/// - is_premium: boolean
/// - chave_pix: string
/// - nome: string
/// - notificacoes_diarias: boolean
/// - acesso_biometrico: boolean
/// - banco: string
/// - agencia: string
/// - conta: string
/// - premium_vence_em: timestamp
/// - premium_transaction_id: string
///
/// Coleção `Debts` (documentId = debtId)
/// - user_id: string
/// - nome: string
/// - telefone: string
/// - valor_principal: double
/// - taxa_juros: double
/// - data_vencimento: timestamp
/// - status_pago: boolean
/// - client_score: integer
/// - created_at: timestamp
///
/// Coleção `Payments` (histórico de comprovantes)
/// - debt_id: string
/// - user_id: string
/// - valor: double
/// - data: timestamp
/// - descricao: string
class FirestoreSchema {
  static const users = 'Users';
  static const debts = 'Debts';
  static const payments = 'Payments';
}
