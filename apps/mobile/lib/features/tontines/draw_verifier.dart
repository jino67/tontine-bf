import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';

/// Recalcule le tirage sur le téléphone, avec le même algorithme que le serveur :
/// les parts tirées sont triées par sha256(graine + "|" + part), dans l'ordre croissant,
/// puis placées dans les tours qui n'ont pas été attribués par le responsable.
abstract final class DrawVerifier {
  static String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();

  static List<String> order(String seed, List<String> slots) {
    final hashes = {for (final slot in slots) slot: sha256Hex('$seed|$slot')};
    return [...slots]..sort((a, b) => hashes[a]!.compareTo(hashes[b]!));
  }

  /// Les tours attribués gardent leur part, les autres reçoivent les parts tirées dans l'ordre.
  static List<String> merge(List<DrawDesignation> designations, List<String> drawn, int cyclesCount) {
    final byCycle = {for (final designation in designations) designation.cycle: designation.slot};
    final queue = [...drawn];
    return [
      for (var cycle = 1; cycle <= cyclesCount; cycle++) byCycle[cycle] ?? (queue.isEmpty ? '' : queue.removeAt(0)),
    ];
  }

  static bool seedMatchesHash(Draw draw) => draw.seed != null && sha256Hex(draw.seed!) == draw.seedHash;

  static bool orderMatches(Draw draw) {
    if (draw.seed == null) return false;
    final expected = merge(draw.designations, order(draw.seed!, draw.slots), draw.cyclesCount);
    return listEquals(expected, draw.order);
  }

  static bool verify(Draw draw) => seedMatchesHash(draw) && orderMatches(draw);
}
