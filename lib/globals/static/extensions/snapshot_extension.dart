import 'package:flutter/cupertino.dart';

extension SnapshotExtension on AsyncSnapshot {
  bool isReady({bool requireData = false}) {
    if(requireData && !hasData){
      return false;
    }
    return hasError || connectionState == ConnectionState.waiting;
  }
}
