import 'dart:convert';

import 'package:app_tontine_bf/core/api/api_client.dart';
import 'package:app_tontine_bf/core/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  test('envoie le jeton et le JSON, puis décode la réponse', () async {
    late http.Request captured;
    final client = ApiClient(
      baseUrl: 'https://api.test/api/v1',
      httpClient: MockClient((request) async {
        captured = request;
        return jsonResponse({
          'data': {'id': 1, 'name': 'Épargne rentrée'},
        });
      }),
    )..token = 'secret';

    final body = await client.post('/orgs', {'name': 'Épargne rentrée'});

    expect(captured.url.toString(), 'https://api.test/api/v1/orgs');
    expect(captured.headers['Authorization'], 'Bearer secret');
    expect(captured.headers['Accept'], 'application/json');
    expect(jsonDecode(captured.body), {'name': 'Épargne rentrée'});
    expect(body['data']['name'], 'Épargne rentrée');
  });

  test('transforme une erreur de validation en messages par champ', () async {
    final client = ApiClient(
      baseUrl: 'https://api.test',
      httpClient: MockClient(
        (_) async => jsonResponse({
          'message': 'Le champ nom est obligatoire.',
          'errors': {
            'name': ['Le champ nom est obligatoire.'],
          },
        }, 422),
      ),
    );

    await expectLater(
      client.post('/orgs', {}),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 422)
            .having((error) => error.fieldError('name'), 'fieldError', 'Le champ nom est obligatoire.'),
      ),
    );
  });

  test('prévient la session et reformule le message quand le jeton est refusé', () async {
    var notified = false;
    final client = ApiClient(
      baseUrl: 'https://api.test',
      httpClient: MockClient((_) async => jsonResponse({'message': 'Unauthenticated.'}, 401)),
    )
      ..token = 'expired'
      ..onUnauthorized = () => notified = true;

    await expectLater(
      client.get('/me'),
      throwsA(isA<ApiException>().having((error) => error.message, 'message', 'Votre session a expiré. Reconnectez-vous.')),
    );
    expect(notified, isTrue);
  });

  test('traduit une coupure réseau en erreur lisible', () async {
    final client = ApiClient(
      baseUrl: 'https://api.test',
      httpClient: MockClient((_) async => throw http.ClientException('hors ligne')),
    );

    await expectLater(
      client.get('/me'),
      throwsA(isA<ApiException>().having((error) => error.isNetworkError, 'isNetworkError', isTrue)),
    );
  });
}
