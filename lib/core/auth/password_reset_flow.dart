enum PasswordResetRouteKind {
  none,
  request,
  reset,
}

class PasswordResetRouteIntent {
  const PasswordResetRouteIntent({
    required this.kind,
    this.token,
    this.email,
    this.preview,
  });

  final PasswordResetRouteKind kind;
  final String? token;
  final String? email;
  final String? preview;
}

PasswordResetRouteIntent resolvePasswordResetRoute(Uri uri) {
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

  final normalizedPath = _normalizePasswordResetPath(path);

  switch (normalizedPath) {
    case '/forgot-password':
      return PasswordResetRouteIntent(
        kind: PasswordResetRouteKind.request,
        email: query['email'],
        preview: query['preview'],
      );
    case '/reset-password':
      return PasswordResetRouteIntent(
        kind: PasswordResetRouteKind.reset,
        token: query['token'],
        email: query['email'],
        preview: query['preview'],
      );
    default:
      return const PasswordResetRouteIntent(kind: PasswordResetRouteKind.none);
  }
}

String _normalizePasswordResetPath(String path) {
  final trimmedPath = path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;

  if (trimmedPath == '/app') {
    return '/';
  }

  if (trimmedPath.startsWith('/app/')) {
    return trimmedPath.substring(4);
  }

  return trimmedPath;
}