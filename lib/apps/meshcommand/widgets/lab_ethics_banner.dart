import 'package:flutter/material.dart';

import '../ui/mesh_tokens.dart';

/// Prominent lawful-use framing for RF / lab tooling surfaces.
class LabEthicsBanner extends StatelessWidget {
  const LabEthicsBanner({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(dense ? 10 : 12),
      decoration: BoxDecoration(
        color: MeshTokens.warning().withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: MeshTokens.warning().withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel_rounded, size: dense ? 18 : 20, color: MeshTokens.warning()),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dense
                  ? 'Authorized testing only ? your hardware, documented consent, lawful bands.'
                  : 'Authorized testing only: capture and analyze transmitters you own or are contractually allowed to test. This UI stores logical traces and forwards sandbox simulation frames inside MeshCommand ? it does not transmit on RF by itself.',
              style: TextStyle(
                color: MeshTokens.textPrimary(),
                fontSize: dense ? 10 : 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
