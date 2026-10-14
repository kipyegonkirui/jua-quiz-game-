import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/game/progression/coin_economy_service.dart';
import 'package:jua_quiz/game/progression/coin_transaction.dart';

void main() {
  test('normalizes negative balances', () {
    expect(CoinEconomyService.normalizeBalance(-10), 0);
  });

  test('checks affordability and projects a spend', () {
    expect(CoinEconomyService.canAfford(balance: 100, cost: 25), isTrue);
    expect(CoinEconomyService.canAfford(balance: 20, cost: 25), isFalse);
    expect(
      CoinEconomyService.projectedBalance(balance: 100, cost: 25),
      75,
    );
  });

  test('rejects invalid spend reasons', () {
    expect(CoinEconomyService.isSpendReason('hint_purchase'), isTrue);
    expect(CoinEconomyService.isSpendReason('admin_grant'), isFalse);
  });

  test('maps a ledger transaction', () {
    final entry = CoinTransaction.fromMap({
      'id': 7,
      'amount': -25,
      'reason': 'hint_purchase',
      'ref_id': '00000000-0000-0000-0000-000000000001',
      'balance_after': 75,
      'created_at': '2026-10-03T00:00:00Z',
    });

    expect(entry.amount, -25);
    expect(entry.kind, CoinTransactionKind.debit);
    expect(entry.balanceAfter, 75);
  });
}
