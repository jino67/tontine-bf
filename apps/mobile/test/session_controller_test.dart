import 'dart:convert';

import 'package:app_tontine_bf/core/api/api_client.dart';
import 'package:app_tontine_bf/core/session/session_controller.dart';
import 'package:app_tontine_bf/core/session/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

SessionController sessionWith(MockClientHandler handler, MemorySessionStore store) =>
    SessionController(api: ApiClient(baseUrl: 'https://api.test', httpClient: MockClient(handler)), store: store);

void main() {
  test('se connecte, retient le jeton et ouvre directement la seule organisation', () async {
    final store = MemorySessionStore();
    final session = sessionWith((request) async {
      return switch (request.url.path) {
        '/auth/otp/verify' => jsonResponse({
            'token': '1|abc',
            'user': {'id': 5, 'phone': '+22670123456', 'name': 'Awa'},
          }),
        '/me' => jsonResponse({
            'data': {'id': 5, 'phone': '+22670123456', 'name': 'Awa'},
          }),
        '/orgs' => jsonResponse({
            'data': [
              {'id': 9, 'name': 'Groupement Wend Panga', 'role': 'tresorier'},
            ],
          }),
        _ => jsonResponse({'message': 'Not Found'}, 404),
      };
    }, store);

    await session.signIn(phone: '+22670123456', code: '123456');

    expect(session.status, SessionStatus.signedIn);
    expect(store.token, '1|abc');
    expect(session.needsProfile, isFalse);
    expect(session.currentOrganization?.id, 9);
    expect(session.currentOrganization?.role.canRecordPayments, isTrue);
  });

  test('oublie un jeton refusé au démarrage', () async {
    final store = MemorySessionStore(token: 'expired');
    final session = sessionWith((_) async => jsonResponse({'message': 'Unauthenticated.'}, 401), store);

    await session.restore();

    expect(session.status, SessionStatus.signedOut);
    expect(store.token, isNull);
  });

  test('garde le jeton quand le serveur est injoignable', () async {
    final store = MemorySessionStore(token: 'valide');
    final session = sessionWith((_) async => throw http.ClientException('hors ligne'), store);

    await session.restore();

    expect(session.status, SessionStatus.unreachable);
    expect(store.token, 'valide');
  });

  test('montre la présentation au premier lancement', () async {
    final session = sessionWith((_) async => jsonResponse({}), MemorySessionStore(onboardingSeen: false));

    await session.restore();

    expect(session.status, SessionStatus.onboarding);
  });
}
