int trustScore({
  required DateTime due,
  required bool paid,
  required double principal,
  required double paidSum,
  required DateTime now,
}) {
  var score = 70;
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  final overdue = dueDay.isBefore(today);

  if (!paid && overdue) score -= 30;
  if (paid && !overdue) score += 20;
  if (paid && overdue) score += 5;

  if (principal > 0 && paidSum > 0) {
    final ratio = (paidSum / principal).clamp(0.0, 1.0);
    score += (ratio * 20).round();
  } else if (!paid && overdue) {
    score -= 10;
  }

  return score.clamp(0, 100);
}
