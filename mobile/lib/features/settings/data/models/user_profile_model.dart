class UserProfileModel {
  final String userId;
  final String displayName;
  final String email;
  final String phoneNumber;
  final String avatarUrl;
  final String preferredLanguage;
  final String registeredCountryId;
  final bool marketingOptIn;
  final int walletBalance;
  final String currencyCode;
  final int loyaltyPoints;
  final String loyaltyTier;

  const UserProfileModel({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.phoneNumber,
    required this.avatarUrl,
    required this.preferredLanguage,
    required this.registeredCountryId,
    required this.marketingOptIn,
    required this.walletBalance,
    required this.currencyCode,
    required this.loyaltyPoints,
    required this.loyaltyTier,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      userId: json['user_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      preferredLanguage: json['preferred_language'] as String? ?? '',
      registeredCountryId: json['registered_country_id'] as String? ?? '',
      marketingOptIn: json['marketing_opt_in'] as bool? ?? false,
      walletBalance: json['wallet_balance'] as int? ?? 0,
      currencyCode: json['currency_code'] as String? ?? '',
      loyaltyPoints: json['loyalty_points'] as int? ?? 0,
      loyaltyTier: json['loyalty_tier'] as String? ?? 'MEMBER',
    );
  }
}

class WalletHistoryModel {
  final String userId;
  final String countryCode;
  final String currencyCode;
  final int balance;
  final List<WalletTransactionModel> transactions;

  const WalletHistoryModel({
    required this.userId,
    required this.countryCode,
    required this.currencyCode,
    required this.balance,
    required this.transactions,
  });

  factory WalletHistoryModel.empty({
    String userId = '',
    String countryCode = '',
    String currencyCode = '',
    int balance = 0,
  }) {
    return WalletHistoryModel(
      userId: userId,
      countryCode: countryCode,
      currencyCode: currencyCode,
      balance: balance,
      transactions: const [],
    );
  }

  factory WalletHistoryModel.fromJson(Map<String, dynamic> json) {
    final transactions = json['transactions'] as List<dynamic>? ?? [];
    return WalletHistoryModel(
      userId: json['user_id'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? '',
      currencyCode: json['currency_code'] as String? ?? '',
      balance: json['balance'] as int? ?? 0,
      transactions: transactions
          .map(
            (item) =>
                WalletTransactionModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class WalletTransactionModel {
  final int id;
  final String transactionType;
  final int amount;
  final int balanceAfter;
  final String currencyCode;
  final String referenceType;
  final String referenceId;
  final String description;
  final String createdAt;

  const WalletTransactionModel({
    required this.id,
    required this.transactionType,
    required this.amount,
    required this.balanceAfter,
    required this.currencyCode,
    required this.referenceType,
    required this.referenceId,
    required this.description,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as int? ?? 0,
      transactionType: json['transaction_type'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      balanceAfter: json['balance_after'] as int? ?? 0,
      currencyCode: json['currency_code'] as String? ?? '',
      referenceType: json['reference_type'] as String? ?? '',
      referenceId: json['reference_id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class LoyaltyHistoryModel {
  final String userId;
  final String countryCode;
  final int points;
  final String tier;
  final List<LoyaltyTransactionModel> transactions;

  const LoyaltyHistoryModel({
    required this.userId,
    required this.countryCode,
    required this.points,
    required this.tier,
    required this.transactions,
  });

  factory LoyaltyHistoryModel.empty({
    String userId = '',
    String countryCode = '',
    int points = 0,
    String tier = 'MEMBER',
  }) {
    return LoyaltyHistoryModel(
      userId: userId,
      countryCode: countryCode,
      points: points,
      tier: tier,
      transactions: const [],
    );
  }

  factory LoyaltyHistoryModel.fromJson(Map<String, dynamic> json) {
    final transactions = json['transactions'] as List<dynamic>? ?? [];
    return LoyaltyHistoryModel(
      userId: json['user_id'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? '',
      points: json['points'] as int? ?? 0,
      tier: json['tier'] as String? ?? 'MEMBER',
      transactions: transactions
          .map(
            (item) =>
                LoyaltyTransactionModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class LoyaltyTransactionModel {
  final int id;
  final String transactionType;
  final int pointsDelta;
  final int balanceAfter;
  final String referenceType;
  final String referenceId;
  final String description;
  final String createdAt;

  const LoyaltyTransactionModel({
    required this.id,
    required this.transactionType,
    required this.pointsDelta,
    required this.balanceAfter,
    required this.referenceType,
    required this.referenceId,
    required this.description,
    required this.createdAt,
  });

  factory LoyaltyTransactionModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransactionModel(
      id: json['id'] as int? ?? 0,
      transactionType: json['transaction_type'] as String? ?? '',
      pointsDelta: json['points_delta'] as int? ?? 0,
      balanceAfter: json['balance_after'] as int? ?? 0,
      referenceType: json['reference_type'] as String? ?? '',
      referenceId: json['reference_id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
