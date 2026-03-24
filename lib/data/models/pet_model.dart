class PetModel {
  final String id;
  final String name;
  final String breed;
  final String type;
  final DateTime? birthday;
  final String gender;             // 'Male' | 'Female'
  final String size;               // 'Small' | 'Medium' | 'Large' | 'Extra Large'
  final List<String> personalities; // multi-select from AppConstants.petPersonalities
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

  // ── Derived helpers ────────────────────────────────────────────────────────
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

  /// Returns personality labels joined, e.g. "Playful • Energetic"
  String get personalityDisplay =>
      personalities.isEmpty ? 'No personality set' : personalities.join(' • ');

  // ── copyWith ───────────────────────────────────────────────────────────────
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

  // ── JSON ───────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id':             id,
    'name':           name,
    'breed':          breed,
    'type':           type,
    'birthday':       birthday?.toIso8601String(),
    'gender':         gender,
    'size':           size,
    'personalities':  personalities,
    'photoUrl':       photoUrl,
    'notes':          notes,
  };

  factory PetModel.fromJson(Map<String, dynamic> json) => PetModel(
    id:             json['id']    ?? '',
    name:           json['name']  ?? '',
    breed:          json['breed'] ?? '',
    type:           json['type']  ?? 'Dog',
    birthday:       json['birthday'] != null
        ? DateTime.tryParse(json['birthday'])
        : null,
    gender:         json['gender'] ?? 'Male',
    size:           json['size']   ?? 'Medium',
    personalities:  (json['personalities'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? [],
    photoUrl:       json['photoUrl'],
    notes:          json['notes'],
  );
}
