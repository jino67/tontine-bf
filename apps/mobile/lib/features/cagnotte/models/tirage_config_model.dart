// lib/features/cagnotte/models/tirage_config_model.dart
class TirageConfig {
  final int id;
  final int cagnotteId;
  final String modeTirage; // 'auto', 'manuel', 'programme', 'hybride'
  final DateTime? dateTirageProgramme;
  final bool notificationsActives;
  final int delaiApresFin;
  final bool selectionAdminActive;
  final Map<int, int> rangsAdminSelectionnes; // {rang: userId}
  final String? raisonInterne; // Note admin discrète

  TirageConfig({
    required this.id,
    required this.cagnotteId,
    required this.modeTirage,
    this.dateTirageProgramme,
    required this.notificationsActives,
    required this.delaiApresFin,
    this.selectionAdminActive = false,
    this.rangsAdminSelectionnes = const {},
    this.raisonInterne,
  });

  factory TirageConfig.fromJson(Map<String, dynamic> json) {
    return TirageConfig(
      id: json['id'] ?? 0,
      cagnotteId: json['cagnotte_id'] ?? 0,
      modeTirage: json['mode_tirage'] ?? 'hybride',
      dateTirageProgramme: json['date_tirage_programme'] != null
          ? DateTime.parse(json['date_tirage_programme'])
          : null,
      notificationsActives: (json['notifications_actives'] ?? 1) == 1,
      delaiApresFin: json['delai_apres_fin'] ?? 24,
      selectionAdminActive: (json['selection_admin_active'] ?? 0) == 1,
      rangsAdminSelectionnes: _parseRangsAdmin(json['rangs_admin']),
      raisonInterne: json['raison_interne'],
    );
  }

  static Map<int, int> _parseRangsAdmin(dynamic data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(int.parse(key.toString()), value as int));
    }
    return {};
  }
}