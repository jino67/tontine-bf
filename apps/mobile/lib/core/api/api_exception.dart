/// Erreur renvoyée par l'API ou par le réseau, avec un message lisible par l'utilisateur.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  factory ApiException.fromResponse(int statusCode, Object? body) {
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};

    final errors = <String, List<String>>{};
    final rawErrors = map['errors'];
    if (rawErrors is Map) {
      rawErrors.forEach((field, messages) {
        if (messages is List && messages.isNotEmpty) {
          errors['$field'] = messages.map((message) => '$message').toList();
        }
      });
    }

    final serverMessage = map['message'];
    final message = serverMessage is String && serverMessage.isNotEmpty && !_isFrameworkDefault(statusCode, serverMessage)
        ? serverMessage
        : _defaultMessage(statusCode);

    return ApiException(message, statusCode: statusCode, fieldErrors: errors);
  }

  final String message;

  /// Nul quand la requête n'a pas atteint le serveur.
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isNetworkError => statusCode == null;

  String? fieldError(String field) => fieldErrors[field]?.first;

  /// La première erreur de champ si elle existe, sinon le message général.
  String get displayMessage => fieldErrors.isNotEmpty ? fieldErrors.values.first.first : message;

  /// Messages génériques de Laravel en anglais, remplacés par une formulation française.
  static bool _isFrameworkDefault(int statusCode, String message) {
    if (statusCode == 401 || statusCode >= 500) return true;
    return message == 'Not Found' || message.startsWith('No query results') || message == 'Too Many Attempts.';
  }

  static String _defaultMessage(int statusCode) => switch (statusCode) {
        401 => 'Votre session a expiré. Reconnectez-vous.',
        403 => "Vous n'avez pas les droits pour cette action.",
        404 => 'Cet élément est introuvable ou a été supprimé.',
        429 => 'Trop de tentatives. Patientez quelques minutes avant de réessayer.',
        >= 500 => 'Le service rencontre un problème. Réessayez dans quelques instants.',
        _ => "L'opération n'a pas abouti.",
      };

  @override
  String toString() => message;
}
