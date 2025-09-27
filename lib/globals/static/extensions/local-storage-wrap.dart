import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'dart:convert';
import 'package:secondstudent/globals/static/extensions/build_context_extension.dart';

//and doesn't add duplicates
extension LocalStorageWrap on LocalStorage {
  void inclusiveSetItem(String key, dynamic value, BuildContext context) {
    final current = localStorage.getItem(key);
    if (current == null) {
      context.showSnackBar('item was not in the list aaaa');
    } else {
      final currentList = jsonDecode(current);
      final currentMap = Map<String, dynamic>.from(currentList);
      if (currentMap.containsKey(value)) {
        print('item was already in the list aaa');
        return;
      }
      currentMap[value] = value;
      localStorage.setItem(key, jsonEncode(currentMap));
    }
  }
}
