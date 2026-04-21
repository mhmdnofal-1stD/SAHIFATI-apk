enum VerificationRouteKind {
  none,
  pending,
  verifyToken,
  success,
  failed,
  expired,
}

class VerificationRouteIntent {
  const VerificationRouteIntent({
    required this.kind,
    this.token,
    this.email,
  });

  final VerificationRouteKind kind;
  final String? token;
  final String? email;
}

VerificationRouteIntent resolveVerificationRoute(Uri uri) {
  String path = uri.path;
  final query = <String, String>{...uri.queryParameters};

  if (uri.fragment.isNotEmpty) {
    final normalizedFragment =
        uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}';
    final fragmentUri = Uri.parse(normalizedFragment);
    if (fragmentUri.path.isNotEmpty && fragmentUri.path != '/') {
      path = fragmentUri.path;
    }
    query.addAll(fragmentUri.queryParameters);
  }

  final normalizedPath = path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;

  switch (normalizedPath) {
    case '/verification-pending':
      return VerificationRouteIntent(
        kind: VerificationRouteKind.pending,
        email: query['email'],
      );
    case '/verify-email':
      return VerificationRouteIntent(
        kind: VerificationRouteKind.verifyToken,
        token: query['token'],
        email: query['email'],
      );
    case '/verification-success':
      return VerificationRouteIntent(
        kind: VerificationRouteKind.success,
        email: query['email'],
      );
    case '/verification-expired':
      return VerificationRouteIntent(
        kind: VerificationRouteKind.expired,
        email: query['email'],
      );
    case '/verification-failed':
      return VerificationRouteIntent(
        kind: VerificationRouteKind.failed,
        email: query['email'],
      );
    default:
      return const VerificationRouteIntent(kind: VerificationRouteKind.none);
  }
}

String maskEmailAddress(String email) {
  final parts = email.trim().split('@');
  if (parts.length != 2) {
    return email;
  }

  final localPart = parts.first;
  final domain = parts.last;

  if (localPart.length <= 1) {
    return '***@$domain';
  }

  if (localPart.length == 2) {
    return '${localPart[0]}***@$domain';
  }

  final prefix = localPart.substring(0, 2);
  final suffix = localPart.substring(localPart.length - 1);
  return '$prefix***$suffix@$domain';
}
