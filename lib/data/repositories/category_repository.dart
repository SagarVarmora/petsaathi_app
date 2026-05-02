import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../models/category_model.dart';

// ─── Result Wrappers ──────────────────────────────────────────────────────────
class CategoryResult {
  final bool isSuccess;
  final List<MainCategory>? categories;
  final String? error;

  CategoryResult._({required this.isSuccess, this.categories, this.error});

  factory CategoryResult.success(List<MainCategory> cats) =>
      CategoryResult._(isSuccess: true, categories: cats);
  factory CategoryResult.error(String msg) =>
      CategoryResult._(isSuccess: false, error: msg);
}

class ServicesResult {
  final bool isSuccess;
  final SubCategoryWithServices? data;
  final String? error;

  ServicesResult._({required this.isSuccess, this.data, this.error});

  factory ServicesResult.success(SubCategoryWithServices d) =>
      ServicesResult._(isSuccess: true, data: d);
  factory ServicesResult.error(String msg) =>
      ServicesResult._(isSuccess: false, error: msg);
}

// ─── Category Repository ──────────────────────────────────────────────────────
class CategoryRepository extends ChangeNotifier {
  final SharedPreferences _prefs;
  static const _cacheKey = 'categories_cache_v1';

  List<MainCategory> _categories = [];
  bool _isLoading = false;
  String? _error;

  CategoryRepository(this._prefs) {
    _loadFromCache();
  }

  // ── Public getters ──────────────────────────────────────────────────────────
  List<MainCategory> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Token helper ────────────────────────────────────────────────────────────
  String get _token => _prefs.getString(AppConstants.keyAuthToken) ?? '';

  // ─── FETCH all main categories (with sub-categories) ─────────────────────────
  // GET /categories  → paginated list with sub_categories
  Future<CategoryResult> fetchCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch all pages (usually 1 page is enough)
      final response = await ApiService.get(
        '/categories',
        token: _token.isNotEmpty ? _token : null,
      );

      _isLoading = false;

      if (response.success && response.data != null) {
        // Response is paginated: { current_page, data: [...], ... }
        final rawList = response.data!['data'];
        if (rawList is List) {
          _categories = rawList
              .whereType<Map<String, dynamic>>()
              .map((j) => MainCategory.fromJson(j))
              .where((c) => c.status)
              .toList();
          _saveToCache();
          notifyListeners();
          return CategoryResult.success(_categories);
        }
      }

      _error = response.errorMessage;
      notifyListeners();
      return CategoryResult.error(response.errorMessage);
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return CategoryResult.error(e.toString());
    }
  }

  // ─── FETCH services by sub-category ──────────────────────────────────────────
  // POST /subcategories/services  { "sub_category_id": id }
  Future<ServicesResult> fetchServicesBySubCategory(int subCategoryId) async {
    final response = await ApiService.post(
      '/subcategories/services',
      {'sub_category_id': subCategoryId},
      token: _token.isNotEmpty ? _token : null,
    );

    if (response.success && response.data != null) {
      final data = SubCategoryWithServices.fromJson(response.data!);
      return ServicesResult.success(data);
    }

    return ServicesResult.error(response.errorMessage);
  }

  // ─── FETCH sub-categories for a main category ─────────────────────────────────
  // POST /categories/subcategories  { "category_id": id }
  Future<List<SubCategory>> fetchSubCategories(int categoryId) async {
    final response = await ApiService.post(
      '/categories/subcategories',
      {'category_id': categoryId},
      token: _token.isNotEmpty ? _token : null,
    );

    if (response.success && response.data != null) {
      final rawSubs = response.data!['sub_categories'];
      if (rawSubs is List) {
        return rawSubs
            .whereType<Map<String, dynamic>>()
            .map((j) => SubCategory.fromJson(j))
            .toList();
      }
    }

    return [];
  }

  // ─── Cache helpers ────────────────────────────────────────────────────────────
  void _loadFromCache() {
    try {
      final raw = _prefs.getString(_cacheKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _categories = list
            .whereType<Map<String, dynamic>>()
            .map((j) => MainCategory.fromJson(j))
            .toList();
        if (_categories.isNotEmpty) notifyListeners();
      }
    } catch (_) {
      _categories = [];
    }
  }

  void _saveToCache() {
    try {
      final raw = jsonEncode(_categories.map((c) => c.toJson()).toList());
      _prefs.setString(_cacheKey, raw);
    } catch (_) {}
  }

  Future<void> clearCache() async {
    _categories = [];
    await _prefs.remove(_cacheKey);
    notifyListeners();
  }
}