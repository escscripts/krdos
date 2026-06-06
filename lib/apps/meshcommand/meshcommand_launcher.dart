import 'package:flutter/material.dart';
import 'meshcommand_app.dart';

class MeshCommandLauncher extends StatelessWidget {
  const MeshCommandLauncher({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Padding(padding: const EdgeInsets.all(16), child: MeshCommandApp()),
    );
  }
}

// Simpler minimal MeshCommand widget that can be embedded
class MeshCommandMinimal extends StatelessWidget {
  const MeshCommandMinimal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MeshCommandApp();
  }
}
