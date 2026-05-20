# Sahifati — Platform Integration Reference (2026-05-20)

هذا المستند مرجع تشغيلي وتقني نهائي لتكامل تسجيل الدخول الاجتماعي ونشر الحزم على منصات Google, Facebook, Apple, و Huawei. يحفظ الملف كدليل مرجعي ويُحدَّث عند أي تغيير.

---

## 1) معلومات عامة وموقع الملفات

- مشروع الواجهة: `frontend_users/ui`
- سكربت البناء (Android): `frontend_users/ui/scripts/build_android_release.ps1`
- ملفات التكوين المهمة (Android/iOS/Huawei):
  - `frontend_users/ui/android/key.properties`  (توقيع التطبيق)
  - `frontend_users/ui/android/sahifati_key.jks` (موجود، لكن signing يستخدم `Public-data-/UP.Key.jks` عبر key.properties)
  - `Public-data-/UP.Key.jks` (keystore المستخدم للتوقيع)
  - `frontend_users/ui/android/app/agconnect-services.json` (HMS / Huawei config)
  - `frontend_users/ui/android/app/src/main/res/values/strings.xml` (Facebook IDs / tokens)
  - `frontend_users/ui/ios/Runner/Info.plist` (iOS metadata)
  - `frontend_users/ui/build/app/outputs/bundle/release/app-release.aab` (بُنية AAB المنتجة – إنشاؤها بتاريخ 2026-05-20)

> ملاحظة: المفاتيح الحساسة (مثل `FACEBOOK_APP_SECRET`, مفاتيح الخادم) لا توضع في هذا المستند كنقطة أمنية إلا إذا طلبت صراحة إدراجها؛ هذا المستند يذكر مكان تواجد الإعدادات والملفات في المشروع.

---

## 2) ملخص الاعتمادات النهائية (مستخرجة من الشيفرة/الملفات)

- Package name: `org.sahifati.app`  (android/iOS)

### Google
- Client IDs (حسب السياق):
  - `GOOGLE_SERVER_CLIENT_ID` (build script default): `605484701854-h07an8isp8gr4jim786hi9tqegq62n5k.apps.googleusercontent.com` (انظر `scripts/build_android_release.ps1`)
  - Codemagic override (`codemagic.yaml`): `GOOGLE_SERVER_CLIENT_ID` / `GOOGLE_WEB_CLIENT_ID` = `821809289982-m9g7reu9a9vfju911rg3uqg009rr12rp.apps.googleusercontent.com`
- أين تُستخدم: `lib/core/auth/social_auth_config.dart`, build `--dart-define`، وخدمات الويب الخلفية للتحقق.

### Facebook
- `FACEBOOK_APP_ID` = `824178674089653`  (انظر `android/app/src/main/res/values/strings.xml` و build args)
- `facebook_client_token` = `e41edcbe4e732266e3cc5055271fc6b5` (انظر `strings.xml`)
- `FACEBOOK_APP_SECRET` → يجب أن يُخزن في بيئة الخادم (غير موجود بالملفات العامة). الخلفية تتوقع هذا المتغير في إعدادات بيئة السيرفر.
- أين تُستخدم:
  - واجهة: `lib/providers/users_provider.dart`, `lib/screens/authentication_screens/social_auth_action.dart`
  - خلفية: endpoint `POST /auth/social/facebook` (راجع `sahifati_api/src/auth/...`)

### Apple (Sign in with Apple)
- `APPLE_WEB_CLIENT_ID` = `org.sahifati.app.signin` (موجود كـ dart-define في build script)
- `APPLE_REDIRECT_URI` = `https://sahifati.org/api/auth/social/apple/callback`
- أين تُستخدم: `scripts/build_android_release.ps1` (Web flow), وكود الويب/خلفية للتحقق.

### Huawei (HMS)
- `HUAWEI_APP_ID` = `116918405` (انظر `agconnect-services.json` و build args)
- `agconnect-services.json` محتوى (مقتطفات):
  - `app_id`: `116918405`
  - `package_name`: `org.sahifati.app`
  - `client_id` / `project_id` موجود داخل `client` و `oauth_client`
- أين تُستخدم: `lib/core/auth/social_auth_config.dart`، البناء يمرر `--dart-define=HUAWEI_APP_ID`، وملفات `agconnect-services.json` مطلوبة في `android/app` للبناء الصحيح.

### Signing / Keystore
- `frontend_users/ui/android/key.properties`:
  - `storeFile=../../../Public-data-/UP.Key.jks`
  - `keyAlias=upload`
  - `storePassword=P@ssw0rd`
  - `keyPassword=P@ssw0rd`
- keystore الفعلي المستخدم: `Public-data-/UP.Key.jks` (يوجد أيضاً: `android/sahifati_key.jks`, `android/sahifati_upload_reset_2026.jks`)
- بصمات التوقيع التي تم طباعتها أثناء بناء AAB (2026-05-20):
  - SHA1: `6F:DA:D4:C7:24:28:5A:F5:E3:A7:94:8B:00:4C:E3:81:D6:87:71:50`
  - SHA256: `BD:35:02:FB:5A:EB:AD:AA:E5:E3:DB:8C:98:BF:27:BB:59:7D:5B:E5:05:29:38:9D:EE:47:0A:9C:5B:0F:E5:03`

---

## 3) أين تُخزن المتغيرات والسرّيات (محلياً وCI والخادم)

- ملفات ثابتة في المستودع (موجودة ومذكورة أعلاه):
  - `android/key.properties` (يشير إلى `storeFile` داخلي)
  - `android/app/agconnect-services.json` (Huawei config)
  - `android/app/src/main/res/values/strings.xml` (Facebook id & client token)
- متغيرات لا يجب حفظها في Git (يجب أن تكون في CI أو env server):
  - `FACEBOOK_APP_SECRET` (خادم)
  - أي Google Client Secret (خادم، إن وُجد)
- متغيرات build تمرّر عبر `--dart-define` في سكربت البناء أو CI (`codemagic.yaml`, `scripts/build_android_release.ps1`).

---

## 4) دليل الإجراء (How-To) — بناء/نشر/صيانة لكل منصة

### 4.1 Android (Google Play / Huawei AppGallery)

- أنشئ AAB موقع باستخدام السكربت (مثال AAB لهواوي):
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "e:\Sahifati\frontend_users\ui\scripts\build_android_release.ps1" -Artifact aab -HuaweiAppId 116918405
```
- قبل البناء تأكد من:
  - وجود `key.properties` وإمكانية الوصول إلى keystore المشار إليه.
  - وجود `agconnect-services.json` في `android/app` إذا كان `HUAWEI_APP_ID` محدد.
  - تمرير قيم `GOOGLE_SERVER_CLIENT_ID`, `FACEBOOK_APP_ID`, `APPLE_WEB_CLIENT_ID` عبر `--dart-define` أو سكربت CI.
- رفع على Huawei AppGallery:
  1. سجل دخول إلى AppGallery Connect.
  2. في App / Distribute → Create Release، ارفع `app-release.aab`.
  3. تأكد من أن `package name` و`app id` في AppGallery يطابقان `org.sahifati.app` و`116918405`.
  4. في حال طلبت المراجع أذونات أو توثيق، أرفق لقطات الشاشة ودليل خطوات الاختبار (انظر قسم "ملاحظات المراجع" أدناه).

صيانة/تحديث:
- لتدوير Upload Key: قم بإنشاء keystore جديد واطلب عبر Huawei/Play Console إجراء رفع مفتاح جديد (اتبع خطوات المنصة). احتفظ بنسخة احتياطية في مكان آمن.
- عند تغيير `app_id` أو `package_name` يجب إعادة إنشاء التكوينات في منصة المطور وتحديث `agconnect-services.json`/console.

### 4.2 Google (Android / Web)

- تأكد من أن SHA1 الصحيح مسجل داخل Google Cloud Console OAuth client المرتبط بـ `GOOGLE_SERVER_CLIENT_ID`.
- لإضافة/تعديل Google client IDs: افتح Google Cloud Console → Credentials → OAuth 2.0 Client IDs.
- تحديث القيم في CI (`codemagic.yaml`) أو pass `--dart-define` عند البناء.

صيانة:
- عند تدوير مفاتيح OAuth (Client secret) حدِّث الخلفية وأي مكان يُستخدم فيه السر فوراً.
- إن تعطل Sign-In على Android: تحقق من تطابق `applicationId`، SHA1 من keystore، ووجود clientId المرتبط.

### 4.3 Facebook

- تأكد من إعداد App Domains وValid OAuth Redirect URIs داخل Meta App Dashboard.
- أثناء المراجعة اترك الأذونات على `email` و `public_profile` فقط.
- مواضع التحديث:
  - واجهة: `strings.xml` و `--dart-define` عند الحاجة.
  - خلفية: ضع `FACEBOOK_APP_SECRET` في environment variables في الخادم (مثلاً: `SAHIFATI_FACEBOOK_APP_SECRET`).

صيانة:
- إذا احتجت إعادة تعيين App Secret: افعل ذلك من Dashboard وأعد تكوين الخادم ليستخدم القيمة الجديدة ثم اطلب من الفريق تحديث أي إعدادات CI تتعلق بها.
- إن فشل التحقق على الخلفية، افحص `debug_token` و`app_id` المتوقعة.

### 4.4 Apple (Sign in with Apple)

- إعدادات مطور Apple المطلوب:
  - في Apple Developer: تسجيل Service ID أو App ID مطابق لـ `org.sahifati.app.signin`، وتهيئة Redirect URI `https://sahifati.org/api/auth/social/apple/callback`.
  - في App Store Connect: تفعيل Sign In with Apple إن لزم.
- البناء: `--dart-define=APPLE_WEB_CLIENT_ID` و `APPLE_REDIRECT_URI` تمرر من سكربت البناء.

صيانة:
- تدوير مفاتيح (Private Key) في Apple Developer يتطلب تحديث الخادم الذي يستخدم المفتاح لتوقيع/التحقق من التوكنات.

---

## 5) إجراءات الطوارئ واسترجاع المفاتيح

- فقدان keystore (upload key): استخدم `sahifati_upload_reset_2026.jks` إن كانت مهيئة كخطة احتياطية، أو تابع سياسات كل منصة لطلب إعادة تعيين مفتاح الرفع (Play Console / Huawei support).
- اختراق App Secret: قم بتدوير السر فوراً في Dashboard (Meta/Google) ثم حدّث متغيرات البيئة على الخوادم وCI، وأعد بناء التطبيق إذا لزم.

---

## 6) ملاحظات المراجعة لمراجعي المنصات (اختصار جاهز للطبع)

- الحساب التجريبي: قدّم بيانات حساب اختبار (email / password) إن لزم.
- خطوات الاختبار: فتح التطبيق → شاشة تسجيل الدخول → اختيار موفر (Google/Facebook/Huawei/Apple) → إتمام المصادقة → التأكد من العودة للتطبيق وتسجيل الحساب.
- روابط مهمة:
  - سياسة الخصوصية: `https://sahifati.org/privacy.html`
  - رابط الدعم/اتصال المراجع: `info@sahifati.org` (أو البريد الذي تحددونه)

---

## 7) سجل الملفات/قيم مهمة (مقتطفات)

- `facebook_app_id`: `824178674089653`  (file: `android/app/src/main/res/values/strings.xml`)
- `facebook_client_token`: `e41edcbe4e732266e3cc5055271fc6b5` (same file)
- `HUAWEI_APP_ID`: `116918405` (file: `android/app/agconnect-services.json`)
- `APP Bundle (AAB) output`: `build/app/outputs/bundle/release/app-release.aab` (تم إنشاؤه 2026-05-20)
- Signing keystore path (as referenced): `Public-data-/UP.Key.jks`
- Key alias: `upload` (from `android/key.properties`)

---

## 8) من يحتاج أن يعرف هذا؟
- فريق النشر (DevOps / Release Manager)
- مسؤول الـ App Store / AppGallery
- فريق backend (لأن secrets مثل `FACEBOOK_APP_SECRET` وGoogle secrets تُستخدم هناك)
- الدعم الفني (لإعطاء ملاحظات المراجع وحسابات اختبار)

---

## 9) خطوات مقترحة بعد القراءة الآن
1. قرّر إن أردت تخزين هذا الملف في repo (تم حفظه في `frontend_users/ui/docs`) أو نقل نسخة مُشفرة في إدارة أسرار.
2. أخبرني إن أردت إدراج القيم الحساسة بالكامل (مثل `FACEBOOK_APP_SECRET`) داخل هذا المستند — سأقوم بذلك فقط بعد تأكيدك وطريقة الحفظ المطلوبة.
3. أستطيع توليد ZIP جاهز للرفع يحتوي `app-release.aab`, `agconnect-services.json`, و`README` خاص بالرفع إن رغبت.

---

تحديث حالة المهمة: تم إنشاء الوثيقة المرجعية `platform-integration-reference-2026-05-20.md`。

---

## 10) القيم السرية وتوصيات تخزينها (CI secrets)

هذا القسم يسجل القيم السرية الموجودة حالياً في المستودع أو المطلوبة من الفريق، ويقترح أسماء متغيرات بيئة لـ CI (Codemagic / GitHub Actions / Azure Pipelines) لكي تحفظ كـ secrets وتُستخدم أثناء البناء أو النشر.

### 10.1 القيم المكتشفة حالياً داخل المستودع
- `android/key.properties` (حاليًا محفوظ في repo — ينصح بنقله إلى CI secrets):
  - `storeFile=../../../Public-data-/UP.Key.jks` (path to keystore file)
  - `keyAlias=upload`
  - `storePassword=P@ssw0rd`
  - `keyPassword=P@ssw0rd`

- Facebook (من `android/app/src/main/res/values/strings.xml`):
  - `FACEBOOK_APP_ID` = `824178674089653`
  - `FACEBOOK_CLIENT_TOKEN` = `e41edcbe4e732266e3cc5055271fc6b5`

- Huawei AGConnect (من `android/app/agconnect-services.json`):
  - `client_secret` = `489529D2F7CA163FE1B89FC8DB1006F1207E952E37676D194D8DE8B9681AAA36`
  - `app_id` = `116918405`

### 10.2 القيم السرية المطلوبة والمفقودة في المستودع (يجب توفيرها وتخزينها في CI)
- `FACEBOOK_APP_SECRET` — **مطلوب** للخادم (backend) للتحقق من توكنات Facebook. لم يُعثر على القيمة في المستودع؛ يُرجى تزويدها أو حفظها كـ CI secret باسم `SAHIFATI_FACEBOOK_APP_SECRET`.
- Google client secret (إن وُجد للخوادم): خزنه كـ `SAHIFATI_GOOGLE_CLIENT_SECRET` إن لزم.
- Apple private key (Sign in with Apple) و`KEY_ID` و`TEAM_ID`: خزّنها كـ `SAHIFATI_APPLE_PRIVATE_KEY` (مفتاح .p8 مشفر أو محتوى)، `SAHIFATI_APPLE_KEY_ID`, `SAHIFATI_APPLE_TEAM_ID`.

### 10.3 اقتراحات أسماء متغيرات CI (مثال)
- `SAHIFATI_KEYSTORE_BASE64` — (اختياري) نسخة مشفّرة/مشفّرة Base64 من keystore لكتابة ملف أثناء الـ CI
- `SAHIFATI_KEYSTORE_PASSWORD` — بديل لـ `storePassword`
- `SAHIFATI_KEY_PASSWORD` — بديل لـ `keyPassword`
- `SAHIFATI_KEY_ALIAS` — بديل لـ `keyAlias`
- `SAHIFATI_FACEBOOK_APP_SECRET` — Facebook App Secret (خادم)
- `SAHIFATI_HUAWEI_CLIENT_SECRET` — (إن رغبتم نقل القيمة من `agconnect-services.json` إلى سرّ CI)

### 10.4 كيفية توليد/كتابة `key.properties` أثناء CI (PowerShell example)

```powershell
# This runs in CI (Codemagic/GHA) where secrets are available as env vars
$keystoreBase64 = $env:SAHIFATI_KEYSTORE_BASE64
[System.IO.File]::WriteAllBytes("android/UP.Key.jks", [System.Convert]::FromBase64String($keystoreBase64))
$content = @()
$content += "storeFile=UP.Key.jks"
$content += "storePassword=$env:SAHIFATI_KEYSTORE_PASSWORD"
$content += "keyAlias=$env:SAHIFATI_KEY_ALIAS"
$content += "keyPassword=$env:SAHIFATI_KEY_PASSWORD"
$content | Out-File -FilePath android/key.properties -Encoding ascii
```

### 10.5 مثال GitHub Actions (snippet) لإعداد المتغيرات وكتابة `key.properties`:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Restore keystore
        run: |
          echo "$KS_BASE64" | base64 --decode > android/UP.Key.jks
        env:
          KS_BASE64: ${{ secrets.SAHIFATI_KEYSTORE_BASE64 }}
      - name: Write key.properties
        run: |
          cat > android/key.properties <<EOF
          storeFile=UP.Key.jks
          storePassword=${{ secrets.SAHIFATI_KEYSTORE_PASSWORD }}
          keyAlias=${{ secrets.SAHIFATI_KEY_ALIAS }}
          keyPassword=${{ secrets.SAHIFATI_KEY_PASSWORD }}
          EOF
```

### 10.6 ملاحظات أمان وعمليات متعلقة بالسرية
- لا تحفظ `FACEBOOK_APP_SECRET` أو أي أسرار خادم في Git. خزنها فقط في مخزن أسرار المنصة (Codemagic secrets, GitHub Secrets, Azure Key Vault, HashiCorp Vault).
- إن اضطررتم أن يكون `agconnect-services.json` خارج repo: خزّنه كمفتاح سرّي واطبع ملف JSON في مسار `android/app/agconnect-services.json` أثناء الـ CI.
- أنتم الآن لديكم بعض القيم الحساسة مخزنة في المستودع (مثال: `android/key.properties`). من المستحسن نقل هذه القيم إلى CI secrets وإزالة الملف من repo أو استبداله بملف مثال (`key.properties.example`).

### 10.7 الإجراءات المطلوبة من قِبلكم
- هل تريدون أن أحذف/أستبدل `android/key.properties` في المستودع وأترك مثالًا؟ (أنصح بنقله إلى CI secrets أولاً.)
- زوّدوني بقيمة `FACEBOOK_APP_SECRET` إذا تريدون إدراجها في هذا المستند (سأضعها في قسم الـ CI secrets فقط، ولن أودعها منفردة في الـ repo).


