import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/services/forditva_token_client.dart';
import 'package:forditva/services/token_balance.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _walletId = '0123456789abcdef0123456789abcdef';

Map<String, dynamic> _server({
  int granted = 200,
  int spent = 0,
  int revision = 2,
}) => {
  'wallet_id': _walletId,
  'balance': granted - spent,
  'granted_total': granted,
  'spent_total': spent,
  'revision': revision,
};

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A wallet that registered earlier: 200 granted, nothing spent, last sync
  // [lastSyncMs] (0 = a sync is due).
  Future<TokenBalance> wallet(
    Future<http.Response> Function(http.Request) handler, {
    int lastSyncMs = 0,
  }) async {
    FlutterSecureStorage.setMockInitialValues({
      'forditva_v3_wallet_id': _walletId,
      'forditva_v3_credential': 'A' * 43,
      'forditva_v3_granted_total': '200',
      'forditva_v3_spent_total': '0',
      'forditva_v3_revision': '1',
      'forditva_v3_last_sync_ms': '$lastSyncMs',
    });
    SharedPreferences.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    final balance = TokenBalance.forTest(
      ForditvaTokenClient(
        baseUrl: tokenServerUrl,
        httpClient: MockClient(handler),
        secureStorage: storage,
      ),
      storage,
    );
    await balance.load();
    return balance;
  }

  test('fractional spends reach the server only as whole WIU', () async {
    final sent = <int>[];
    final balance = await wallet((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      sent.add(body['spent_total'] as int);
      return _json(200, _server(spent: body['spent_total'] as int));
    });
    expect(balance.value.value, 200);
    expect(balance.state.value, WalletState.ready);

    await balance.spendFractional(0.6);
    expect(balance.value.value, 200);
    await balance.spendFractional(0.6);
    expect(balance.value.value, 199);
    await balance.spendFractional(2.5);
    expect(balance.value.value, 197); // 3.7 spent, 0.7 waits

    await balance.syncIfDue();
    expect(sent, [3]); // the lifetime total, rounded down
    expect(balance.value.value, 197);
  });

  test('no sync before 8 hours have passed', () async {
    var calls = 0;
    final balance = await wallet((req) async {
      calls++;
      return _json(200, _server());
    }, lastSyncMs: DateTime.now().millisecondsSinceEpoch);
    await balance.syncIfDue();
    expect(calls, 0);
  });

  test('offline sync keeps the local balance', () async {
    final balance = await wallet((req) async {
      throw http.ClientException('offline');
    });
    await balance.spendFractional(5);
    await balance.syncIfDue();
    expect(balance.value.value, 195);
    expect(balance.state.value, WalletState.ready);
  });

  test('a refused credential asks for the recovery code', () async {
    final balance = await wallet(
      (req) async => _json(401, {'detail': 'INVALID_WALLET_CREDENTIALS'}),
    );
    await balance.syncIfDue();
    expect(balance.state.value, WalletState.needsRecovery);
  });

  test('redeem adds the amount with the current total', () async {
    Map<String, dynamic>? sent;
    final balance = await wallet((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return _json(200, {
        'amount': 1000,
        'already_redeemed': false,
        ..._server(granted: 1200, spent: 4, revision: 3),
      });
    });
    await balance.spendFractional(4.2);
    expect(await balance.redeem('a2b3-c4d5'), 1000);
    expect(sent!['code'], 'A2B3C4D5');
    expect(sent!['spent_total'], 4);
    expect(balance.value.value, 1196);
  });

  test('redeem of a code this wallet already used adds nothing', () async {
    final balance = await wallet(
      (req) async => _json(200, {
        'amount': 1000,
        'already_redeemed': true,
        ..._server(granted: 1200),
      }),
    );
    expect(await balance.redeem('A2B3C4D5'), 0);
  });

  group('redeem errors', () {
    Future<WalletError> errorFor(http.Response response) async {
      final balance = await wallet((req) async => response);
      try {
        await balance.redeem('A2B3C4D5');
      } on WalletException catch (e) {
        return e.kind;
      }
      fail('no error');
    }

    test('invalid or used code', () async {
      expect(
        await errorFor(_json(400, {'detail': 'INVALID_OR_USED_CODE'})),
        WalletError.invalidCode,
      );
    });
    test('5 wrong codes lock the wallet for an hour', () async {
      expect(
        await errorFor(_json(429, {'detail': 'CODE_ATTEMPTS_LOCKED'})),
        WalletError.codeLocked,
      );
    });
    test('the proxy limit answers in HTML', () async {
      expect(
        await errorFor(http.Response('<html>429</html>', 429)),
        WalletError.rateLimited,
      );
    });
    test('server down', () async {
      expect(
        await errorFor(http.Response('<html>502</html>', 502)),
        WalletError.unavailable,
      );
    });
  });

  test('code format: client alphabet, spaces and dashes removed', () {
    expect(TokenBalance.isGiftCodeFormat(' a2b3-c4d5 '), isTrue);
    expect(TokenBalance.isGiftCodeFormat('A2B3C4D0'), isFalse); // no 0
    expect(TokenBalance.isGiftCodeFormat('A2B3C4DO'), isFalse); // no O
    expect(TokenBalance.isGiftCodeFormat('A2B3C4D'), isFalse);
    expect(
      TokenBalance.isRecoveryCodeFormat('ABCDE FGHJK LMNPQ RSTUV WXYZ2'),
      isTrue,
    );
  });
}
