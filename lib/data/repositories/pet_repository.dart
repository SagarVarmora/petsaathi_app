import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet_model.dart';

class PetRepository extends ChangeNotifier {
  final SharedPreferences _prefs;
  static const _key = 'pets_list';

  List<PetModel> _pets = [];

  PetRepository(this._prefs) {
    _loadPets();
  }

  List<PetModel> get pets => List.unmodifiable(_pets);

  PetModel? getPetById(String id) {
    try {
      return _pets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  void _loadPets() {
    final raw = _prefs.getStringList(_key) ?? [];
    _pets = raw
        .map((e) => PetModel.fromJson(jsonDecode(e)))
        .toList();
    notifyListeners();
  }

  Future<void> _savePets() async {
    final raw = _pets.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_key, raw);
  }

  Future<void> addPet(PetModel pet) async {
    _pets.add(pet);
    await _savePets();
    notifyListeners();
  }

  Future<void> updatePet(PetModel updated) async {
    final idx = _pets.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _pets[idx] = updated;
      await _savePets();
      notifyListeners();
    }
  }

  Future<void> deletePet(String id) async {
    _pets.removeWhere((p) => p.id == id);
    await _savePets();
    notifyListeners();
  }
}
