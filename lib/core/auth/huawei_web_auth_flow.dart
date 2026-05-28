enum HuaweiWebAuthRouteKind {
  none,
  callback,
}

class HuaweiWebAuthRouteIntent {
  const HuaweiWebAuthRouteIntent({
    required this.kind,
    this.provider,
    this.token,
    this.state,
    this.errorCode,
    this.errorMessage,
  });

  final HuaweiWebAuthRouteKind kind;
  final String? provider;
  final String? token;
  final String? state;
  final String? errorCode;
  final String? errorMessage;

  bool get hasError => errorCode != null && errorCode!.isNotEmpty;
}

HuaweiWebAuthRouteIntent resolveHuaweiWebAuthRoute(Uri uri) {
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

  final normalizedPath = _normalizeHuaweiWebAuthPath(path);
  if (normalizedPath != '/social-huawei-callback') {
    return const HuaweiWebAuthRouteIntent(kind: HuaweiWebAuthRouteKind.none);
  }

  return HuaweiWebAuthRouteIntent(
    kind: HuaweiWebAuthRouteKind.callback,
    provider: query['provider'],
    token: query['token'],
    state: query['state'],
    errorCode: query['errorCode'],
    errorMessage: query['errorMessage'],
  );
}

String _normalizeHuaweiWebAuthPath(String path) {
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