import 'package:localstorage/localstorage.dart';
import 'dart:convert';

//and doesn't add duplicates
extension LocalStorageWrap on LocalStorage {
  void inclusiveSetItem(String key, dynamic value) {
    final current = getItem(key);
    if (current == null) {
      setItem(key, value);
    } else {
      final currentList = jsonDecode(current);
      final currentMap = Map<String, dynamic>.from(currentList);
      if (currentMap.containsKey(value)) {
        return;
      }
      currentMap[value] = value;
      setItem(key, jsonEncode(currentMap));
    }
  }
}
