import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../models/pet_model.dart';

// ─── Result wrapper ───────────────────────────────────────────────────────────
class PetResult {
  final bool isSuccess;
  final PetModel? pet;
  final List<PetModel>? pets;
  final String? error;

  PetResult._({required this.isSuccess, this.pet, this.pets, this.error});

  factory PetResult.success({PetModel? pet, List<PetModel>? pets}) =>
      PetResult._(isSuccess: true, pet: pet, pets: pets);

  factory PetResult.error(String msg) =>
      PetResult._(isSuccess: false, error: msg);
}

// ─── Pet Repository ───────────────────────────────────────────────────────────
class PetRepository extends ChangeNotifier {
  final SharedPreferences _prefs;

  // Local cache key (used as offline fallback)
  static const _cacheKey = 'pets_list_v2';

  List<PetModel> _pets = [];
  bool _isLoading = false;

  PetRepository(this._prefs) {
    _loadFromCache(); // Show cached pets immediately while API loads
  }

  // ── Public getters ──────────────────────────────────────────────────────────
  List<PetModel> get pets     => List.unmodifiable(_pets);
  bool            get isLoading => _isLoading;

  PetModel? getPetById(String id) {
    try {
      return _pets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Token helper ────────────────────────────────────────────────────────────
  String get _token => _prefs.getString(AppConstants.keyAuthToken) ?? '';

  bool get _hasToken => _token.isNotEmpty;

  // ─── FETCH all pets from API ─────────────────────────────────────────────────
  // Call this on HomeScreen / PetListScreen load.
  Future<PetResult> fetchPets() async {
    if (!_hasToken) return PetResult.error('Not authenticated');

    _isLoading = true;
    notifyListeners();

    final response = await ApiService.get('/customer/pets', token: _token);

    _isLoading = false;

    if (response.success && response.data != null) {
      final rawList = response.data!['data'];
      if (rawList is List) {
        _pets = rawList
            .whereType<Map<String, dynamic>>()
            .map((j) => PetModel.fromJson(j))
            .toList();
        _saveToCache();
        notifyListeners();
        return PetResult.success(pets: _pets);
      }
    }

    notifyListeners();
    return PetResult.error(response.errorMessage);
  }

  // ─── ADD a new pet ────────────────────────────────────────────────────────────
  Future<PetResult> addPet(PetModel pet) async {
    if (!_hasToken) return PetResult.error('Not authenticated');

    final response = await ApiService.post(
      '/customer/pet/add',
      pet.toApiJson(),
      token: _token,
    );

    if (response.success && response.data?['data'] != null) {
      final created = PetModel.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
      // Preserve local-only fields (size) that server doesn't store
      final merged = created.copyWith(size: pet.size);
      _pets.insert(0, merged);
      _saveToCache();
      notifyListeners();
      return PetResult.success(pet: merged);
    }

    return PetResult.error(response.errorMessage);
  }

  // ─── UPDATE an existing pet ───────────────────────────────────────────────────
  Future<PetResult> updatePet(PetModel updated) async {
    if (!_hasToken) return PetResult.error('Not authenticated');

    final body = {
      'pet_id': int.tryParse(updated.id) ?? updated.id,
      ...updated.toApiJson(),
    };

    final response = await ApiService.post(
      '/customer/pet/update',
      body,
      token: _token,
    );

    if (response.success && response.data?['data'] != null) {
      final fromServer = PetModel.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
      // Keep local-only fields
      final merged = fromServer.copyWith(size: updated.size);
      final idx = _pets.indexWhere((p) => p.id == updated.id);
      if (idx != -1) {
        _pets[idx] = merged;
      } else {
        _pets.insert(0, merged);
      }
      _saveToCache();
      notifyListeners();
      return PetResult.success(pet: merged);
    }

    return PetResult.error(response.errorMessage);
  }

  // ─── DELETE a pet ─────────────────────────────────────────────────────────────
  Future<PetResult> deletePet(String id) async {
    if (!_hasToken) return PetResult.error('Not authenticated');

    final petId = int.tryParse(id) ?? id;
    final response = await ApiService.post(
      '/customer/pet/delete',
      {'pet_id': petId},
      token: _token,
    );

    if (response.success) {
      _pets.removeWhere((p) => p.id == id);
      _saveToCache();
      notifyListeners();
      return PetResult.success();
    }

    return PetResult.error(response.errorMessage);
  }

  // ─── GET single pet detail from API ──────────────────────────────────────────
  Future<PetResult> fetchPetDetail(String id) async {
    if (!_hasToken) return PetResult.error('Not authenticated');

    _isLoading = true;
    notifyListeners();

    final response = await ApiService.post(
      '/customer/pet/detail',
      {'pet_id': id},
      token: _token,
    );

    _isLoading = false;

    if (response.success && response.data?['data'] != null) {
      final localPet = getPetById(id);
      final serverPet = PetModel.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );

      final mergedPet = serverPet.copyWith(size: localPet?.size);

      final idx = _pets.indexWhere((p) => p.id == id);
      if (idx != -1) {
        _pets[idx] = mergedPet;
      } else {
        _pets.add(mergedPet);
      }

      _saveToCache();
      notifyListeners();
      return PetResult.success(pet: mergedPet);
    }

    notifyListeners();
    return PetResult.error(response.errorMessage ?? 'Failed to load pet details');
  }


  // ─── Cache helpers ────────────────────────────────────────────────────────────
  void _loadFromCache() {
    try {
      final raw = _prefs.getStringList(_cacheKey) ?? [];
      _pets = raw
          .map((e) => PetModel.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
      if (_pets.isNotEmpty) notifyListeners();
    } catch (_) {
      _pets = [];
    }
  }

  void _saveToCache() {
    try {
      final raw = _pets.map((p) => jsonEncode(p.toJson())).toList();
      _prefs.setStringList(_cacheKey, raw);
    } catch (_) {}
  }

  // ─── Clear cache on logout ────────────────────────────────────────────────────
  Future<void> clearCache() async {
    _pets = [];
    await _prefs.remove(_cacheKey);
    notifyListeners();
  }
}