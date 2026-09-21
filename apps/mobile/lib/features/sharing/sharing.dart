import '../../core/json.dart';

/// Qui peut voir une organisation, une tontine ou une cagnotte.
///
/// Nommé `ShareVisibility` et non `Visibility` : ce dernier est déjà un widget de Flutter.
enum ShareVisibility {
  members('privee', 'Privé', 'Visible des membres seulement.'),
  link('lien', 'Par lien', 'Accessible à qui reçoit le lien, absent de la recherche.'),
  listed('publique', 'Public', 'Visible de tous dans l’application.');

  const ShareVisibility(this.apiValue, this.label, this.description);

  final String apiValue;
  final String label;
  final String description;

  bool get isShared => this != members;

  static ShareVisibility fromApi(Object? value) =>
      values.firstWhere((visibility) => visibility.apiValue == value, orElse: () => members);
}

/// Comment on entre dans une organisation ou une tontine.
enum JoinPolicy {
  closed('fermee', 'Sur invitation'),
  onRequest('sur_demande', 'Sur demande'),
  open('libre', 'Libre');

  const JoinPolicy(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static JoinPolicy fromApi(Object? value) =>
      values.firstWhere((policy) => policy.apiValue == value, orElse: () => closed);
}

/// Fiche publique d'un code partagé, telle que l'API la renvoie.
class SharedLink {
  const SharedLink({required this.type, required this.data});

  factory SharedLink.fromJson(Map<String, dynamic> json) =>
      SharedLink(type: '${json['type'] ?? ''}', data: asMap(json['data']));

  /// tontine, cagnotte, organisation ou invitation.
  final String type;
  final Map<String, dynamic> data;

  bool get isInvitation => type == 'invitation';

  String get title => switch (type) {
        'cagnotte' => '${data['title'] ?? ''}',
        'invitation' => '${data['tontine'] ?? data['organization'] ?? 'Invitation'}',
        _ => '${data['name'] ?? ''}',
      };

  String? get organizationName => asStringOrNull(data['organization']);
  String? get invitationCode => asStringOrNull(data['code']);
  bool get usable => data['usable'] != false;
  bool get acceptsRequests => data['accepts_requests'] == true;
  int? get objectId => asIntOrNull(data['id']);

  /// Renseigné par l'API quand le visiteur est connecté.
  bool get isMember => asMap(data['viewer'])['is_member'] == true;
  bool get hasPendingRequest => asMap(data['viewer'])['has_pending_request'] == true;
}

/// Extrait le code d'un lien collé ou saisi : « https://exemple.bf/t/ABCD2345 » donne « ABCD2345 ».
String? shareCodeFrom(String input) {
  final cleaned = input.trim().split('?').first.split('#').first;
  final match = RegExp(r'([A-Za-z0-9]{6,12})/*$').firstMatch(cleaned);

  return match?.group(1)?.toUpperCase();
}
