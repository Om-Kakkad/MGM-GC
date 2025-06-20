import 'package:flutter/material.dart';

class DummyPaymentPage extends StatelessWidget {
  const DummyPaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context, true);
          },
          child: const Text('Confirm Payment'),
        ),
      ),
    );
  }
}
