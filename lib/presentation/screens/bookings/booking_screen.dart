import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/category_model.dart';
import '../../../data/repositories/pet_repository.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../widgets/common/common_widgets.dart';

const String _kPlacesApiKey = '';

// ─── Step Index Constants ──────────────────────────────────────────────────
const int _kStepPet = 0;
const int _kStepService = 1;
const int _kStepProvider = 2;
const int _kStepDateTime = 3;
const int _kStepAddress = 4;

class BookingScreen extends StatefulWidget {
  final String serviceId;
  const BookingScreen({super.key, required this.serviceId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with SingleTickerProviderStateMixin {
  // ── Meta ──────────────────────────────────────────────────────────────────
  String _subCategoryName = '';
  String _categoryName = '';
  String _categoryEmoji = '🐾';

  // ── Selections ─────────────────────────────────────────────────────────────
  String? _selectedPetId;
  ServiceModel? _selectedService;
  ServiceProvider? _selectedProvider;
  ProviderSlot? _selectedSlot;
  DateTime? _selectedDate;
  TimeOfDay? _manualTime;
  bool _useManualTime = false;

  // ── Address ─────────────────────────────────────────────────────────────
  final _addressController = TextEditingController();
  final _addressFocusNode = FocusNode();
  List<Map<String, dynamic>> _placeSuggestions = [];
  Timer? _debounceTimer;
  bool _isSearchingPlaces = false;
  bool _showSuggestions = false;
  bool _isGettingLocation = false;

  final _notesController = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _isLoadingServices = true;
  SubCategoryWithServices? _subCategoryData;
  String? _servicesError;

  // ── Accordion: which step is currently expanded ───────────────────────────
  int _expandedStep = _kStepPet;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Step progress (0-based index of first incomplete step) ────────────────
  int get _currentStep {
    if (_selectedPetId == null) return _kStepPet;
    if (_selectedService == null) return _kStepService;
    if (_selectedProvider == null) return _kStepProvider;
    if (_selectedDate == null) return _kStepDateTime;
    if (_selectedSlot == null && !(_useManualTime && _manualTime != null)) {
      return _kStepDateTime;
    }
    return _kStepAddress;
  }

  bool get _isStepCompleted_Pet => _selectedPetId != null;
  bool get _isStepCompleted_Service => _selectedService != null;
  bool get _isStepCompleted_Provider => _selectedProvider != null;
  bool get _isStepCompleted_DateTime =>
      _selectedDate != null &&
          (_selectedSlot != null || (_useManualTime && _manualTime != null));
  bool get _isStepCompleted_Address =>
      _addressController.text.trim().isNotEmpty;

  bool get _canBook =>
      _isStepCompleted_Pet &&
          _isStepCompleted_Service &&
          _isStepCompleted_Provider &&
          _isStepCompleted_DateTime &&
          _isStepCompleted_Address;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _addressFocusNode.addListener(() {
      if (!_addressFocusNode.hasFocus) setState(() => _showSuggestions = false);
    });
    _addressController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadServices());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      _subCategoryName = extra['subCategoryName'] as String? ?? '';
      _categoryName = extra['categoryName'] as String? ?? '';
      _categoryEmoji = extra['categoryEmoji'] as String? ?? '🐾';
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _addressFocusNode.dispose();
    _notesController.dispose();
    _fadeController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ── Helper: expand next incomplete step automatically ─────────────────────
  void _advanceTo(int step) {
    setState(() => _expandedStep = step);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadServices() async {
    final subCatId = int.tryParse(widget.serviceId);
    if (subCatId == null) {
      setState(() {
        _isLoadingServices = false;
        _servicesError = 'Invalid sub-category.';
      });
      return;
    }
    setState(() {
      _isLoadingServices = true;
      _servicesError = null;
    });
    final result = await context
        .read<CategoryRepository>()
        .fetchServicesBySubCategory(subCatId);
    if (!mounted) return;
    setState(() {
      _isLoadingServices = false;
      if (result.isSuccess) {
        _subCategoryData = result.data;
        if (_subCategoryData!.services.length == 1) {
          _selectedService = _subCategoryData!.services.first;
        }
        _fadeController.forward();
      } else {
        _servicesError = result.error;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PICKERS
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedSlot = null;
        _manualTime = null;
        _useManualTime = false;
      });
    }
  }

  Future<void> _pickManualTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _manualTime ?? const TimeOfDay(hour: 10, minute: 0),
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            onSurface: AppTheme.textPrimary,
            surface: Colors.white,
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: Colors.white,
            hourMinuteShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            dayPeriodShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            dayPeriodColor: MaterialStateColor.resolveWith((s) =>
            s.contains(MaterialState.selected) ? AppTheme.primary : AppTheme.primarySurface),
            dayPeriodTextColor: MaterialStateColor.resolveWith((s) =>
            s.contains(MaterialState.selected) ? Colors.white : AppTheme.primary),
            hourMinuteColor: MaterialStateColor.resolveWith((s) =>
            s.contains(MaterialState.selected) ? AppTheme.primary : AppTheme.primarySurface),
            hourMinuteTextColor: MaterialStateColor.resolveWith((s) =>
            s.contains(MaterialState.selected) ? Colors.white : AppTheme.primary),
            dialBackgroundColor: AppTheme.primarySurface,
            dialHandColor: AppTheme.primary,
            dialTextColor: MaterialStateColor.resolveWith((s) =>
            s.contains(MaterialState.selected) ? Colors.white : AppTheme.textPrimary),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _manualTime = picked;
        _selectedSlot = null;
        _useManualTime = true;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GOOGLE PLACES
  // ─────────────────────────────────────────────────────────────────────────
  void _onAddressChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _placeSuggestions = [];
        _showSuggestions = false;
        _isSearchingPlaces = false;
      });
      return;
    }
    setState(() => _isSearchingPlaces = true);
    _debounceTimer = Timer(const Duration(milliseconds: 450), () {
      _fetchPlaceSuggestions(query.trim());
    });
  }

  Future<void> _fetchPlaceSuggestions(String query) async {
    if (_kPlacesApiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      setState(() => _isSearchingPlaces = false);
      return;
    }
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
            '?input=${Uri.encodeComponent(query)}'
            '&key=$_kPlacesApiKey'
            '&components=country:in'
            '&language=en'
            '&location=22.9734,78.6569'
            '&radius=5000000',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final predictions = data['predictions'] as List<dynamic>? ?? [];
        setState(() {
          _placeSuggestions = predictions
              .map((p) => {
            'place_id': p['place_id'] ?? '',
            'description': p['description'] ?? '',
            'main_text': (p['structured_formatting']?['main_text'] as String?) ?? '',
            'secondary_text':
            (p['structured_formatting']?['secondary_text'] as String?) ?? '',
          })
              .toList();
          _showSuggestions = _placeSuggestions.isNotEmpty;
          _isSearchingPlaces = false;
        });
      } else {
        setState(() => _isSearchingPlaces = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingPlaces = false);
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> place) async {
    final placeId = place['place_id'] as String? ?? '';
    final fallback = place['description'] as String? ?? '';
    _addressFocusNode.unfocus();
    setState(() {
      _placeSuggestions = [];
      _showSuggestions = false;
      _addressController.text =
      place['main_text'].isNotEmpty ? place['main_text'] as String : fallback;
      _isSearchingPlaces = true;
    });
    if (_kPlacesApiKey == 'YOUR_GOOGLE_PLACES_API_KEY' || placeId.isEmpty) {
      setState(() {
        _addressController.text = fallback;
        _isSearchingPlaces = false;
      });
      return;
    }
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
            '?place_id=${Uri.encodeComponent(placeId)}'
            '&fields=formatted_address,name,geometry'
            '&key=$_kPlacesApiKey'
            '&language=en',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['result'] as Map<String, dynamic>?;
        if (result != null) {
          final name = result['name'] as String? ?? '';
          final formatted = result['formatted_address'] as String? ?? fallback;
          final full =
          (name.isNotEmpty && !formatted.startsWith(name)) ? '$name, $formatted' : formatted;
          setState(() {
            _addressController.text = full;
            _isSearchingPlaces = false;
          });
        } else {
          setState(() {
            _addressController.text = fallback;
            _isSearchingPlaces = false;
          });
        }
      } else {
        setState(() {
          _addressController.text = fallback;
          _isSearchingPlaces = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _addressController.text = fallback;
          _isSearchingPlaces = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _isGettingLocation = false);
          _showSnack('Location services are disabled. Please enable GPS.');
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() => _isGettingLocation = false);
            _showSnack('Location permission denied.');
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _isGettingLocation = false);
          _showLocationPermissionDialog();
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted) return;
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
            '?latlng=${position.latitude},${position.longitude}'
            '&key=$_kPlacesApiKey'
            '&language=en',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        if (results.isNotEmpty) {
          String? address;
          for (final r in results) {
            final types = (r['types'] as List?)?.cast<String>() ?? [];
            if (types.contains('route') ||
                types.contains('sublocality') ||
                types.contains('premise') ||
                types.contains('street_address')) {
              address = r['formatted_address'] as String?;
              break;
            }
          }
          address ??= results[0]['formatted_address'] as String? ?? '';
          setState(() {
            _addressController.text = address!;
            _isGettingLocation = false;
          });
        } else {
          setState(() => _isGettingLocation = false);
          _showSnack('Could not find your address.');
        }
      } else {
        setState(() => _isGettingLocation = false);
        _showSnack('Failed to fetch address. Please try again.');
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _isGettingLocation = false);
        _showSnack('Location timed out. Please try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isGettingLocation = false);
        _showSnack('Could not get location. Please enter manually.');
      }
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.location_off_rounded, color: AppTheme.error, size: 40),
        title: const Text('Location Permission Required',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text(
          'Location permission is permanently denied.\n\nPlease go to Settings → App → Permissions → Location.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, minimumSize: const Size(120, 44)),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOOKING
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _book() async {
    if (!_canBook) {
      if (_selectedPetId == null) return _showSnack('Please select a pet');
      if (_selectedService == null) return _showSnack('Please select a service');
      if (_selectedProvider == null) return _showSnack('Please select a provider');
      if (_selectedDate == null) return _showSnack('Please select a date');
      if (_selectedSlot == null && !(_useManualTime && _manualTime != null)) {
        return _showSnack('Please select or pick a time');
      }
      return _showSnack('Please enter the service address');
    }

    setState(() => _isLoading = true);
    final petRepo = context.read<PetRepository>();
    final bookingRepo = context.read<BookingRepository>();
    final pet = petRepo.getPetById(_selectedPetId!);
    final d = _selectedDate!;
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    String? startTime, endTime;
    int? slotId;
    if (_selectedSlot != null) {
      startTime = _selectedSlot!.startTime;
      endTime = _selectedSlot!.endTime;
      slotId = _selectedSlot!.id;
    } else if (_manualTime != null) {
      final h = _manualTime!.hour.toString().padLeft(2, '0');
      final m = _manualTime!.minute.toString().padLeft(2, '0');
      startTime = '$h:$m:00';
      final endHour = (_manualTime!.hour + 1) % 24;
      endTime = '${endHour.toString().padLeft(2, '0')}:$m:00';
    }

    final result = await bookingRepo.createBooking(
      providerId: _selectedProvider!.providerId,
      serviceId: _selectedService!.id,
      petId: int.tryParse(_selectedPetId!) ?? 0,
      bookingDate: dateStr,
      bookingAddress: _addressController.text.trim(),
      bookingSlotId: slotId,
      bookingStartTime: startTime,
      bookingEndTime: endTime,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result.isSuccess) {
      String slotDisplay = _selectedSlot != null
          ? _selectedSlot!.displayTime
          : '${_manualTime!.format(context)} (Custom)';

      context.pushReplacement(AppConstants.routePayment, extra: {
        'bookingId': result.bookingId,
        'otp': result.otp,
        'serviceName': _subCategoryName.isNotEmpty ? _subCategoryName : _selectedService!.name,
        'serviceEmoji': _categoryEmoji,
        'petName': pet?.name ?? '',
        'providerName': _selectedProvider!.providerName,
        'bookingDate': dateStr,
        'slotTime': slotDisplay,
        'totalAmount': result.totalAmount ?? _selectedProvider!.price,
        'discountedAmount': result.discountedAmount ?? 0.0,
        'finalAmount': result.finalAmount ?? _selectedProvider!.discountedPrice,
      });
    } else {
      _showSnack(result.error ?? 'Booking failed. Please try again.');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1A2E),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  IconData _serviceIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('groom')) return Icons.content_cut_rounded;
    if (n.contains('bath')) return Icons.shower_rounded;
    if (n.contains('vaccin') || n.contains('check')) return Icons.vaccines_rounded;
    if (n.contains('walk')) return Icons.directions_walk_rounded;
    if (n.contains('train')) return Icons.school_rounded;
    if (n.contains('board') || n.contains('stay')) return Icons.home_rounded;
    if (n.contains('vet') || n.contains('doctor')) return Icons.local_hospital_rounded;
    if (n.contains('dental')) return Icons.medical_services_rounded;
    return Icons.pets_rounded;
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _estimatedEndTime() {
    if (_manualTime == null) return '';
    final endHour = (_manualTime!.hour + 1) % 24;
    final h = endHour > 12 ? endHour - 12 : (endHour == 0 ? 12 : endHour);
    final m = _manualTime!.minute.toString().padLeft(2, '0');
    final period = endHour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period (~1hr)';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final pets = context.watch<PetRepository>().pets;
    final title = _subCategoryName.isNotEmpty ? _subCategoryName : 'Book Service';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: _isLoadingServices
          ? _buildLoader()
          : _servicesError != null
          ? _buildError()
          : _buildMain(pets, title),
    );
  }

  // ── Loader ────────────────────────────────────────────────────────────────
  Widget _buildLoader() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar('Loading...'),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
            SizedBox(height: 16),
            Text('Loading services...',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar('Error'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('😕', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_servicesError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Try Again', onPressed: _loadServices),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(String title) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1A1A2E)),
        onPressed: () => context.pop(),
      ),
      title: Text(title,
          style: const TextStyle(
              color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 17)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFEEEFF4)),
      ),
    );
  }

  // ── Main ──────────────────────────────────────────────────────────────────
  Widget _buildMain(List pets, String title) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: _buildAppBar(title),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    _buildHeroHeader(),
                    _buildStepProgress(),
                    const SizedBox(height: 10),

                    // ── Accordion Steps ─────────────────────────────────────
                    _buildAccordionStep(
                      stepIndex: _kStepPet,
                      title: 'Select Your Pet',
                      icon: Icons.pets_rounded,
                      isCompleted: _isStepCompleted_Pet,
                      preview: _selectedPetId != null
                          ? _buildPetPreviewChip(pets)
                          : null,
                      body: _buildPetBody(pets),
                    ),

                    _buildAccordionStep(
                      stepIndex: _kStepService,
                      title: 'Select Service',
                      icon: Icons.room_service_rounded,
                      isCompleted: _isStepCompleted_Service,
                      isLocked: !_isStepCompleted_Pet,
                      preview: _selectedService != null
                          ? Text(_selectedService!.name,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600))
                          : null,
                      body: _buildServiceBody(),
                    ),

                    _buildAccordionStep(
                      stepIndex: _kStepProvider,
                      title: 'Choose Provider',
                      icon: Icons.person_rounded,
                      isCompleted: _isStepCompleted_Provider,
                      isLocked: !_isStepCompleted_Service,
                      preview: _selectedProvider != null
                          ? Text(_selectedProvider!.providerName,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600))
                          : null,
                      body: _buildProviderBody(),
                    ),

                    _buildAccordionStep(
                      stepIndex: _kStepDateTime,
                      title: 'Pick Date & Time',
                      icon: Icons.calendar_month_rounded,
                      isCompleted: _isStepCompleted_DateTime,
                      isLocked: !_isStepCompleted_Provider,
                      preview: _isStepCompleted_DateTime
                          ? Text(
                          '${_formatDate(_selectedDate!)}  •  ${_selectedSlot?.displayTime ?? _manualTime?.format(context) ?? ''}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600))
                          : null,
                      body: _buildDateTimeBody(),
                    ),

                    _buildAccordionStep(
                      stepIndex: _kStepAddress,
                      title: 'Service Address',
                      icon: Icons.location_on_rounded,
                      isCompleted: _isStepCompleted_Address,
                      isLocked: !_isStepCompleted_DateTime,
                      preview: _isStepCompleted_Address
                          ? Text(
                          _addressController.text.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600))
                          : null,
                      body: _buildAddressBody(),
                    ),

                    // ── Notes ────────────────────────────────────────────────
                    _buildNotesSection(),

                    // ── Price Summary ────────────────────────────────────────
                    if (_selectedProvider != null) _buildPriceSummary(),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Sticky Book Button ────────────────────────────────────────
            _buildStickyBookButton(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACCORDION STEP WIDGET
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAccordionStep({
    required int stepIndex,
    required String title,
    required IconData icon,
    required bool isCompleted,
    bool isLocked = false,
    Widget? preview,
    required Widget body,
  }) {
    final isExpanded = _expandedStep == stepIndex && !isLocked;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? AppTheme.primary
              : isCompleted
              ? AppTheme.primary.withOpacity(0.25)
              : const Color(0xFFEEEFF4),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isExpanded ? 0.06 : 0.03),
            blurRadius: isExpanded ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header (always visible) ────────────────────────────────────
          GestureDetector(
            onTap: isLocked ? null : () => _advanceTo(isExpanded ? -1 : stepIndex),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  // Step number / check circle
                  _StepCircle(
                    number: stepIndex + 1,
                    isCompleted: isCompleted,
                    isActive: isExpanded,
                    isLocked: isLocked,
                  ),
                  const SizedBox(width: 12),
                  // Title + preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isLocked ? const Color(0xFFBBBBBB) : const Color(0xFF1A1A2E),
                          ),
                        ),
                        if (!isExpanded && preview != null) ...[
                          const SizedBox(height: 2),
                          preview,
                        ],
                        if (isLocked)
                          const Text('Complete previous step first',
                              style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
                      ],
                    ),
                  ),
                  // Done badge or chevron
                  if (isCompleted && !isExpanded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Done ✓',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                    )
                  else if (!isLocked)
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF9CA3AF), size: 22),
                    ),
                ],
              ),
            ),
          ),

          // ── Body (expanded only) ──────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(height: 1, color: const Color(0xFFEEEFF4)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: body,
                ),
              ],
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP BODY BUILDERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPetPreviewChip(List pets) {
    try {
      final pet = pets.firstWhere((p) => p.id == _selectedPetId);
      return Row(
        children: [
          Text(pet.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text('${pet.name} · ${pet.breed}',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }


  Widget _buildPetBody(List pets) {
    if (pets.isEmpty) {
      return _EmptyBanner(
        icon: '🐾',
        message: 'No pets added yet. Add a pet first to book a service.',
      );
    }
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: pets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _PetCard(
          name: pets[i].name,
          breed: pets[i].breed,
          emoji: pets[i].emoji,
          isSelected: _selectedPetId == pets[i].id,
          onTap: () {
            setState(() => _selectedPetId = pets[i].id);
            _advanceTo(_kStepService);
          },
        ),
      ),
    );
  }

  Widget _buildServiceBody() {
    final services = _subCategoryData?.services ?? [];
    if (services.isEmpty) return const SizedBox.shrink();
    return Column(
      children: services
          .map((svc) => _ServiceCard(
        service: svc,
        icon: _serviceIcon(svc.name),
        isSelected: _selectedService?.id == svc.id,
        onTap: () {
          setState(() {
            _selectedService = svc;
            _selectedProvider = null;
            _selectedSlot = null;
            _manualTime = null;
            _useManualTime = false;
          });
          _advanceTo(_kStepProvider);
        },
      ))
          .toList(),
    );
  }

  Widget _buildProviderBody() {
    if (_selectedService == null) return const SizedBox.shrink();
    final providers = _selectedService!.providers;
    if (providers.isEmpty) {
      return _EmptyBanner(
        icon: '🔍',
        message: 'No providers available for this service right now.',
      );
    }
    return Column(
      children: providers
          .map((prov) => _ProviderCard2(
        provider: prov,
        isSelected: _selectedProvider?.providerId == prov.providerId,
        onTap: prov.isAvailable
            ? () {
          setState(() {
            _selectedProvider = prov;
            _selectedSlot = null;
            _manualTime = null;
            _useManualTime = false;
          });
          _advanceTo(_kStepDateTime);
        }
            : null,
      ))
          .toList(),
    );
  }

  Widget _buildDateTimeBody() {
    final hasSlots = _selectedProvider?.slots.isNotEmpty ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date picker tile
        GestureDetector(
          onTap: _pickDate,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _selectedDate != null ? AppTheme.primarySurface : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedDate != null ? AppTheme.primary : const Color(0xFFE5E7EB),
                width: _selectedDate != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _selectedDate != null ? AppTheme.primary : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_month_rounded,
                      color: _selectedDate != null ? Colors.white : const Color(0xFF9CA3AF),
                      size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedDate != null ? 'Date Selected' : 'Choose a Date',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _selectedDate != null ? AppTheme.primary : const Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _selectedDate != null ? _formatDate(_selectedDate!) : 'Tap to select',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedDate != null
                                ? const Color(0xFF1A1A2E)
                                : const Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: _selectedDate != null ? AppTheme.primary : const Color(0xFF9CA3AF),
                    size: 20),
              ],
            ),
          ),
        ),

        if (_selectedDate != null) ...[
          const SizedBox(height: 16),

          // Time mode toggle
          Row(
            children: [
              const Text('Time',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TimeToggleTab(
                        label: 'Slots',
                        icon: Icons.grid_view_rounded,
                        selected: !_useManualTime,
                        onTap: () => setState(() {
                          _useManualTime = false;
                          _manualTime = null;
                        })),
                    _TimeToggleTab(
                        label: 'Clock',
                        icon: Icons.access_time_rounded,
                        selected: _useManualTime,
                        onTap: () => setState(() {
                          _useManualTime = true;
                          _selectedSlot = null;
                        })),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (!_useManualTime) ...[
            if (!hasSlots)
              _NoSlotsCard(onUseClock: () {
                setState(() {
                  _useManualTime = true;
                  _selectedSlot = null;
                });
                _pickManualTime();
              })
            else
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: _selectedProvider!.slots.map((slot) {
                  final available = slot.isAvailable;
                  final selected = _selectedSlot?.id == slot.id;
                  return GestureDetector(
                    onTap: available
                        ? () => setState(() {
                      _selectedSlot = slot;
                      _manualTime = null;
                    })
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary
                            : available
                            ? Colors.white
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : available
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFFE5E7EB),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 12,
                              color: selected
                                  ? Colors.white
                                  : available
                                  ? const Color(0xFF6B7280)
                                  : const Color(0xFFD1D5DB)),
                          const SizedBox(height: 2),
                          Text(slot.displayTime,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : available
                                      ? const Color(0xFF1A1A2E)
                                      : const Color(0xFFD1D5DB))),
                          if (!available)
                            Text('Full',
                                style: TextStyle(
                                    fontSize: 9, color: Colors.red.shade300, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ] else
            _buildClockPickerUI(),
        ],
      ],
    );
  }

  Widget _buildClockPickerUI() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickManualTime,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _manualTime != null ? AppTheme.primarySurface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _manualTime != null ? AppTheme.primary : const Color(0xFFE5E7EB),
                width: _manualTime != null ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _manualTime != null ? AppTheme.primary : const Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.schedule_rounded,
                      color: _manualTime != null ? Colors.white : const Color(0xFF9CA3AF),
                      size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _manualTime != null ? 'Time Selected' : 'Pick Your Time',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _manualTime != null ? AppTheme.primary : const Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _manualTime != null ? _manualTime!.format(context) : 'Tap to open clock',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _manualTime != null ? AppTheme.primary : const Color(0xFF9CA3AF),
                            letterSpacing: 0.5),
                      ),
                      if (_manualTime != null)
                        Text('Est. end: ${_estimatedEndTime()}',
                            style: TextStyle(
                                fontSize: 10, color: AppTheme.primary.withOpacity(0.7))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _manualTime != null ? AppTheme.primary : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _manualTime != null ? 'Change' : 'Open',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _manualTime != null ? Colors.white : const Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Custom time is subject to provider availability. Provider will confirm via WhatsApp.',
                  style: TextStyle(fontSize: 10, color: AppTheme.primary.withOpacity(0.8), height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressBody() {
    return Column(
      children: [
        TextField(
          controller: _addressController,
          focusNode: _addressFocusNode,
          maxLines: _showSuggestions ? 1 : 3,
          onTap: () {
            if (_addressController.text.trim().length >= 3) {
              setState(() => _showSuggestions = _placeSuggestions.isNotEmpty);
            }
          },
          onChanged: (val) {
            setState(() {});
            _onAddressChanged(val);
          },
          style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E), height: 1.5),
          decoration: InputDecoration(
            hintText: 'Search or type your address...',
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            prefixIcon: const Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 18),
            suffixIcon: _addressController.text.isNotEmpty
                ? GestureDetector(
                onTap: () => setState(() {
                  _addressController.clear();
                  _placeSuggestions = [];
                  _showSuggestions = false;
                }),
                child: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF), size: 16))
                : _isSearchingPlaces
                ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)))
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
          ),
        ),
        if (_showSuggestions && _placeSuggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: List.generate(_placeSuggestions.length, (i) {
                final place = _placeSuggestions[i];
                final isLast = i == _placeSuggestions.length - 1;
                final mainText = place['main_text'] as String? ?? '';
                final secondaryText = place['secondary_text'] as String? ?? '';
                final description = place['description'] as String? ?? '';
                return InkWell(
                  onTap: () => _selectPlace(place),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(i == 0 ? 12 : 0),
                    topRight: Radius.circular(i == 0 ? 12 : 0),
                    bottomLeft: Radius.circular(isLast ? 12 : 0),
                    bottomRight: Radius.circular(isLast ? 12 : 0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.place_rounded, color: AppTheme.primary, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(mainText.isNotEmpty ? mainText : description,
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              if (secondaryText.isNotEmpty)
                                Text(secondaryText,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const Icon(Icons.north_west_rounded, color: Color(0xFF9CA3AF), size: 13),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Powered by Google', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ),
        ],
        if (!_showSuggestions && _addressController.text.isEmpty) ...[
          const SizedBox(height: 8),
          // GestureDetector(
          //   onTap: _getCurrentLocation,
          //   child: Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          //     decoration: BoxDecoration(
          //       color: AppTheme.primarySurface,
          //       borderRadius: BorderRadius.circular(9),
          //       border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          //     ),
          //     child: Row(
          //       mainAxisSize: MainAxisSize.min,
          //       children: [
          //         if (_isGettingLocation)
          //           const SizedBox(
          //               width: 14,
          //               height: 14,
          //               child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
          //         else
          //           const Icon(Icons.my_location_rounded, color: AppTheme.primary, size: 15),
          //         const SizedBox(width: 7),
          //         // Text(
          //         //   _isGettingLocation ? 'Detecting...' : 'Use my current location',
          //         //   style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
          //         // ),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ],
    );
  }

  Widget _buildNotesSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEFF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.notes_rounded, size: 15, color: Color(0xFF6B7280)),
              ),
              const SizedBox(width: 10),
              const Text('Special Instructions',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                child: const Text('Optional',
                    style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E), height: 1.5),
            decoration: InputDecoration(
              hintText: 'e.g., My dog gets nervous around strangers...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary() {
    final prov = _selectedProvider!;
    final hasDiscount = prov.discountDetails != null;
    final savings = prov.price - prov.discountedPrice;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEFF4)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 7),
                const Text('Price Summary',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                if (hasDiscount) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_offer_rounded, size: 11, color: Color(0xFF16A34A)),
                        const SizedBox(width: 3),
                        Text(prov.discountDetails!.label,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _PriceRow(
                    label: _selectedService?.name ?? 'Service Price',
                    value: '₹${prov.price.toInt()}',
                    isStrikethrough: hasDiscount,
                    valueColor: hasDiscount ? const Color(0xFF9CA3AF) : const Color(0xFF1A1A2E)),
                if (hasDiscount) ...[
                  const SizedBox(height: 7),
                  _PriceRow(
                      label: 'Discount',
                      value: '- ₹${savings.toInt()}',
                      valueColor: const Color(0xFF16A34A),
                      labelColor: const Color(0xFF16A34A)),
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Color(0xFFE5E7EB))),
                ] else
                  const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Payable',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                          color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(10)),
                      child: Text('₹${prov.discountedPrice.toInt()}',
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero & Progress (compact) ─────────────────────────────────────────────
  Widget _buildHeroHeader() {
    final services = _subCategoryData?.services ?? [];
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF4CAF82), Color(0xFF2E7D5E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(_categoryEmoji, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_subCategoryName.isNotEmpty ? _subCategoryName : 'Services',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 2),
                Text(_categoryName,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Text('${services.length} service${services.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgress() {
    const labels = ['Pet', 'Service', 'Provider', 'Schedule', 'Address'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEFF4)),
      ),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < _currentStep;
            return Expanded(
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                    color: isCompleted ? AppTheme.primary : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(1)),
              ),
            );
          }
          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex < _currentStep;
          final isActive = stepIndex == _currentStep;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppTheme.primary
                      : isActive
                      ? AppTheme.primarySurface
                      : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                  border: isActive ? Border.all(color: AppTheme.primary, width: 2) : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                      : Text('${stepIndex + 1}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isActive ? AppTheme.primary : const Color(0xFF9CA3AF))),
                ),
              ),
              const SizedBox(height: 3),
              Text(labels[stepIndex],
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: isActive || isCompleted ? FontWeight.w700 : FontWeight.w400,
                      color: isCompleted
                          ? AppTheme.primary
                          : isActive
                          ? const Color(0xFF1A1A2E)
                          : const Color(0xFF9CA3AF))),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStickyBookButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: (!_isLoading && _canBook) ? _book : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 54,
            decoration: BoxDecoration(
              gradient: _canBook
                  ? const LinearGradient(colors: [Color(0xFF4CAF82), Color(0xFF2E7D5E)])
                  : null,
              color: _canBook ? null : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(14),
              boxShadow: _canBook
                  ? [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5))]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                else ...[
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _selectedProvider != null
                        ? 'Confirm Booking  •  ₹${_selectedProvider!.discountedPrice.toInt()}'
                        : 'Confirm Booking',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _canBook ? Colors.white : const Color(0xFF9CA3AF),
                        letterSpacing: 0.2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP CIRCLE WIDGET
// ═══════════════════════════════════════════════════════════════════════════════
class _StepCircle extends StatelessWidget {
  final int number;
  final bool isCompleted;
  final bool isActive;
  final bool isLocked;

  const _StepCircle({
    required this.number,
    required this.isCompleted,
    required this.isActive,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isCompleted
            ? AppTheme.primary
            : isActive
            ? AppTheme.primarySurface
            : isLocked
            ? const Color(0xFFF0F0F0)
            : const Color(0xFFF3F4F6),
        shape: BoxShape.circle,
        border: isActive ? Border.all(color: AppTheme.primary, width: 2) : null,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : Text('$number',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? AppTheme.primary
                    : isLocked
                    ? const Color(0xFFD0D0D0)
                    : const Color(0xFF9CA3AF))),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NO SLOTS CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _NoSlotsCard extends StatelessWidget {
  final VoidCallback onUseClock;
  const _NoSlotsCard({required this.onUseClock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle),
                  child: const Icon(Icons.event_busy_rounded, color: Colors.orange, size: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No pre-set slots',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
                    Text('Use Clock to pick your time',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onUseClock,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('Pick Time with Clock',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TIME TOGGLE TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _TimeToggleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TimeToggleTab({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(7)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? Colors.white : const Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : const Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PET CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _PetCard extends StatelessWidget {
  final String name;
  final String breed;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _PetCard({super.key, required this.name, required this.breed, required this.emoji, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySurface : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppTheme.primary : const Color(0xFFE5E7EB), width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: AppTheme.primary.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))] : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withOpacity(0.12) : const Color(0xFFEEEFF4),
                      shape: BoxShape.circle),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                ),
                if (isSelected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                          color: AppTheme.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                      child: const Icon(Icons.check_rounded, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? AppTheme.primary : const Color(0xFF1A1A2E))),
            Text(breed,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _ServiceCard extends StatelessWidget {
  final ServiceModel service;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServiceCard({required this.service, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySurface : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.primary : const Color(0xFFE5E7EB), width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : const Color(0xFFEEEFF4), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: isSelected ? Colors.white : const Color(0xFF6B7280), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppTheme.primary : const Color(0xFF1A1A2E))),
                  if (service.startingPrice != null)
                    Text('From ₹${service.startingPrice}',
                        style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? AppTheme.primary : const Color(0xFF6B7280),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isSelected ? null : Border.all(color: const Color(0xFFD1D5DB), width: 1.5)),
              child: isSelected ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDER CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _ProviderCard2 extends StatelessWidget {
  final ServiceProvider provider;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ProviderCard2({required this.provider, required this.isSelected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasDiscount = provider.discountDetails != null;
    final isUnavailable = !provider.isAvailable;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySurface : isUnavailable ? const Color(0xFFF9FAFB) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.primary : const Color(0xFFE5E7EB), width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: AppTheme.primary.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))] : [],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: isSelected ? const LinearGradient(colors: [Color(0xFF4CAF82), Color(0xFF2E7D5E)]) : null,
                    color: isSelected ? null : const Color(0xFFEEEFF4),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      provider.providerName.isNotEmpty ? provider.providerName[0].toUpperCase() : 'P',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : const Color(0xFF6B7280)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(provider.providerName,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isUnavailable ? const Color(0xFF9CA3AF) : const Color(0xFF1A1A2E))),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (provider.averageRating != null) ...[
                            const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 12),
                            const SizedBox(width: 2),
                            Text('${provider.averageRating!.toStringAsFixed(1)} (${provider.reviews.length})',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
                            const SizedBox(width: 6),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: isUnavailable ? Colors.red.shade50 : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(isUnavailable ? 'Unavailable' : 'Available',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isUnavailable ? Colors.red.shade600 : Colors.green.shade700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${provider.discountedPrice.toInt()}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                    if (hasDiscount)
                      Text('₹${provider.price.toInt()}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), decoration: TextDecoration.lineThrough)),
                  ],
                ),
              ],
            ),
            if (hasDiscount) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.green.shade50, borderRadius: BorderRadius.circular(7), border: Border.all(color: Colors.green.shade100)),
                child: Row(
                  children: [
                    Icon(Icons.local_offer_rounded, color: Colors.green.shade600, size: 12),
                    const SizedBox(width: 5),
                    Text('${provider.discountDetails!.displayName} • ${provider.discountDetails!.label}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRICE ROW
// ═══════════════════════════════════════════════════════════════════════════════
class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? labelColor;
  final Color? valueColor;
  final bool isStrikethrough;

  const _PriceRow({required this.label, required this.value, this.labelColor, this.valueColor, this.isStrikethrough = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: labelColor ?? const Color(0xFF6B7280))),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF1A1A2E),
                decoration: isStrikethrough ? TextDecoration.lineThrough : null)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMPTY BANNER
// ═══════════════════════════════════════════════════════════════════════════════
class _EmptyBanner extends StatelessWidget {
  final String icon;
  final String message;

  const _EmptyBanner({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade100)),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w500, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
