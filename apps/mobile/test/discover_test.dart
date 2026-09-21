import 'package:app_tontine_bf/features/discover/join_request.dart';
import 'package:app_tontine_bf/features/sharing/sharing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lit une demande d’adhésion vue par le responsable', () {
    final request = JoinRequestSummary.fromJson({
      'id': 7,
      'status': 'en_attente',
      'message': 'Je cotise chaque semaine au marché.',
      'organization': {'id': 2, 'name': 'Groupement Wend Panga'},
      'tontine': {'id': 4, 'name': 'Tontine du marché'},
      'user': {'id': 9, 'name': 'Binta'},
      'created_at': '2026-09-21T09:00:00+00:00',
    });

    expect(request.isPending, isTrue);
    expect(request.statusLabel, 'En attente');
    expect(request.userName, 'Binta');
    expect(request.target, 'Tontine du marché');
    expect(request.createdAt, isNotNull);
  });

  test('lit une demande refusée avec son motif, et une demande sur l’organisation', () {
    final refusee = JoinRequestSummary.fromJson({
      'id': 8,
      'status': 'refusee',
      'decision_reason': 'Groupe complet',
      'organization': {'id': 2, 'name': 'Groupement Wend Panga'},
      'tontine': null,
    });

    expect(refusee.isPending, isFalse);
    expect(refusee.statusLabel, 'Refusée');
    expect(refusee.decisionReason, 'Groupe complet');
    expect(refusee.target, 'Groupement Wend Panga');
    expect(refusee.tontineName, isNull);
  });

  test('lit ce que le visiteur connecté peut faire sur une fiche', () {
    final membre = SharedLink.fromJson({
      'type': 'tontine',
      'data': {
        'id': 4,
        'name': 'Tontine du marché',
        'accepts_requests': true,
        'viewer': {'is_member': true, 'has_pending_request': false},
      },
    });
    final enAttente = SharedLink.fromJson({
      'type': 'tontine',
      'data': {
        'id': 4,
        'name': 'Tontine du marché',
        'accepts_requests': true,
        'viewer': {'is_member': false, 'has_pending_request': true},
      },
    });
    final visiteur = SharedLink.fromJson({
      'type': 'tontine',
      'data': {'id': 4, 'name': 'Tontine du marché', 'accepts_requests': true},
    });

    expect(membre.isMember, isTrue);
    expect(membre.hasPendingRequest, isFalse);
    expect(enAttente.hasPendingRequest, isTrue);
    expect(enAttente.isMember, isFalse);
    expect(visiteur.isMember, isFalse);
    expect(visiteur.hasPendingRequest, isFalse);
    expect(visiteur.acceptsRequests, isTrue);
  });

  test('garde les motifs de signalement attendus par l’API', () {
    expect(ReportReason.values.map((reason) => reason.apiValue), [
      'arnaque',
      'trompeur',
      'montants_irrealistes',
      'usurpation',
      'autre',
    ]);
    expect(ReportReason.scam.label, 'Tentative d’arnaque');
  });
}
