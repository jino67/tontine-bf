import 'package:app_tontine_bf/features/tontines/draw_verifier.dart';
import 'package:app_tontine_bf/features/tontines/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Vecteur calculé par App\Services\DrawService côté API (PHP) : le téléphone doit retrouver exactement le même résultat.
  const seed = 'graine-de-test';
  const slots = ['1#1', '1#2', '2#1', '3#1', '4#1'];
  const serverHash = '99b4cab3cd90eb6bc08db0c198648101f17db2222bf729eb00d4509ef14494f0';
  const serverOrder = ['4#1', '3#1', '2#1', '1#2', '1#1'];

  Draw revealedDraw({String revealedSeed = seed, List<String> order = serverOrder}) => Draw(
        id: 1,
        seedHash: serverHash,
        slots: slots,
        revealAfter: DateTime(2026, 9, 15),
        revealedAt: DateTime(2026, 9, 16),
        seed: revealedSeed,
        order: order,
      );

  test('retrouve l’empreinte et l’ordre calculés par le serveur', () {
    expect(DrawVerifier.sha256Hex(seed), serverHash);
    expect(DrawVerifier.order(seed, slots), serverOrder);
  });

  test('valide un tirage conforme', () {
    expect(DrawVerifier.verify(revealedDraw()), isTrue);
  });

  test('refuse une graine qui ne correspond pas à l’empreinte publiée', () {
    expect(DrawVerifier.verify(revealedDraw(revealedSeed: 'autre-graine')), isFalse);
  });

  test('refuse un ordre de passage modifié', () {
    expect(DrawVerifier.verify(revealedDraw(order: const ['1#1', '3#1', '2#1', '1#2', '4#1'])), isFalse);
  });
}
