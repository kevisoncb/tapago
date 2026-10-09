/// Schema Firestore do Pagô.
///
/// Coleção `Users` (documentId = uid)
/// - email: string
/// - is_premium: boolean
/// - chave_pix: string
/// - nome: string
/// - telefone: string (opcional; contato do usuário)
/// - whatsapp_conectado: boolean (opcional; default false)
/// - notificacoes_diarias: boolean
/// - acesso_biometrico: boolean
/// - banco: string
/// - agencia: string
/// - conta: string
/// - mensagem_cobranca: string (opcional; template Premium)
/// - premium_vence_em: timestamp
/// - premium_transaction_id: string
/// - aceite_termos_em: timestamp
/// - aceite_privacidade_em: timestamp
///
/// Coleção `PremiumCharges` (só Admin SDK / Functions)
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
/// Coleção `Payments` (abatimentos na caderneta)
/// - debt_id: string
/// - user_id: string
/// - valor: double
/// - data: timestamp
/// - descricao: string (Juros | Abatimento | Quitação)
///
/// Coleção `Bills` (boletos a pagar, Premium)
/// - user_id: string
/// - fornecedor: string
/// - valor: double
/// - data_vencimento: timestamp
/// - codigo: string (linha digitável, opcional)
/// - pago: boolean
/// - pago_em: timestamp (opcional)
/// - grupo_id: string (mesmo id nas parcelas de um boleto parcelado)
/// - parcela, total_parcelas: integer
/// - created_at: timestamp
///
/// Coleção `Presence` (doc id = uid; só o painel admin lê)
/// - last_seen_at: timestamp (servidor)
/// - plataforma: string (android, iOS, web...)
class FirestoreSchema {
  static const users = 'Users';
  static const debts = 'Debts';
  static const payments = 'Payments';
  static const bills = 'Bills';
  static const premiumCharges = 'PremiumCharges';
  static const presence = 'Presence';
}
