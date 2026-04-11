import 'package:flutter/material.dart';

class SearchProvider extends ChangeNotifier {
  String _query = '';
  String? _categorySlug;
  String? _categoryName;

  String get query => _query;
  String? get categorySlug => _categorySlug;
  String? get categoryName => _categoryName;

  bool get hasFilter => _query.isNotEmpty || _categorySlug != null;

  void setSearch(String q) {
    _query = q;
    _categorySlug = null;
    _categoryName = null;
    notifyListeners();
  }

  void setCategory(String slug, String name) {
    _categorySlug = slug;
    _categoryName = name;
    _query = '';
    notifyListeners();
  }

  void clear() {
    _query = '';
    _categorySlug = null;
    _categoryName = null;
    notifyListeners();
  }
}
