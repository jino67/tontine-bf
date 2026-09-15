import '../tontines/draw_verifier.dart';
import 'cagnotte.dart';

typedef PrizePick = ({int rank, int userId, bool designated});

/// Calculs des cagnottes à gagnants, identiques à App\Services\CagnottePrizeDraw côté API.
///
/// Ticket « u12#3 » : 3e ticket du membre 12. Les tickets des membres qui ont déjà un rang attribué
/// sont écartés, les autres sont triés par sha256(graine + "|" + ticket). Les membres sont pris dans
/// l'ordre de leur premier ticket, une seule fois chacun, pour les rangs non attribués.
abstract final class PrizeDraw {
  static List<double> defaultSplit(int winners) => switch (winners) {
        <= 1 => [100],
        2 => [60, 40],
        3 => [50, 30, 20],
        _ => [40, 25, 15, ...List.filled(winners - 3, (20 / (winners - 3) * 10000).round() / 10000)],
      };

  static int pot(int collected, int feePercent) => collected - (collected * feePercent) ~/ 100;

  /// Montants entiers par rang. Les francs perdus dans les arrondis vont au 1er rang.
  static List<int> prizeAmounts(int pot, List<double> split) {
    final amounts = [for (final percent in split) (pot * percent / 100).floor()];
    if (amounts.isNotEmpty) amounts[0] += pot - amounts.fold(0, (sum, amount) => sum + amount);
    return amounts;
  }

  static int ticketsFor(int amount, int? ticketPrice) => ticketPrice == null || ticketPrice <= 0 ? 0 : amount ~/ ticketPrice;

  static int userOf(String ticket) => int.tryParse(ticket.split('#').first.substring(1)) ?? 0;

  static List<PrizePick> pickWinners(String seed, List<String> tickets, Map<int, int> designations, int winnersCount) {
    final designatedUsers = designations.values.toSet();
    final eligible = tickets.where((ticket) => !designatedUsers.contains(userOf(ticket))).toList();
    final hashes = {for (final ticket in eligible) ticket: DrawVerifier.sha256Hex('$seed|$ticket')};
    eligible.sort((a, b) => hashes[a]!.compareTo(hashes[b]!));

    final drawn = <int>[];
    for (final ticket in eligible) {
      final userId = userOf(ticket);
      if (!drawn.contains(userId)) drawn.add(userId);
    }

    return [
      for (var rank = 1; rank <= winnersCount; rank++)
        if (designations[rank] != null)
          (rank: rank, userId: designations[rank]!, designated: true)
        else if (drawn.isNotEmpty)
          (rank: rank, userId: drawn.removeAt(0), designated: false),
    ];
  }

  /// Vrai si la graine correspond à l'empreinte et si les gagnants recalculés ici sont ceux du serveur.
  static bool verify(Cagnotte cagnotte) {
    final draw = cagnotte.draw;
    if (draw == null || !draw.isRevealed) return false;
    if (DrawVerifier.sha256Hex(draw.seed!) != draw.seedHash) return false;

    final expected = pickWinners(draw.seed!, draw.tickets, cagnotte.designations, cagnotte.winnersCount ?? 0);
    final actual = [...cagnotte.winners]..sort((a, b) => a.rank.compareTo(b.rank));
    if (expected.length != actual.length) return false;

    for (var i = 0; i < expected.length; i++) {
      final winner = actual[i];
      if (expected[i] != (rank: winner.rank, userId: winner.user?.id ?? 0, designated: winner.designated)) return false;
    }
    return true;
  }
}
