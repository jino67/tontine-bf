/// Lecture tolérante des réponses JSON de l'API.
int asInt(Object? value) => switch (value) {
      int() => value,
      num() => value.toInt(),
      String() => int.tryParse(value) ?? 0,
      _ => 0,
    };

int? asIntOrNull(Object? value) => value == null ? null : asInt(value);

double asDouble(Object? value) => switch (value) {
      num() => value.toDouble(),
      String() => double.tryParse(value) ?? 0,
      _ => 0,
    };

String? asStringOrNull(Object? value) => value is String && value.isNotEmpty ? value : null;

DateTime? asDate(Object? value) => value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

Map<String, dynamic> asMap(Object? value) => value is Map<String, dynamic> ? value : const {};

List<Map<String, dynamic>> asMapList(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];

List<String> asStringList(Object? value) => value is List ? value.map((item) => '$item').toList() : const [];

/// Extrait `data` de l'enveloppe des ressources Laravel.
Object? unwrap(Object? body) => body is Map<String, dynamic> && body.containsKey('data') ? body['data'] : body;
