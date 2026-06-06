import 'package:flutter/material.dart';
import '../../core/filesystem/vfs.dart';
import 'professional_editor_screen.dart';

class EditorScreen extends StatelessWidget {
  final VirtualFileSystem vfs;
  final String? initialFilePath;

  const EditorScreen({
    super.key,
    required this.vfs,
    this.initialFilePath,
  });

  @override
  Widget build(BuildContext context) {
    return ProfessionalEditorScreen(
      vfs: vfs,
      initialFilePath: initialFilePath,
    );
  }
}
