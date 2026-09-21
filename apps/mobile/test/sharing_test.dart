import 'package:app_tontine_bf/features/cagnottes/cagnotte.dart';
import 'package:app_tontine_bf/features/organizations/organization.dart';
import 'package:app_tontine_bf/features/sharing/sharing.dart';
import 'package:app_tontine_bf/features/tontines/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retrouve le code dans un lien reçu comme dans un code saisi', () {
    expect(shareCodeFrom('https://goaicorp-crm.online/t/ABCD2345'), 'ABCD2345');
    expect(shareCodeFrom('  https://goaicorp-crm.online/i/abcd2345/  '), 'ABCD2345');
    expect(shareCodeFrom('https://goaicorp-crm.online/c/ABCD2345?source=whatsapp'), 'ABCD2345');
    expect(shareCodeFrom('Rejoignez-nous : https://goaicorp-crm.online/o/ABCD2345'), 'ABCD2345');
    expect(shareCodeFrom('ABCD2345'), 'ABCD2345');
    expect(shareCodeFrom('   '), isNull);
  });

  test('lit la fiche publique d’une tontine partagée', () {
    final link = SharedLink.fromJson({
      'type': 'tontine',
      'data': {
        'id': 12,
        'name': 'Tontine du marché',
        'amount': 5000,
        'frequency': 'hebdomadaire',
        'members_count': 6,
        'places_left': 6,
        'started': false,
        'accepts_requests': true,
        'organization': 'Groupement Wend Panga',
        'creator': 'Awa',
      },
    });

    expect(link.type, 'tontine');
    expect(link.title, 'Tontine du marché');
    expect(link.organizationName, 'Groupement Wend Panga');
    expect(link.acceptsRequests, isTrue);
    expect(link.isInvitation, isFalse);
    expect(link.objectId, 12);
  });

  test('lit une invitation, valable ou non', () {
    final invitation = SharedLink.fromJson({
      'type': 'invitation',
      'data': {'code': 'ABCD2345', 'usable': true, 'organization': 'Groupement Wend Panga', 'tontine': 'Tontine du marché'},
    });
    final expired = SharedLink.fromJson({
      'type': 'invitation',
      'data': {'code': 'ABCD2345', 'usable': false, 'organization': 'Groupement Wend Panga'},
    });

    expect(invitation.isInvitation, isTrue);
    expect(invitation.title, 'Tontine du marché');
    expect(invitation.invitationCode, 'ABCD2345');
    expect(invitation.usable, isTrue);
    expect(expired.usable, isFalse);
    expect(expired.title, 'Groupement Wend Panga');
  });

  test('lit la visibilité et le lien des objets renvoyés par l’API', () {
    final tontine = Tontine.fromJson({
      'id': 1,
      'organization_id': 2,
      'name': 'Tontine du marché',
      'type': 'rotative',
      'amount': 5000,
      'frequency': 'hebdomadaire',
      'starts_on': '2026-10-05',
      'status': 'brouillon',
      'visibility': 'publique',
      'join_policy': 'sur_demande',
      'share_url': 'https://goaicorp-crm.online/t/ABCD2345',
    });

    final organization = Organization.fromJson({
      'id': 2,
      'name': 'Groupement Wend Panga',
      'role': 'owner',
      'visibility': 'lien',
      'join_policy': 'fermee',
      'share_url': 'https://goaicorp-crm.online/o/WXYZ6789',
    });

    final cagnotte = Cagnotte.fromJson({
      'id': 3,
      'organization_id': 2,
      'mode': 'gagnants',
      'title': 'Cagnotte Flash',
      'duration': 'flash_24h',
      'status': 'ouverte',
      'min_amount': 250,
      'seconds_left': 3600,
      'ends_at': '2026-09-22T10:00:00+00:00',
      'visibility': 'publique',
      'share_url': 'https://goaicorp-crm.online/c/QRST2345',
    });

    expect(tontine.visibility, ShareVisibility.listed);
    expect(tontine.joinPolicy, JoinPolicy.onRequest);
    expect(tontine.shareUrl, 'https://goaicorp-crm.online/t/ABCD2345');
    expect(organization.visibility, ShareVisibility.link);
    expect(organization.visibility.isShared, isTrue);
    expect(cagnotte.visibility, ShareVisibility.listed);
    expect(cagnotte.shareUrl, 'https://goaicorp-crm.online/c/QRST2345');
  });

  test('reste privé quand l’API ne dit rien', () {
    final tontine = Tontine.fromJson({
      'id': 1,
      'organization_id': 2,
      'name': 'Tontine',
      'type': 'rotative',
      'amount': 1000,
      'frequency': 'hebdomadaire',
      'starts_on': '2026-10-05',
      'status': 'brouillon',
    });

    expect(tontine.visibility, ShareVisibility.members);
    expect(tontine.visibility.isShared, isFalse);
    expect(tontine.shareUrl, isNull);
  });
}
