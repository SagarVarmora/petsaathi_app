class PetModel {
  final String id;
  final String name;
  final String breed;
  final String type;
  final DateTime? birthday;
  final String gender;             // Display value: 'Male' | 'Female'
  final String size;               // Local-only: 'Small' | 'Medium' | 'Large' | 'Extra Large'
  final List<String> personalities; // Maps to API field 'personality'
  final String? photoUrl;
  final String? notes;

  const PetModel({
    required this.id,
    required this.name,
    required this.breed,
    required this.type,
    this.birthday,
    required this.gender,
    required this.size,
    this.personalities = const [],
    this.photoUrl,
    this.notes,
  });

  // ── Derived helpers ─────────────────────────────────────────────────────────
  String get emoji {
    switch (type.toLowerCase()) {
      case 'cat':    return '🐱';
      case 'bird':   return '🐦';
      case 'rabbit': return '🐰';
      case 'fish':   return '🐟';
      default:       return '🐶';
    }
  }

  int? get ageInMonths {
    if (birthday == null) return null;
    final now = DateTime.now();
    return (now.year - birthday!.year) * 12 + (now.month - birthday!.month);
  }

  String get ageDisplay {
    final months = ageInMonths;
    if (months == null) return 'Unknown age';
    if (months < 12) return '$months month${months == 1 ? '' : 's'}';
    final years = months ~/ 12;
    final rem   = months % 12;
    if (rem == 0) return '$years year${years == 1 ? '' : 's'}';
    return '$years yr $rem mo';
  }

  String get personalityDisplay =>
      personalities.isEmpty ? 'No personality set' : personalities.join(' • ');

  // ── copyWith ────────────────────────────────────────────────────────────────
  PetModel copyWith({
    String? id,
    String? name,
    String? breed,
    String? type,
    DateTime? birthday,
    String? gender,
    String? size,
    List<String>? personalities,
    String? photoUrl,
    String? notes,
  }) {
    return PetModel(
      id:            id            ?? this.id,
      name:          name          ?? this.name,
      breed:         breed         ?? this.breed,
      type:          type          ?? this.type,
      birthday:      birthday      ?? this.birthday,
      gender:        gender        ?? this.gender,
      size:          size          ?? this.size,
      personalities: personalities ?? this.personalities,
      photoUrl:      photoUrl      ?? this.photoUrl,
      notes:         notes         ?? this.notes,
    );
  }

  // ── Local JSON (SharedPreferences cache) ─────────────────────────────────────
  // Preserves all fields including 'size' which the server doesn't store.
  Map<String, dynamic> toJson() => {
    'id':             id,
    'name':           name,
    'breed':          breed,
    'type':           type,
    'birthday':       birthday?.toIso8601String(),
    'gender':         gender,          // stored capitalized locally
    'size':           size,
    'personalities':  personalities,
    'photoUrl':       photoUrl,
    'notes':          notes,
  };

  factory PetModel.fromJson(Map<String, dynamic> json) => PetModel(
    // Server returns integer id; local cache stores it as a string.
    id:   json['id']?.toString() ?? '',
    name:  json['name']  ?? '',
    breed: json['breed'] ?? '',
    type:  json['type']  ?? 'Dog',
    birthday: json['birthday'] != null
        ? DateTime.tryParse(json['birthday'].toString())
        : null,
    // Server sends lowercase ('male'/'female'); normalise to title-case for UI.
    gender: _normaliseGender(json['gender']),
    size:   json['size'] ?? 'Medium',
    // Server field is 'personality' (array); local cache uses 'personalities'.
    personalities: _parsePersonalities(json),
    photoUrl: json['photoUrl'] as String?,
    notes:    json['notes']    as String?,
  );

  // ── API payload (POST to server) ─────────────────────────────────────────────
  // Sends only the fields the Laravel controller accepts.
  Map<String, dynamic> toApiJson() => {
    'name':        name,
    'type':        type,
    if (breed.isNotEmpty) 'breed': breed,
    if (birthday != null)
      'birthday':
      '${birthday!.year}-${birthday!.month.toString().padLeft(2, '0')}-${birthday!.day.toString().padLeft(2, '0')}',
    // Server expects lowercase gender
    'gender': gender.toLowerCase(),
    if (personalities.isNotEmpty) 'personality': personalities,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  /// Accepts 'male', 'Male', 'MALE' → returns 'Male'.
  static String _normaliseGender(dynamic raw) {
    if (raw == null) return 'Male';
    final s = raw.toString().trim();
    if (s.isEmpty) return 'Male';
    return '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';
  }

  /// Server key is 'personality'; local cache key is 'personalities'.
  static List<String> _parsePersonalities(Map<String, dynamic> json) {
    final raw = json['personality'] ?? json['personalities'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }
}