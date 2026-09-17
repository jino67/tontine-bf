import '../tontines/draw_verifier.dart';
import 'cagnotte.dart';

typedef PrizePick = ({int rank, int userId});

/// Calculs des cagnottes à gagnants, identiques à App\Services\CagnottePrizeDraw côté API.
///
/// Ticket « u12#3 » : 3e ticket du membre 12. Les tickets sont triés par sha256(graine + "|" + ticket),
/// puis les membres sont pris dans l'ordre de leur premier ticket, une seule fois chacun.
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

  static List<PrizePick> pickWinners(String seed, List<String> tickets, int winnersCount) {
    final sorted = [...tickets];
    final hashes = {for (final ticket in sorted) ticket: DrawVerifier.sha256Hex('$seed|$ticket')};
    sorted.sort((a, b) => hashes[a]!.compareTo(hashes[b]!));

    final drawn = <int>[];
    for (final ticket in sorted) {
      final userId = userOf(ticket);
      if (!drawn.contains(userId)) drawn.add(userId);
    }

    return [
      for (var index = 0; index < drawn.length && index < winnersCount; index++) (rank: index + 1, userId: drawn[index]),
    ];
  }

  /// Vrai si la graine correspond à l'empreinte et si les gagnants recalculés ici sont ceux du serveur.
  static bool verify(Cagnotte cagnotte) {
    final draw = cagnotte.draw;
    if (draw == null || !draw.isRevealed) return false;
    if (DrawVerifier.sha256Hex(draw.seed!) != draw.seedHash) return false;

    final expected = pickWinners(draw.seed!, draw.tickets, cagnotte.winnersCount ?? 0);
    final actual = [...cagnotte.winners]..sort((a, b) => a.rank.compareTo(b.rank));
    if (expected.length != actual.length) return false;

    for (var i = 0; i < expected.length; i++) {
      if (expected[i] != (rank: actual[i].rank, userId: actual[i].user?.id ?? 0)) return false;
    }
    return true;
  }
}
