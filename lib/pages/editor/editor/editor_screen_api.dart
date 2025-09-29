// ================= Editor API injector (to allow external load) =================

import 'package:flutter/material.dart'; // Import for InheritedWidget and BuildContext
import 'package:secondstudent/pages/editor/editor/editor.dart'; // Import for EditorScreen and EditorScreenState



/// Editor API the host (workspace/file viewer) can call.
abstract class EditorScreenApi {
  void loadFromJson(String json, String filePath);
}

/// Lightweight inherited widget to expose an API to the editor.
class EditorApiInjector extends InheritedWidget {
  final void Function(EditorScreenApi api) onCreateApi;

  const EditorApiInjector({required this.onCreateApi, required super.child});

  static EditorApiInjector? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EditorApiInjector>();

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

/// Extend EditorScreen’s State to register an API instance.
extension EditorScreenApiHook on State<EditorScreen> {
  void attachEditorApi(BuildContext context, EditorScreenApi api) {
    final injector = EditorApiInjector.of(context);
    if (injector != null) injector.onCreateApi(api);
  }
}

/// Concrete API implementation that delegates to the editor state.
class EditorApiImpl implements EditorScreenApi {
  final EditorScreenState _state;
  EditorApiImpl(State<EditorScreen> s) : _state = s as EditorScreenState;

  @override
  void loadFromJson(String json, String filePath) {
    _state.loadFromJsonString(json, sourcePath: filePath);
  }
}