import 'package:app_tontine_bf/core/format.dart';
import 'package:app_tontine_bf/features/tontines/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('formats', () {
    test('normalise les numéros burkinabè', () {
      expect(normalizeBurkinaPhone('70 12 34 56'), '+22670123456');
      expect(normalizeBurkinaPhone('+226 70 12 34 56'), '+22670123456');
      expect(normalizeBurkinaPhone('0022670123456'), '+22670123456');
      expect(normalizeBurkinaPhone('7012345'), isNull);
      expect(phoneDisplay('+22670123456'), '+226 70 12 34 56');
    });

    test('affiche les montants en francs CFA avec séparateur de milliers', () {
      expect(fcfa(12500).replaceAll(RegExp(r'\s'), ' '), '12 500 FCFA');
    });

    test('décrit les jours de façon relative', () {
      final now = DateTime(2026, 9, 15, 10);
      expect(relativeDay(DateTime(2026, 9, 15), now: now), "aujourd'hui");
      expect(relativeDay(DateTime(2026, 9, 16), now: now), 'demain');
      expect(relativeDay(DateTime(2026, 9, 20), now: now), 'dans 5 jours');
      expect(relativeDay(DateTime(2026, 9, 13), now: now), 'il y a 2 jours');
    });

    test('forme les initiales et accorde les pluriels', () {
      expect(initials('Awa Ouédraogo'), 'AO');
      expect(initials(null), '?');
      expect(countLabel(1, 'part', 'parts'), '1 part');
      expect(countLabel(3, 'part', 'parts'), '3 parts');
    });
  });

  group('modèles', () {
    test('lit une tontine telle que renvoyée par l’API', () {
      final tontine = Tontine.fromJson({
        'id': 3,
        'organization_id': 1,
        'name': 'Tontine du marché',
        'type': 'rotative',
        'amount': 5000,
        'frequency': 'hebdomadaire',
        'starts_on': '2026-10-05',
        'cycles_count': 4,
        'max_members': 12,
        'goal': null,
        'status': 'active',
        'members_count': 2,
        'amount_due_total': 60000,
        'amount_paid_total': 15000,
        'next_due_on': '2026-10-12',
        'members': [
          {
            'id': 10,
            'shares': 2,
            'position': 1,
            'user': {'id': 5, 'name': 'Awa Ouédraogo', 'phone': '+22670123456'},
          },
          {
            'id': 11,
            'shares': 1,
            'position': 2,
            'user': {'id': 6, 'name': null, 'phone': '+226 ** ** 34 56'},
          },
        ],
      });

      expect(tontine.type, TontineType.rotative);
      expect(tontine.frequency, Frequency.weekly);
      expect(tontine.status, TontineStatus.active);
      expect(tontine.paidRatio, 0.25);
      expect(tontine.totalShares, 3);
      expect(tontine.potPerCycle, 15000);
      expect(tontine.nextDueOn, DateTime(2026, 10, 12));
      expect(tontine.members.last.displayName, 'Membre sans nom');
    });

    test('lit une cotisation de l’échéancier personnel', () {
      final item = MyContribution.fromJson({
        'id': 7,
        'cycle_id': 2,
        'tontine_member_id': 10,
        'amount_due': 10000,
        'amount_paid': 4000,
        'method': 'orange_money',
        'reference': 'PP250915.1432',
        'paid_at': '2026-10-05T09:00:00+00:00',
        'status': 'enregistree',
        'confirmed_at': null,
        'cycle_number': 1,
        'due_on': '2026-10-05',
        'is_late': true,
        'is_beneficiary': true,
        'tontine': {'id': 3, 'name': 'Tontine du marché', 'type': 'tirage_ordre', 'organization_id': 1},
      });

      expect(item.contribution.status, ContributionStatus.recorded);
      expect(item.contribution.method, PaymentMethod.orangeMoney);
      expect(item.contribution.isFullyPaid, isFalse);
      expect(item.tontineType, TontineType.drawOrder);
      expect(item.isLate && item.isBeneficiary, isTrue);
    });

    test('tolère les champs absents et les valeurs inconnues', () {
      final draw = Draw.fromJson({
        'id': 1,
        'seed_hash': 'abc',
        'slots': ['12#1', '12#2'],
        'reveal_after': '2026-09-16T10:00:00Z',
      });

      expect(draw.isRevealed, isFalse);
      expect(Draw.memberIdOf('12#2'), 12);
      expect(TontineStatus.fromApi('inconnu'), TontineStatus.draft);
      expect(PaymentMethod.fromApi(null), isNull);
    });
  });
}
