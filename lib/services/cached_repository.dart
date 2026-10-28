import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'app_repository.dart';
import 'local_repository.dart';

class CachedRepository implements AppRepository, RepositorySyncStatus {
  CachedRepository({required this.remote, required this.cache});

  final AppRepository remote;
  final AppRepository cache;
  final _cachedResources = <String>{};
  DateTime? _lastSyncedAt;

  @override
  bool get usingCachedData => _cachedResources.isNotEmpty;

  @override
  DateTime? get lastSyncedAt => _lastSyncedAt;

  void _fresh(String resource) {
    _cachedResources.remove(resource);
    _lastSyncedAt = DateTime.now();
  }

  bool _networkFailure(Object error) =>
      error is TimeoutException ||
      error is FirebaseException &&
          const {
            'unavailable',
            'deadline-exceeded',
            'network-request-failed',
          }.contains(error.code);

  Future<void> _cacheWrite(Future<void> Function() write) async {
    try {
      await write();
    } catch (error) {
      // A local cache failure must not turn an acknowledged server operation
      // into an apparent failure that the user may submit again.
      debugPrint('Cache local não atualizado: ${error.runtimeType}');
    }
  }

  @override
  bool get usesFirestore => true;

  @override
  Future<void> init() async {}

  @override
  Future<AppUser> getCurrentUser() async {
    try {
      final user = await remote.getCurrentUser();
      _fresh('user');
      await _cacheWrite(() => cache.saveUser(user));
      return user;
    } catch (error) {
      if (!_networkFailure(error)) rethrow;
      _cachedResources.add('user');
      return cache.getCurrentUser();
    }
  }

  @override
  Stream<AppUser>? watchCurrentUser() =>
      remote.watchCurrentUser()?.asyncMap((user) async {
        _fresh('user');
        await _cacheWrite(() => cache.saveUser(user));
        return user;
      });

  @override
  Future<void> saveUser(AppUser user) async {
    await remote.saveUser(user);
    await _cacheWrite(() => cache.saveUser(user));
  }

  @override
  Future<List<Debt>> getDebts() async {
    try {
      final debts = await remote.getDebts();
      _fresh('debts');
      final local = cache;
      if (local is LocalRepository) {
        await _cacheWrite(() => local.replaceDebts(debts));
      }
      return debts;
    } catch (error) {
      if (!_networkFailure(error)) rethrow;
      _cachedResources.add('debts');
      return cache.getDebts();
    }
  }

  @override
  Future<void> upsertDebt(Debt debt) async {
    await remote.upsertDebt(debt);
    await _cacheWrite(() => cache.upsertDebt(debt));
  }

  @override
  Future<void> upsertDebts(List<Debt> debts) async {
    await remote.upsertDebts(debts);
    await _cacheWrite(() => cache.upsertDebts(debts));
  }

  @override
  Future<void> deleteDebt(String id) async {
    await remote.deleteDebt(id);
    await _cacheWrite(() => cache.deleteDebt(id));
  }

  @override
  Future<List<Payment>> getPayments({String? debtId}) async {
    try {
      final payments = await remote.getPayments(debtId: debtId);
      _fresh('payments');
      final local = cache;
      if (debtId == null && local is LocalRepository) {
        await _cacheWrite(() => local.replacePayments(payments));
      }
      return payments;
    } catch (error) {
      if (!_networkFailure(error)) rethrow;
      _cachedResources.add('payments');
      return cache.getPayments(debtId: debtId);
    }
  }

  @override
  Future<void> addPayment(Payment payment) async {
    await recordPayment(payment);
  }

  @override
  Future<void> recordPayment(Payment payment) async {
    await remote.recordPayment(payment);
    await _refreshFinancialCache();
  }

  @override
  Future<void> reversePayment(
    String paymentId, {
    required String reason,
  }) async {
    await remote.reversePayment(paymentId, reason: reason);
    await _refreshFinancialCache();
  }

  Future<void> _refreshFinancialCache() async {
    try {
      final debts = await remote.getDebts();
      final payments = await remote.getPayments();
      final local = cache;
      if (local is LocalRepository) {
        await _cacheWrite(() => local.replaceDebts(debts));
        await _cacheWrite(() => local.replacePayments(payments));
      }
      _fresh('debts');
      _fresh('payments');
    } catch (error) {
      _cachedResources.addAll({'debts', 'payments'});
      debugPrint(
        'Pagamento confirmado; atualização do cache pendente: ${error.runtimeType}',
      );
    }
  }

  @override
  Future<List<Bill>> getBills() async {
    try {
      final bills = await remote.getBills();
      _fresh('bills');
      final local = cache;
      if (local is LocalRepository) {
        await _cacheWrite(() => local.replaceBills(bills));
      }
      return bills;
    } catch (error) {
      if (!_networkFailure(error)) rethrow;
      _cachedResources.add('bills');
      return cache.getBills();
    }
  }

  @override
  Future<void> upsertBill(Bill bill) async {
    await remote.upsertBill(bill);
    await _cacheWrite(() => cache.upsertBill(bill));
  }

  @override
  Future<void> upsertBills(List<Bill> bills) async {
    await remote.upsertBills(bills);
    await _cacheWrite(() => cache.upsertBills(bills));
  }

  @override
  Future<void> deleteBill(String id) async {
    await remote.deleteBill(id);
    await _cacheWrite(() => cache.deleteBill(id));
  }
}
