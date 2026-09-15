import 'package:intl/intl.dart';

final _amount = NumberFormat.decimalPattern('fr');

/// 12500 devient « 12 500 FCFA ».
String fcfa(int amount) => '${_amount.format(amount)} FCFA';

String shortDate(DateTime date) => DateFormat('d MMM yyyy', 'fr').format(date);

String dayAndMonth(DateTime date) => DateFormat('EEEE d MMMM', 'fr').format(date);

String dateAndTime(DateTime date) => DateFormat("d MMM yyyy 'à' HH'h'mm", 'fr').format(date.toLocal());

String apiDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// « aujourd'hui », « demain », « dans 5 jours », « il y a 2 jours ».
String relativeDay(DateTime date, {DateTime? now}) {
  final days = _day(date).difference(_day(now ?? DateTime.now())).inDays;
  return switch (days) {
    0 => "aujourd'hui",
    1 => 'demain',
    -1 => 'hier',
    > 1 => 'dans $days jours',
    _ => 'il y a ${-days} jours',
  };
}

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

String capitalize(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// « 1 membre », « 3 membres ». En français, 0 prend le singulier.
String countLabel(int count, String singular, String plural) => '$count ${count > 1 ? plural : singular}';

/// Initiales affichées dans les pastilles de membres.
String initials(String? name) {
  final words = (name ?? '').trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return (words.first.substring(0, 1) + words.last.substring(0, 1)).toUpperCase();
}

/// +22670123456 devient « +226 70 12 34 56 ». Les numéros masqués par l'API sont laissés tels quels.
String phoneDisplay(String phone) {
  final match = RegExp(r'^\+226(\d{2})(\d{2})(\d{2})(\d{2})$').firstMatch(phone);
  if (match == null) return phone;
  return '+226 ${match[1]} ${match[2]} ${match[3]} ${match[4]}';
}

/// Garde les 8 chiffres d'un numéro burkinabè saisi librement, ou null s'il est invalide.
String? normalizeBurkinaPhone(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00226')) digits = digits.substring(5);
  if (digits.startsWith('226') && digits.length == 11) digits = digits.substring(3);
  return digits.length == 8 ? '+226$digits' : null;
}
