import 'package:flutter/material.dart';
import 'package:flutter_automation/flutter_automation.dart';

import 'package:example/automation/example_target.dart';

/// First screen: one button that opens the catalog.
class LoginScreen extends StatelessWidget {
  static const routeName = 'login';

  final VoidCallback onSignInPressed;

  const LoginScreen({super.key, required this.onSignInPressed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Center(
        child: FilledButton(
          onPressed: onSignInPressed,
          child: const Text('Sign in'),
        ).automationTarget(ExampleTarget.loginButton),
      ),
    ).automationTarget(ExampleTarget.loginScreen);
  }
}
