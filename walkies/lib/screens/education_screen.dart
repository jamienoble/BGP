import 'package:flutter/material.dart';

class EducationScreen extends StatelessWidget {
  const EducationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Education'),
      ),
      body: const Center(
        child: Text(
          'Education content coming soon...',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
