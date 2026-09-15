import 'package:url_launcher/url_launcher.dart';
import 'package:app_tontine_bf/models/tontine.dart';

class InvitationService {

  // Inviter par numéro de téléphone
  Future<void> inviteByPhone({
    required String phoneNumber,
    required Tontine tontine,
  }) async {
    final message = "Rejoignez ma tontine '${tontine.nom}' sur Tontine BF!\n"
        "Type: ${tontine.typeString}\n"
        "Montant: ${tontine.montantCotisation} FCFA ${tontine.frequencyString}\n"
        "Code: ${tontine.codeInvitation}\n"
        "Lien: ${tontine.generateDeepLink()}";

    final Uri url = Uri.parse("https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Impossible d\'ouvrir WhatsApp');
      }
    } catch (e) {
      throw Exception('Erreur d\'invitation: $e');
    }
  }

  // Partager le lien d'invitation
  Future<void> shareInvitationLink(Tontine tontine) async {
    final message = "Rejoignez ma tontine '${tontine.nom}' sur Tontine BF!\n"
        "Type: ${tontine.typeString}\n"
        "Montant: ${tontine.montantCotisation} FCFA ${tontine.frequencyString}\n"
        "Lien: ${tontine.generateDeepLink()}";

    final Uri url = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(message)}");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback pour autres applications
        final fallbackUrl = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      throw Exception('Erreur de partage: $e');
    }
  }

  // Traiter un lien d'invitation profond
  Map<String, dynamic>? parseDeepLink(Uri deepLink) {
    if (deepLink.host == 'tontinebf.page.link' && deepLink.path == '/invite') {
      final params = deepLink.queryParameters;
      return {
        'code': params['code'],
        'type': params['type'],
        'tontine_id': params['tontine_id'],
      };
    }
    return null;
  }
}