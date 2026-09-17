import 'package:app_tontine_bf/core/format.dart';
import 'package:app_tontine_bf/features/cagnottes/cagnotte.dart';
import 'package:app_tontine_bf/features/cagnottes/prize_draw.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  // Vecteurs calculés par App\Services\CagnottePrizeDraw côté API (PHP).
  const seed = 'graine-de-test';
  const seedHash = '99b4cab3cd90eb6bc08db0c198648101f17db2222bf729eb00d4509ef14494f0';
  const tickets = ['u5#1', 'u5#2', 'u7#1', 'u7#2', 'u7#3', 'u9#1', 'u11#1', 'u11#2'];

  Map<String, dynamic> revealedCagnotte({int secondWinner = 11}) => {
        'id': 4,
        'organization_id': 1,
        'mode': 'gagnants',
        'title': 'Cagnotte Flash',
        'duration': 'flash_24h',
        'min_amount': 250,
        'opens_at': '2026-09-14T10:00:00+00:00',
        'ends_at': '2026-09-15T10:00:00+00:00',
        'seconds_left': 0,
        'status': 'tiree',
        'accepts_contributions': false,
        'collected_amount': 1750,
        'ticket_price': 250,
        'winners_count': 3,
        'fee_percent': 10,
        'tickets_count': 8,
        'prizes': [
          {'rank': 1, 'percent': 50, 'amount': 788},
          {'rank': 2, 'percent': 30, 'amount': 472},
          {'rank': 3, 'percent': 20.0, 'amount': 315},
        ],
        'draw': {
          'seed_hash': seedHash,
          'tickets': tickets,
          'reveal_after': '2026-09-15T11:00:00+00:00',
          'revealed_at': '2026-09-15T12:00:00+00:00',
          'seed': seed,
        },
        'winners': [
          {'id': 1, 'rank': 1, 'user': {'id': 7, 'name': 'Awa', 'phone': '+22670000007'}, 'prize_amount': 788},
          {'id': 2, 'rank': 2, 'user': {'id': secondWinner, 'name': 'Cheick', 'phone': '+22670000011'}, 'prize_amount': 472},
          {'id': 3, 'rank': 3, 'user': {'id': 5, 'name': 'Djénéba', 'phone': '+22670000005'}, 'prize_amount': 315},
        ],
      };

  test('retrouve les gagnants tirés au sort par le serveur', () {
    expect(PrizeDraw.pickWinners(seed, tickets, 3), [
      (rank: 1, userId: 7),
      (rank: 2, userId: 11),
      (rank: 3, userId: 5),
    ]);
    expect(PrizeDraw.pickWinners(seed, tickets, 2), [(rank: 1, userId: 7), (rank: 2, userId: 11)]);
    expect(PrizeDraw.pickWinners(seed, tickets, 6), hasLength(4));
  });

  test('calcule tickets, commission et gains comme le serveur', () {
    expect(PrizeDraw.ticketsFor(1100, 250), 4);
    expect(PrizeDraw.pot(1750, 10), 1575);
    expect(PrizeDraw.prizeAmounts(1575, const [50, 30, 20]), [788, 472, 315]);
    expect(PrizeDraw.prizeAmounts(10001, PrizeDraw.defaultSplit(4)), [4001, 2500, 1500, 2000]);
    expect(PrizeDraw.defaultSplit(5), [40, 25, 15, 10, 10]);
  });

  test('lit une cagnotte à gagnants révélée et vérifie le tirage sur le téléphone', () {
    final cagnotte = Cagnotte.fromJson(revealedCagnotte());

    expect(cagnotte.isPrize, isTrue);
    expect(cagnotte.status, CagnotteStatus.drawn);
    expect(cagnotte.prizes.first.percent, 50.0);
    expect(cagnotte.isLocked, isTrue);
    expect(PrizeDraw.verify(cagnotte), isTrue);
    expect(PrizeDraw.verify(Cagnotte.fromJson(revealedCagnotte(secondWinner: 9))), isFalse);
  });

  test('part des secondes restantes du serveur pour le compte à rebours', () {
    final now = DateTime(2026, 9, 15, 10);
    final cagnotte = Cagnotte.fromJson({
      'id': 5,
      'mode': 'solidaire',
      'duration': 'hebdo_7j',
      'status': 'ouverte',
      'seconds_left': 3600,
      'ends_at': '2026-09-20T10:00:00+00:00',
      'beneficiary': {'type': 'externe', 'user_id': null, 'name': 'Mariam'},
    }, now: now);

    expect(cagnotte.deadline, DateTime(2026, 9, 15, 11));
    expect(cagnotte.beneficiary?.isMember, isFalse);
    expect(cagnotte.isPrize, isFalse);
  });

  test('formate le compte à rebours, les rangs et les pourcentages', () {
    expect(countdownLabel(const Duration(hours: 23, minutes: 5, seconds: 9)), '23:05:09');
    expect(countdownLabel(const Duration(days: 2, hours: 3)), '2 j 3 h');
    expect(countdownLabel(const Duration(seconds: -4)), '00:00:00');
    expect(ordinal(1), '1er');
    expect(ordinal(3), '3e');
    expect(percentLabel(50), '50 %');
    expect(percentLabel(6.6667), '6,67 %');
  });
}
