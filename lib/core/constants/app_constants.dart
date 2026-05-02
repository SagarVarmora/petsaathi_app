class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'PetSaathi';
  static const String appTagline = "India's most trusted pet care platform";

  // Routes
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeOtp = '/otp';
  static const String routeSetupName = '/setup-name';
  static const String routeHome = '/home';
  static const String routeAddPet = '/add-pet';
  static const String routePetDetail = '/pet-detail';
  static const String routeServiceDetail = '/service-detail';
  static const String routeBooking = '/booking';
  static const String routePayment = '/payment';          // ← ADD THIS
  static const String routeBookingConfirm = '/booking-confirm';
  static const String routeBookings = '/bookings';
  static const String routeProfile = '/profile';
  static const String routeEditProfile = '/edit-profile';
  static const String routeWallet = '/wallet';

  // SharedPreferences Keys
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyUserName = 'user_name';
  static const String keyUserPhone = 'user_phone';
  static const String keyUserId = 'user_id';
  static const String keyAuthToken = 'auth_token';

  // Services
  static const List<Map<String, dynamic>> services = [
    {
      'id': 'dog_walking',
      'title': 'Dog Walking',
      'icon': '🦮',
      'price': 299,
      'unit': 'per walk',
      'badge': 'Trained & Verified Companions',
      'duration': '30 min',
      'description': 'Professional dog walkers for your furry friend. GPS tracked walks with photo updates.',
    },
    {
      'id': 'pet_sitting',
      'title': 'Pet Sitting',
      'icon': '🏠',
      'price': 499,
      'unit': 'per day',
      'badge': 'In-Home Care',
      'duration': '24 hours',
      'description': 'Trusted sitters who care for your pet in your home while you are away.',
    },
    {
      'id': 'grooming',
      'title': 'Grooming',
      'icon': '✂️',
      'price': 799,
      'unit': 'per session',
      'badge': 'Salon Quality',
      'duration': '90 min',
      'description': 'Full grooming session including bath, haircut, nail trim and ear cleaning.',
    },
    {
      'id': 'vet_consult',
      'title': 'Vet Consult',
      'icon': '🩺',
      'price': 399,
      'unit': 'per session',
      'badge': 'Certified Vets',
      'duration': '20 min',
      'description': 'Online and in-person consultations with certified veterinarians.',
    },
    {
      'id': 'training',
      'title': 'Training',
      'icon': '🎾',
      'price': 1299,
      'unit': 'per session',
      'badge': 'Expert Trainers',
      'duration': '60 min',
      'description': 'Obedience and behavioral training by certified pet trainers.',
    },
  ];

  // Pet Sizes
  static const List<String> petSizes = ['Small', 'Medium', 'Large', 'Extra Large'];

  // Pet Types (used for emoji in PetAvatarCard & detail screen)
  static const List<String> petTypes = ['Dog', 'Cat', 'Bird', 'Rabbit', 'Fish', 'Other'];

  // Pet Personalities — multi-select, emoji + label
  static const List<Map<String, String>> petPersonalities = [
    {'emoji': '😊', 'label': 'Friendly'},
    {'emoji': '😎', 'label': 'Calm'},
    {'emoji': '🤩', 'label': 'Playful'},
    {'emoji': '⚡', 'label': 'Energetic'},
    {'emoji': '😴', 'label': 'Lazy'},
    {'emoji': '🥰', 'label': 'Affectionate'},
    {'emoji': '🙈', 'label': 'Shy'},
    {'emoji': '🐾', 'label': 'Obedient'},
    {'emoji': '😤', 'label': 'Stubborn'},
    {'emoji': '🛡️', 'label': 'Protective'},
    {'emoji': '🌿', 'label': 'Independent'},
    {'emoji': '🔍', 'label': 'Curious'},
  ];

  // Popular Breeds
  static const List<String> dogBreeds = [
    'Labrador', 'Golden Retriever', 'German Shepherd', 'Poodle',
    'Bulldog', 'Beagle', 'Husky', 'Cocker Spaniel', 'Shih Tzu',
    'Doberman', 'Rottweiler', 'Pug', 'Dachshund', 'Boxer',
    'Border Collie', 'Maltese', 'Indian Pariah', 'Spitz',
  ];

  static const List<String> catBreeds = [
    'Persian', 'Siamese', 'Bengal', 'Maine Coon', 'Ragdoll',
    'Sphynx', 'British Shorthair', 'Himalayan', 'Indian Shorthair',
  ];
}