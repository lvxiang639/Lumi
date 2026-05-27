import 'package:flutter/material.dart';

class Live2DView extends StatelessWidget {
  const Live2DView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.indigo.shade50,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 80, color: Colors.indigo),
            SizedBox(height: 8),
            Text('Live2D 角色', style: TextStyle(color: Colors.indigo, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
