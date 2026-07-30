String shortCode(String prefix, String seedId, {DateTime? now}) {
  final d = (now ?? DateTime.now().toUtc());
  const months = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  final dd = d.day.toString().padLeft(2, '0');
  final mmm = months[(d.month - 1).clamp(0, 11)];
  final yy = (d.year % 100).toString().padLeft(2, '0');
  final tail = (seedId).isEmpty
      ? 'XXXX'
      : seedId.length <= 4
          ? seedId.toUpperCase().padRight(4, 'X')
          : seedId.substring(seedId.length - 4).toUpperCase();
  return '$prefix-$dd$mmm$yy-$tail';
}

