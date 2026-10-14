class CoinEconomyService {
  const CoinEconomyService._();

  static const hintPrice = 25;

  static const spendReasons = <String>{
    'hint_purchase',
    'second_chance_purchase',
    'streak_shield_purchase',
    'cosmetic_purchase',
    'competition_entry',
  };

  static int normalizeBalance(int coins) => coins < 0 ? 0 : coins;

  static bool canAfford({required int balance, required int cost}) {
    if (cost <= 0) return false;
    return normalizeBalance(balance) >= cost;
  }

  static int projectedBalance({required int balance, required int cost}) {
    if (!canAfford(balance: balance, cost: cost)) {
      return normalizeBalance(balance);
    }
    return normalizeBalance(balance) - cost;
  }

  static bool isSpendReason(String reason) => spendReasons.contains(reason);
}
