/// Mapped from Go `catalog.Store`.
class StoreModel {
  final int id;
  final int brandId;
  final String countryId;
  final String zoneId;
  final String storeCode;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final bool isActive;
  final String operationalStatus;
  final String statusMessage;

  const StoreModel({
    required this.id,
    required this.brandId,
    required this.countryId,
    required this.zoneId,
    required this.storeCode,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.isActive,
    this.operationalStatus = 'OPEN',
    this.statusMessage = '',
  });

  bool get acceptsOrders => operationalStatus.toUpperCase() == 'OPEN';

  String get displayStatus {
    switch (operationalStatus.toUpperCase()) {
      case 'TEMPORARILY_CLOSED':
        return 'Temporarily closed';
      case 'CLOSED':
        return 'Closed';
      default:
        return 'Open';
    }
  }

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      id: json['id'] as int? ?? 0,
      brandId: json['brand_id'] as int? ?? 0,
      countryId: json['country_id'] as String? ?? '',
      zoneId: json['zone_id'] as String? ?? '',
      storeCode: json['store_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      operationalStatus: json['operational_status'] as String? ?? 'OPEN',
      statusMessage: json['status_message'] as String? ?? '',
    );
  }
}
