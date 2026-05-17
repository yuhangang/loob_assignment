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
