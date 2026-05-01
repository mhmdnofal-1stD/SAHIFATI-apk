enum PurchaseReturnKind {
  none,
  success,
  failure,
  cancelled,
}

class PurchaseReturnIntent {
  const PurchaseReturnIntent({required this.kind});

  final PurchaseReturnKind kind;
}

PurchaseReturnIntent resolvePurchaseReturnRoute(
  Uri uri, {
  String? explicitStatus,
}) {
  final explicitIntent = purchaseReturnIntentFromStatus(explicitStatus);
  if (explicitIntent.kind != PurchaseReturnKind.none) {
    return explicitIntent;
  }

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

  final normalizedPath = _normalizePurchaseReturnPath(path);
  if (normalizedPath != '/license-activation' &&
      normalizedPath != '/my-licenses') {
    return const PurchaseReturnIntent(kind: PurchaseReturnKind.none);
  }

  return purchaseReturnIntentFromStatus(query['purchase']);
}

PurchaseReturnIntent purchaseReturnIntentFromStatus(String? rawStatus) {
  final normalized = rawStatus?.trim().toLowerCase();
  switch (normalized) {
    case 'success':
    case 'paid':
      return const PurchaseReturnIntent(kind: PurchaseReturnKind.success);
    case 'failure':
    case 'failed':
      return const PurchaseReturnIntent(kind: PurchaseReturnKind.failure);
    case 'cancelled':
    case 'canceled':
    case 'cancel':
      return const PurchaseReturnIntent(kind: PurchaseReturnKind.cancelled);
    default:
      return const PurchaseReturnIntent(kind: PurchaseReturnKind.none);
  }
}

String _normalizePurchaseReturnPath(String path) {
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
