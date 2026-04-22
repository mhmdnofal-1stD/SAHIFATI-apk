import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../providers/evaluations_provider.dart';
import '../../providers/users_provider.dart';

typedef AuthenticatedRouteLoader = Future<void> Function(
  UsersProvider usersProvider,
  EvaluationsProvider evaluationsProvider,
);

class AuthenticatedRouteGate extends StatefulWidget {
  const AuthenticatedRouteGate({
    super.key,
    required this.child,
    this.loader,
  });

  final Widget child;
  final AuthenticatedRouteLoader? loader;

  @override
  State<AuthenticatedRouteGate> createState() => _AuthenticatedRouteGateState();
}

class _AuthenticatedRouteGateState extends State<AuthenticatedRouteGate> {
  late final Future<bool> _bootstrapFuture;
  bool _redirectScheduled = false;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  Future<bool> _bootstrap() async {
    final usersProvider = context.read<UsersProvider>();
    final evaluationsProvider = context.read<EvaluationsProvider>();

    if (usersProvider.selectedUser == null) {
      final isLoggedIn = await usersProvider.tryAutoLogin();
      if (!isLoggedIn || usersProvider.selectedUser == null) {
        return false;
      }
    }

    if (widget.loader != null) {
      await widget.loader!(usersProvider, evaluationsProvider);
    }

    return true;
  }

  void _scheduleRedirect() {
    if (_redirectScheduled) {
      return;
    }
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Get.offAllNamed('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data != true) {
          _scheduleRedirect();
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return widget.child;
      },
    );
  }
}