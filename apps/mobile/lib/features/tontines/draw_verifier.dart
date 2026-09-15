import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'models.dart';

/// Recalcule le tirage sur le téléphone, avec le même algorithme que le serveur :
/// les parts sont triées par sha256(graine + "|" + part), dans l'ordre croissant.
abstract final class DrawVerifier {
  static String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();

  static List<String> order(String seed, List<String> slots) {
    final hashes = {for (final slot in slots) slot: sha256Hex('$seed|$slot')};
    return [...slots]..sort((a, b) => hashes[a]!.compareTo(hashes[b]!));
  }

  static bool seedMatchesHash(Draw draw) => draw.seed != null && sha256Hex(draw.seed!) == draw.seedHash;

  static bool orderMatches(Draw draw) {
    if (draw.seed == null) return false;
    final expected = order(draw.seed!, draw.slots);
    if (expected.length != draw.order.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (expected[i] != draw.order[i]) return false;
    }
    return true;
  }

  static bool verify(Draw draw) => seedMatchesHash(draw) && orderMatches(draw);
}
