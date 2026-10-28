import '../models/models.dart';
import 'client_match.dart';
import 'collection_follow_up.dart';

class CollectionRoutine {
  const CollectionRoutine({
    required this.contacted,
    required this.withoutContact,
    required this.promisesToReview,
    required this.contactedLast7Days,
  });

  final int contacted;
  final int withoutContact;
  final int promisesToReview;
  final int contactedLast7Days;
}

CollectionRoutine buildCollectionRoutine({
  required List<Debt> debts,
  required double Function(Debt debt) saldoOf,
  required List<CollectionFollowUp> followUps,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final byContact = {for (final item in followUps) item.contactKey: item};
  var contacted = 0;
  var withoutContact = 0;
  var promisesToReview = 0;
  var contactedLast7Days = 0;
  final since = clock.subtract(const Duration(days: 7));
  for (final contact in groupContacts(debts)) {
    final followUp = byContact[contact.key];
    if (followUp?.lastContactedAt != null) {
      contacted++;
      if (!followUp!.lastContactedAt!.isBefore(since)) contactedLast7Days++;
    }
    if (contact.temAtraso(saldoOf) && followUp?.lastContactedAt == null) {
      withoutContact++;
    }
    final timing = followUp?.timingAt(clock);
    if (followUp?.promisedAmount != null &&
        (timing == FollowUpTiming.overdue || timing == FollowUpTiming.today)) {
      promisesToReview++;
    }
  }
  return CollectionRoutine(
    contacted: contacted,
    withoutContact: withoutContact,
    promisesToReview: promisesToReview,
    contactedLast7Days: contactedLast7Days,
  );
}
