# sahifaty

A new Flutter project.

## API routing for experiments

- Web builds now use `https://sahifati.org/api` by default, including when served from `localhost` or `127.0.0.1`.
- If you intentionally want the web app to talk to a locally running API on `http://127.0.0.1:3077/api`, start or build with:

```bash
flutter run -d chrome --dart-define=USE_LOCAL_API_ON_WEB=true
```

- You can still override the full API target explicitly with:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://example.com/api
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
