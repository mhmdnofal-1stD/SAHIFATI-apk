/// Enumeration of all social sign-in providers supported by the app.
///
/// Add a new entry here when onboarding a new provider, then wire it up in
/// [SocialProviderRegistry] and [SocialAuthAction].
enum SocialProvider {
  google,
  apple,
  facebook,
  huawei,
}
