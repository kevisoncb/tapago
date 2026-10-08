/// Schema Firestore do Pagô!.
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
/// Coleção `Boletos` (contas da empresa a pagar)
/// - user_id: string
/// - empresa: string
/// - cnpj: string (opcional)
/// - descricao: string (opcional)
/// - valor: double
/// - data_vencimento: timestamp
/// - linha_digitavel: string (opcional)
/// - status_pago: boolean
/// - pago_em: timestamp (opcional)
/// - created_at: timestamp
class FirestoreSchema {
  static const users = 'Users';
  static const debts = 'Debts';
  static const payments = 'Payments';
  static const boletos = 'Boletos';
  static const premiumCharges = 'PremiumCharges';
}
