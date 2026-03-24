enum BookingStatus { upcoming, ongoing, completed, cancelled }

class BookingModel {
  final String id;
  final String serviceId;
  final String serviceTitle;
  final String petId;
  final String petName;
  final DateTime scheduledAt;
  final int price;
  final BookingStatus status;
  final String? notes;
  final String? companionName;

  const BookingModel({
    required this.id,
    required this.serviceId,
    required this.serviceTitle,
    required this.petId,
    required this.petName,
    required this.scheduledAt,
    required this.price,
    required this.status,
    this.notes,
    this.companionName,
  });

  String get statusLabel {
    switch (status) {
      case BookingStatus.upcoming: return 'Upcoming';
      case BookingStatus.ongoing: return 'Ongoing';
      case BookingStatus.completed: return 'Completed';
      case BookingStatus.cancelled: return 'Cancelled';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'serviceId': serviceId,
    'serviceTitle': serviceTitle,
    'petId': petId,
    'petName': petName,
    'scheduledAt': scheduledAt.toIso8601String(),
    'price': price,
    'status': status.name,
    'notes': notes,
    'companionName': companionName,
  };

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
    id: json['id'] ?? '',
    serviceId: json['serviceId'] ?? '',
    serviceTitle: json['serviceTitle'] ?? '',
    petId: json['petId'] ?? '',
    petName: json['petName'] ?? '',
    scheduledAt: DateTime.parse(json['scheduledAt']),
    price: json['price'] ?? 0,
    status: BookingStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => BookingStatus.upcoming,
    ),
    notes: json['notes'],
    companionName: json['companionName'],
  );
}
