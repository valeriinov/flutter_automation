import 'package:flutter/material.dart';
import 'package:flutter_automation/flutter_automation.dart';

import 'package:example/automation/example_target.dart';

/// First screen: one button that opens the catalog.
class LoginScreen extends StatelessWidget {
  static const routeName = 'login';

  final VoidCallback onSignInPressed;

  /// Opens the mock mode switch. It is null in a build that cannot switch.
  final VoidCallback? onMockModePressed;

  const LoginScreen({
    super.key,
    required this.onSignInPressed,
    this.onMockModePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        actions: [
          if (onMockModePressed != null)
            IconButton(
              tooltip: 'Mock mode',
              onPressed: onMockModePressed,
              icon: const Icon(Icons.settings),
            ),
        ],
      ),
      body: Center(
        child: FilledButton(
          onPressed: onSignInPressed,
          child: const Text('Sign in'),
        ).automationTarget(ExampleTarget.loginButton),
      ),
    ).automationTarget(ExampleTarget.loginScreen);
  }
}
