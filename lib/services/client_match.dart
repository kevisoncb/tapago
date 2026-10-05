import '../models/models.dart';
import '../utils/formatters.dart';

String foldClientName(String value) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const to = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  final buffer = StringBuffer();
  for (final rune in value.trim().toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index == -1 ? char : to[index]);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

bool namesLookTheSame(String a, String b) {
  final left = foldClientName(a);
  final right = foldClientName(b);
  if (left.isEmpty || right.isEmpty) return false;
  return left == right;
}

class ClientHit {
  const ClientHit({
    required this.debt,
    required this.sameName,
    required this.samePhone,
  });

  final Debt debt;
  final bool sameName;
  final bool samePhone;

  bool get confirmed => sameName && samePhone;

  bool get phoneTaken => samePhone && !sameName;

  bool get nameTaken => sameName && !samePhone;
}

List<ClientHit> findClientHits({
  required List<Debt> debts,
  required String nome,
  required String telefone,
  String? ignoreId,
}) {
  final phone = digitsOnly(telefone);
  final name = foldClientName(nome);
  if (name.isEmpty && phone.isEmpty) return const [];

  final hits = <ClientHit>[];
  for (final debt in debts) {
    if (ignoreId != null && debt.id == ignoreId) continue;
    final sameName = name.isNotEmpty && namesLookTheSame(nome, debt.nome);
    final samePhone =
        phone.isNotEmpty && digitsOnly(debt.telefone) == phone;
    if (!sameName && !samePhone) continue;
    hits.add(
      ClientHit(debt: debt, sameName: sameName, samePhone: samePhone),
    );
  }
  hits.sort((a, b) {
    final byRank = _hitRank(a).compareTo(_hitRank(b));
    if (byRank != 0) return byRank;
    return a.debt.nome.toLowerCase().compareTo(b.debt.nome.toLowerCase());
  });
  return hits;
}

int _hitRank(ClientHit hit) {
  if (hit.confirmed) return 0;
  if (hit.phoneTaken) return 1;
  return 2;
}

/// Número de outro cliente, ou a mesma pessoa num cadastro novo.
/// Novo lançamento da mesma gente (allowPhone / allowNome) passa.
ClientHit? firstBlockingHit({
  required List<Debt> debts,
  required String nome,
  required String telefone,
  String? ignoreId,
  String? allowPhone,
  String? allowNome,
}) {
  final hits = findClientHits(
    debts: debts,
    nome: nome,
    telefone: telefone,
    ignoreId: ignoreId,
  );
  final allowedDigits = digitsOnly(allowPhone ?? '');
  for (final hit in hits) {
    if (hit.phoneTaken) return hit;
    if (!hit.confirmed) continue;
    final hitPhone = digitsOnly(hit.debt.telefone);
    final sameAllowedPhone =
        allowedDigits.length >= 10 && hitPhone == allowedDigits;
    final sameAllowedName = allowNome != null &&
        namesLookTheSame(allowNome, hit.debt.nome) &&
        namesLookTheSame(nome, hit.debt.nome);
    if (sameAllowedPhone || (allowedDigits.isEmpty && sameAllowedName)) {
      continue;
    }
    return hit;
  }
  return null;
}

bool cadernetaMatchesQuery(Debt debt, String query) {
  final needle = foldClientName(query);
  if (needle.isEmpty) return true;
  final digits = digitsOnly(query);
  if (digits.length >= 3 && digitsOnly(debt.telefone).contains(digits)) {
    return true;
  }
  return foldClientName(debt.nome).contains(needle);
}

String contactKeyOf(Debt debt) {
  final phone = digitsOnly(debt.telefone);
  if (phone.length >= 10) return 'p:$phone';
  return 'n:${foldClientName(debt.nome)}';
}

class CadernetaContact {
  const CadernetaContact({
    required this.key,
    required this.nome,
    required this.telefone,
    required this.debts,
  });

  final String key;
  final String nome;
  final String telefone;
  final List<Debt> debts;

  int get lancamentos => debts.length;

  double saldoAbertoOf(double Function(Debt debt) saldoOf) {
    return debts.fold(0.0, (sum, debt) => sum + saldoOf(debt));
  }

  bool temAberto(double Function(Debt debt) saldoOf) {
    return debts.any((debt) => !debt.statusPago && saldoOf(debt) > 0.009);
  }

  bool temAtraso(double Function(Debt debt) saldoOf) {
    return debts.any(
      (debt) => debt.isOverdue && !debt.statusPago && saldoOf(debt) > 0.009,
    );
  }
}

List<CadernetaContact> groupContacts(List<Debt> debts) {
  final buckets = <String, List<Debt>>{};
  for (final debt in debts) {
    buckets.putIfAbsent(contactKeyOf(debt), () => []).add(debt);
  }

  final contacts = <CadernetaContact>[];
  for (final entry in buckets.entries) {
    final list = [...entry.value]
      ..sort((a, b) {
        final left = a.createdAt ?? a.dataVencimento;
        final right = b.createdAt ?? b.dataVencimento;
        final byDate = right.compareTo(left);
        if (byDate != 0) return byDate;
        return b.nome.length.compareTo(a.nome.length);
      });
    final display = list.first;
    contacts.add(
      CadernetaContact(
        key: entry.key,
        nome: display.nome,
        telefone: display.telefone,
        debts: list,
      ),
    );
  }
  contacts.sort(
    (a, b) => foldClientName(a.nome).compareTo(foldClientName(b.nome)),
  );
  return contacts;
}

bool contactMatchesQuery(CadernetaContact contact, String query) {
  return contact.debts.any((debt) => cadernetaMatchesQuery(debt, query));
}
