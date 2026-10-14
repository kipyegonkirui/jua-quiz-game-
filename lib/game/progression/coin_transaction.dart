enum CoinTransactionKind { credit, debit }

class CoinTransaction {
  final int id;
  final int amount;
  final String reason;
  final String? refId;
  final int balanceAfter;
  final DateTime createdAt;

  const CoinTransaction({
    required this.id,
    required this.amount,
    required this.reason,
    required this.refId,
    required this.balanceAfter,
    required this.createdAt,
  });

  CoinTransactionKind get kind =>
      amount >= 0 ? CoinTransactionKind.credit : CoinTransactionKind.debit;

  factory CoinTransaction.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    final rawAmount = map['amount'];
    final rawBalance = map['balance_after'];
    final rawCreatedAt = map['created_at'];

    return CoinTransaction(
      id: rawId is num ? rawId.toInt() : int.parse(rawId as String),
      amount: rawAmount is num ? rawAmount.toInt() : int.parse(rawAmount as String),
      reason: map['reason'] as String,
      refId: map['ref_id'] as String?,
      balanceAfter:
          rawBalance is num ? rawBalance.toInt() : int.parse(rawBalance as String),
      createdAt: DateTime.parse(rawCreatedAt as String),
    );
  }
}

class CoinSpendResult {
  final int amountSpent;
  final String reason;
  final String? refId;
  final int balance;
  final bool applied;

  const CoinSpendResult({
    required this.amountSpent,
    required this.reason,
    required this.refId,
    required this.balance,
    required this.applied,
  });

  factory CoinSpendResult.fromMap(Map<String, dynamic> map) {
    return CoinSpendResult(
      amountSpent: (map['amount_spent'] as num).toInt(),
      reason: map['reason'] as String,
      refId: map['ref_id'] as String?,
      balance: (map['balance'] as num).toInt(),
      applied: map['applied'] as bool? ?? true,
    );
  }
}
