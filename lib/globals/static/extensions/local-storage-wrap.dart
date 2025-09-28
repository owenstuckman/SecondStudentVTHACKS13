import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'dart:convert';
import 'package:secondstudent/globals/static/extensions/build_context_extension.dart';

//and doesn't add duplicates
extension LocalStorageWrap on LocalStorage {
  void inclusiveSetItem(String key, dynamic value, [BuildContext? context]) {
    List<dynamic> incoming;
    if (value is String) {
      try {
        incoming = jsonDecode(value) as List<dynamic>;
      } catch (_) {
        return;
      }
    } else if (value is List) {
      incoming = value;
    } else {
      return;
    }

    final existingRaw = localStorage.getItem(key);
    final List<dynamic> existing =
        (existingRaw != null && existingRaw.isNotEmpty)
        ? (jsonDecode(existingRaw) as List<dynamic>)
        : <dynamic>[];

    final Map<String, Map<String, dynamic>> byId = {};
    for (final item in existing) {
      if (item is Map && item['id'] != null) {
        byId[item['id'].toString()] = Map<String, dynamic>.from(item);
      }
    }
    for (final item in incoming) {
      if (item is Map && item['id'] != null) {
        byId[item['id'].toString()] = Map<String, dynamic>.from(item);
      }
    }

    final merged = byId.values.toList();
    localStorage.setItem(key, jsonEncode(merged));
  }
}

void deleteItem(String key, String id) {
  final existingRaw = localStorage.getItem(key);
  final List<dynamic> existing = (existingRaw != null && existingRaw.isNotEmpty)
      ? (jsonDecode(existingRaw) as List<dynamic>)
      : <dynamic>[];

  final Map<String, Map<String, dynamic>> byId = {};
}
