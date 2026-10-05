bool premiumIsActive({
  required bool isPremium,
  required DateTime? until,
  required DateTime now,
}) {
  if (!isPremium || until == null) return false;
  return until.isAfter(now);
}
