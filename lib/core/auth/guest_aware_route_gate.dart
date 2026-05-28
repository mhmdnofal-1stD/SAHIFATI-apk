import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../providers/evaluations_provider.dart';
import '../../providers/users_provider.dart';

/// Restrictions that apply when a route is accessed in guest mode.
class GuestRestrictions {
  const GuestRestrictions({
    this.canSaveProgress = false,
    this.canOpenAssessmentDialog = false,
    this.canUseAdvancedFilters = false,
    this.canEnterSelectionMode = false,
  });

  final bool canSaveProgress;
  final bool canOpenAssessmentDialog;
  final bool canUseAdvancedFilters;
  final bool canEnterSelectionMode;

  /// Default restrictions for guest mode (all features disabled).
  static const GuestRestrictions none = GuestRestrictions();

  /// Allow guest to view content but not save or modify.
  static const GuestRestrictions readOnly = GuestRestrictions();

  /// Copy with changes.
  GuestRestrictions copyWith({
    bool? canSaveProgress,
    bool? canOpenAssessmentDialog,
    bool? canUseAdvancedFilters,
    bool? canEnterSelectionMode,
  }) {
    return GuestRestrictions(
      canSaveProgress: canSaveProgress ?? this.canSaveProgress,
      canOpenAssessmentDialog:
          canOpenAssessmentDialog ?? this.canOpenAssessmentDialog,
      canUseAdvancedFilters:
          canUseAdvancedFilters ?? this.canUseAdvancedFilters,
      canEnterSelectionMode:
          canEnterSelectionMode ?? this.canEnterSelectionMode,
    );
  }
}

typedef GuestAwareRouteLoader = Future<void> Function(
  UsersProvider usersProvider,
  EvaluationsProvider evaluationsProvider,
);

/// A flexible route gate that supports three access levels:
/// 1. Guest: No authentication required (if allowGuest = true)
/// 2. Registered: Authenticated user without license
/// 3. Licensed: Authenticated user with active license
///
/// This gate preserves auto-login behavior for existing users while
/// allowing guest access to specific routes as needed for Apple Review
/// compliance (5.1.1(v)).
class GuestAwareRouteGate extends StatefulWidget {
  const GuestAwareRouteGate({
    super.key,
    required this.child,
    this.requiresAuth = false,
    this.requiresLicense = false,
    this.allowGuest = true,
    this.guestRestrictions,
    this.loader,
  });

  final Widget child;

  /// Whether this route requires authentication (registered user).
  /// If true and user is not logged in, auto-login will be attempted.
  final bool requiresAuth;

  /// Whether this route requires an active license.
  /// Only checked if user is authenticated.
  final bool requiresLicense;

  /// Whether guest access is allowed for this route.
  /// If true, unauthenticated users can access the route with restrictions.
  final bool allowGuest;

  /// Restrictions that apply when accessing this route as a guest.
  final GuestRestrictions? guestRestrictions;

  /// Optional async loader that runs after authentication/license checks.
  final GuestAwareRouteLoader? loader;

  @override
  State<GuestAwareRouteGate> createState() => _GuestAwareRouteGateState();
}

class _GuestAwareRouteGateState extends State<GuestAwareRouteGate> {
  late final Future<bool> _bootstrapFuture;
  bool _redirectScheduled = false;
  String _redirectRoute = '/';

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  Future<bool> _bootstrap() async {
    final usersProvider = context.read<UsersProvider>();
    final evaluationsProvider = context.read<EvaluationsProvider>();

    // CRITICAL: Preserve auto-login behavior for existing users.
    // If auth is required and no user is logged in, attempt auto-login first.
    if (widget.requiresAuth && usersProvider.selectedUser == null) {
      final isLoggedIn = await usersProvider.tryAutoLogin();

      // If auto-login failed and guest is not allowed, redirect to login.
      if (!isLoggedIn && !widget.allowGuest) {
        _redirectRoute = '/login';
        return false;
      }

      // If auto-login failed but guest is allowed, proceed as guest.
      if (!isLoggedIn && widget.allowGuest) {
        return true; // Guest proceeds with restrictions
      }
    }

    // If no user is logged in at this point, check guest allowance.
    if (usersProvider.selectedUser == null) {
      if (widget.allowGuest) {
        return true; // Guest mode
      } else {
        _redirectRoute = '/login';
        return false;
      }
    }

    // User is authenticated. Check license requirement if needed.
    if (widget.requiresLicense) {
      try {
        await usersProvider.ensureLicenseStateLoaded(
          forceRefresh: !usersProvider.hasKnownLicenseState,
        );
      } catch (error) {
        debugPrint('Guest-aware gate skipped license refresh: $error');
      }

      if (!usersProvider.hasActiveLicense) {
        _redirectRoute = '/license-activation';
        return false;
      }
    }

    // Run optional loader if provided.
    if (widget.loader != null) {
      try {
        await widget.loader!(usersProvider, evaluationsProvider);
      } catch (error) {
        debugPrint('Guest-aware gate loader skipped: $error');
      }
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
      Get.offAllNamed(_redirectRoute);
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
