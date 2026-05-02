// ─── Category Models ──────────────────────────────────────────────────────────
// Matches Laravel CategoryController API response

// ── Parse helpers: API may return numbers as strings ─────────────────────────
double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _parseInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

class MainCategory {
  final int id;
  final String name;
  final String? description;
  final bool status;
  final List<SubCategory> subCategories;

  const MainCategory({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    this.subCategories = const [],
  });

  // Emoji mapping based on category name
  String get emoji {
    final lower = name.toLowerCase();
    if (lower.contains('groom')) return '✂️';
    if (lower.contains('train') || lower.contains('behav')) return '🎾';
    if (lower.contains('vet') || lower.contains('health')) return '🩺';
    if (lower.contains('board') || lower.contains('day care')) return '🏠';
    if (lower.contains('walk')) return '🦮';
    if (lower.contains('sitting') || lower.contains('sit')) return '🏡';
    return '🐾';
  }

  factory MainCategory.fromJson(Map<String, dynamic> json) {
    final subs = (json['sub_categories'] as List<dynamic>? ?? [])
        .map((s) => SubCategory.fromJson(s as Map<String, dynamic>))
        .toList();

    return MainCategory(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] == true ||
          json['status'] == '1' ||
          json['status'] == 1,
      subCategories: subs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'status': status,
    'sub_categories': subCategories.map((s) => s.toJson()).toList(),
  };
}

// ─── Sub Category ─────────────────────────────────────────────────────────────
class SubCategory {
  final int id;
  final int mainCategoryId;
  final String name;
  final String? description;
  final bool status;

  const SubCategory({
    required this.id,
    required this.mainCategoryId,
    required this.name,
    this.description,
    required this.status,
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['id'] as int? ?? 0,
      mainCategoryId:
      int.tryParse(json['main_category_id']?.toString() ?? '0') ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] == true ||
          json['status'] == '1' ||
          json['status'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'main_category_id': mainCategoryId,
    'name': name,
    'description': description,
    'status': status,
  };
}

// ─── Service (from servicesBySubCategory) ────────────────────────────────────
class ServiceModel {
  final int id;
  final String name;
  final String? description;
  final bool status;
  final List<ServiceProvider> providers;

  const ServiceModel({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    this.providers = const [],
  });

  /// Best (lowest discounted) price across all providers, null if no providers
  int? get startingPrice {
    if (providers.isEmpty) return null;
    return providers
        .map((p) => p.discountedPrice.round())
        .reduce((a, b) => a < b ? a : b);
  }

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    final provList = (json['providers'] as List<dynamic>? ?? [])
        .map((p) => ServiceProvider.fromJson(p as Map<String, dynamic>))
        .toList();

    return ServiceModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] == true ||
          json['status'] == '1' ||
          json['status'] == 1,
      providers: provList,
    );
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────
class ServiceProvider {
  final int providerId;
  final String providerName;
  final double price;
  final double discountedPrice;
  final DiscountDetails? discountDetails;
  final String availabilityStatus;
  final List<ProviderSlot> slots;
  final List<ProviderReview> reviews;
  final double? averageRating;

  const ServiceProvider({
    required this.providerId,
    required this.providerName,
    required this.price,
    required this.discountedPrice,
    this.discountDetails,
    required this.availabilityStatus,
    this.slots = const [],
    this.reviews = const [],
    this.averageRating,
  });

  bool get isAvailable => availabilityStatus == 'available';

  List<ProviderSlot> get availableSlots =>
      slots.where((s) => s.isAvailable).toList();

  factory ServiceProvider.fromJson(Map<String, dynamic> json) {
    final slotList = (json['slots'] as List<dynamic>? ?? [])
        .map((s) => ProviderSlot.fromJson(s as Map<String, dynamic>))
        .toList();
    final reviewList = (json['reviews'] as List<dynamic>? ?? [])
        .map((r) => ProviderReview.fromJson(r as Map<String, dynamic>))
        .toList();
    final discount = json['discount_details'] != null
        ? DiscountDetails.fromJson(
        json['discount_details'] as Map<String, dynamic>)
        : null;

    return ServiceProvider(
      providerId: _parseInt(json['provider_id']) ?? 0,
      providerName: json['provider_name'] as String? ?? '',
      price: _parseDouble(json['price']) ?? 0.0,
      discountedPrice: _parseDouble(json['discounted_price']) ?? 0.0,
      discountDetails: discount,
      availabilityStatus: json['availability_status'] as String? ?? '',
      slots: slotList,
      reviews: reviewList,
      averageRating: _parseDouble(json['average_rating']),
    );
  }


}

// ─── Discount Details ────────────────────────────────────────────────────────
class DiscountDetails {
  final String displayName;
  final String discountType; // 'percentage' | 'fixed'
  final double discountValue;

  const DiscountDetails({
    required this.displayName,
    required this.discountType,
    required this.discountValue,
  });

  factory DiscountDetails.fromJson(Map<String, dynamic> json) {
    return DiscountDetails(
      displayName: json['display_name'] as String? ?? '',
      discountType: json['discount_type'] as String? ?? '',
      discountValue: _parseDouble(json['discount_value']) ?? 0.0,
    );
  }

  String get label {
    if (discountType == 'percentage') return '${discountValue.toInt()}% OFF';
    return '₹${discountValue.toInt()} OFF';
  }
}

// ─── Slot ────────────────────────────────────────────────────────────────────
class ProviderSlot {
  final int id;
  final String startTime;
  final String endTime;
  final int maxBookings;
  final int noOfBookings;
  final bool status;

  const ProviderSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.maxBookings,
    required this.noOfBookings,
    required this.status,
  });

  bool get isAvailable => status && noOfBookings < maxBookings;

  String get displayTime => '$startTime - $endTime';

  factory ProviderSlot.fromJson(Map<String, dynamic> json) {
    return ProviderSlot(
      id: _parseInt(json['id']) ?? 0,
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      maxBookings: _parseInt(json['max_bookings']) ?? 0,
      noOfBookings: _parseInt(json['no_of_bookings']) ?? 0,
      status: json['status'] == true ||
          json['status'] == 1 ||
          json['status'] == '1' ||
          json['status'] == 'available',
    );
  }
}

// ─── Review ──────────────────────────────────────────────────────────────────
class ProviderReview {
  final String? userName;
  final double rating;
  final String? review;

  const ProviderReview({
    this.userName,
    required this.rating,
    this.review,
  });

  factory ProviderReview.fromJson(Map<String, dynamic> json) {
    return ProviderReview(
      userName: json['user_name'] as String?,
      rating: _parseDouble(json['rating']) ?? 0.0,
      review: json['review'] as String?,
    );
  }
}

// ─── Sub-category with Services (from servicesBySubCategory endpoint) ─────────
class SubCategoryWithServices {
  final int subCategoryId;
  final String subCategoryName;
  final List<ServiceModel> services;

  const SubCategoryWithServices({
    required this.subCategoryId,
    required this.subCategoryName,
    required this.services,
  });

  factory SubCategoryWithServices.fromJson(Map<String, dynamic> json) {
    final serviceList = (json['services'] as List<dynamic>? ?? [])
        .map((s) => ServiceModel.fromJson(s as Map<String, dynamic>))
        .toList();

    return SubCategoryWithServices(
      subCategoryId: json['sub_category_id'] as int? ?? 0,
      subCategoryName: json['sub_category_name'] as String? ?? '',
      services: serviceList,
    );
  }
}