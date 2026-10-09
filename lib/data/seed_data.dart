import '../models/models.dart';
import '../utils/constants.dart';

class SeedData {
  static AppUser user() {
    return AppUser(
      id: AppConstants.demoUserId,
      nome: 'João Dinâmico',
      email: 'joao.dinamico@email.com',
      isPremium: false,
      chavePix: 'joao.dinamico@email.com',
      notificacoesDiarias: true,
      acessoBiometrico: false,
      banco: 'Banco Inter',
      agencia: '0001',
      conta: '12345-6',
    );
  }

  static List<Debt> debts() {
    const uid = AppConstants.demoUserId;
    return [
      Debt(
        id: 'debt_carlos',
        userId: uid,
        nome: 'Carlos Oliveira',
        telefone: '11987654321',
        valorPrincipal: 450,
        taxaJuros: 8,
        dataVencimento: DateTime(2026, 9, 20),
        statusPago: false,
        clientScore: 80,
      ),
      Debt(
        id: 'debt_mariana',
        userId: uid,
        nome: 'Mariana Souza',
        telefone: '21998877665',
        valorPrincipal: 1200,
        taxaJuros: 5,
        dataVencimento: DateTime(2026, 10, 25),
        statusPago: false,
        clientScore: 60,
      ),
      Debt(
        id: 'debt_roberto',
        userId: uid,
        nome: 'Roberto Silva',
        telefone: '31991234567',
        valorPrincipal: 890,
        taxaJuros: 6,
        dataVencimento: DateTime(2026, 10, 28),
        statusPago: false,
        clientScore: 60,
      ),
      Debt(
        id: 'debt_ana',
        userId: uid,
        nome: 'Ana Beatriz',
        telefone: '11995551234',
        valorPrincipal: 300,
        taxaJuros: 4,
        dataVencimento: DateTime(2026, 11, 2),
        statusPago: false,
        clientScore: 100,
      ),
      Debt(
        id: 'debt_ricardo',
        userId: uid,
        nome: 'Ricardo Carvalho',
        telefone: '11997441222',
        valorPrincipal: 1380.95,
        taxaJuros: 5,
        dataVencimento: DateTime(2026, 10, 6),
        statusPago: false,
        clientScore: 92,
      ),
    ];
  }

  static List<Bill> bills(DateTime today) {
    const uid = AppConstants.demoUserId;
    DateTime day(int offset) =>
        DateTime(today.year, today.month, today.day + offset);
    return [
      for (final (index, offset) in [-1, 29, 59].indexed)
        Bill(
          id: 'bill_silva_${index + 1}',
          userId: uid,
          fornecedor: 'Distribuidora Silva',
          valor: index == 2 ? 333.34 : 333.33,
          dataVencimento: day(offset),
          grupoId: 'grupo_silva',
          parcela: index + 1,
          totalParcelas: 3,
        ),
      Bill(
        id: 'bill_atacadao',
        userId: uid,
        fornecedor: 'Atacadão Bebidas',
        valor: 686.67,
        dataVencimento: day(3),
        codigo: '23793381286000000000300000000400184340000068667',
        grupoId: 'grupo_atacadao',
      ),
      Bill(
        id: 'bill_energia',
        userId: uid,
        fornecedor: 'Conta de luz',
        valor: 212.40,
        dataVencimento: day(-5),
        pago: true,
        pagoEm: day(-6),
        grupoId: 'grupo_energia',
      ),
    ];
  }

  static List<Payment> payments() {
    const uid = AppConstants.demoUserId;
    return [
      Payment(
        id: 'pay_ricardo_1',
        debtId: 'debt_ricardo',
        userId: uid,
        valor: 500,
        data: DateTime(2026, 9, 15),
        descricao: 'Abatimento',
      ),
      Payment(
        id: 'pay_carlos_1',
        debtId: 'debt_carlos',
        userId: uid,
        valor: 150,
        data: DateTime(2026, 8, 2),
        descricao: 'Abatimento',
      ),
    ];
  }
}
