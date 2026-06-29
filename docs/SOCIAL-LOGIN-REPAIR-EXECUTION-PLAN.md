---

# خطة إصلاح التسجيل والدخول عبر وسائل التواصل (Google / Facebook / Huawei / Apple)

**المشروع:** Sahifati Flutter App — `E:\Sahifati\sahifati_app\sahifati_app_v01`
**أعدّ:** كبير المهندسين (تقرير فحص وتخطيط)
**التاريخ:** 2026-06-23
**الهدف:** ملف تنفيذي يسلّمه موديل تنفيذي لإصلاح توقّف خدمة التسجيل/الدخول الاجتماعي بعد التجارب التي تمت.

---

## 0. كيف تستخدم هذا الملف

- نفّذ المهام بالترتيب من الموجة 1 إلى الموجة 3 (Waves). لا تتجاوز ترتيب الموجات لأن بعض الإصلاحات تعتمد على نتائج أخرى.
- كل مهمة موثّقة بـ: الملف، السطر، المشكلة، الإصلاح المطلوب، وكود مرجعي.
- بعد كل موجة، نفّذ خطوة التحقق (Verification) قبل الانتقال.
- استخدم `flutter analyze` للتحقق من عدم وجود أخطاء بعد التعديلات.
- **لا تلمس ملفات الباك-إند**. كل الإصلاحات في هذا الملف على مستوى تطبيق Flutter + سكربتات البناء/CI فقط. أسئلة الباك-إند مدرجة في قسم "تحقق خارجي" ليعدها المهندس يدوياً مع فريق السيرفر.

---

## 1. ملخّص التشخيص (Root Cause)

خدمة الدخول الاجتماعي توقّفت لأسباب **تراكمية على مستوى الإعداد (Configuration)**، وليست عيباً في منطق الكود. منطق `users_provider.dart` و`users_services.dart` و`social_auth_action.dart` سليم ومنظّم. الخلل في ثلاث طبقات إعداد:

| # | المشكلة | الموقع | الأثر |
|---|---------|--------|-------|
| B1 | `SocialAuthConfig.initialize()` **لا يتم استدعاؤها إطلاقاً** في `main.dart` | `lib/main.dart` (لا يوجد استدعاء) | كل الحقول الديناميكية (`googleWebClientId`, `appleWebClientId`, `appleRedirectUri`, `facebookAppId`, `huaweiWebClientId`, `huaweiWebRedirectUri`) تبقى فارغة `''` طوال عمر التطبيق → كل فحوص `isXxxConfiguredForCurrentPlatform` ترجع `false` → أزرار الدخول الاجتماعي **لا تُعرض أصلاً** (تُرجع `SizedBox.shrink()`) |
| B2 | ملف `assets/config/auth_config.json` **مُستبدل بقيم وهمية/placeholder** | `assets/config/auth_config.json` | حتى لو استُدعيت `initialize()`، القيم غير صالحة: `GOOGLE_WEB_CLIENT_ID` = `"://googleusercontent.com"` (مبتور)، والبقية نصوص مثل `"your-apple-service-id"` و`"your-facebook-app-id"` |
| B3 | سكربت النشر `.github/workflows/deploy-web.yml` **يحقن نفس القيم المبتورة** + redirect URIs ناقصة `/api` | `.github/workflows/deploy-web.yml` السطور 34-44 | بناء الويب للإنتاج مكسور؛ Google web client ID مبتور، و`APPLE_REDIRECT_URI`/`HUAWEI_WEB_REDIRECT_URI` = `https://sahifati.org/auth/social/.../callback` بينما المسار الصحيح يتضمّن `/api` |
| B4 | سباق تنافس (race condition) في زر Google على الويب | `lib/screens/authentication_screens/widgets/google_web_button_adapter_web.dart` السطور 52-63 | `prompt()` callback يُكمل الـ future بخطأ "cancelled" عند أول `PromptMomentNotification` (لحظة العرض نفسها) قبل أن يصل `callback` بالاعتماد → المستخدم يرى "تم الإلغاء" فوراً |
| B5 | احتمال عدم تطابق شكل استجابة الباك-إند مع `AuthData.fromJson` | `lib/models/auth_data.dart` السطور 14-30 + `lib/providers/users_provider.dart` السطور 1347-1353 | لو الباك-إند يُرجع `{accessToken, refreshToken, user:{...}}` بدون `id`/`username` بمستوى الجذر، فـ`AuthData.user == null` → `finalizeAuthenticatedUser` يرمي `SOCIAL_AUTH_INVALID_RESPONSE`. تحقق خارجي مطلوب |
| B6 | كود حالة HTTP: يقبل `200` فقط لكل نقاط النهاية الاجتماعية | `lib/services/users_services.dart` السطور 310, 335, 360, 385 | لو الباك-إند يُرجع `201 Created` للتسجيل الاجتماعي الجديد، يُعتبر فشلاً صامتاً. تحقق خارجي |

**ملاحظة:** الحقلان `googleServerClientId` و`huaweiAppId` يأتيان من `String.fromEnvironment` (وقت البناء) لذلك يعمل Google/Huawei على أندرويد عند البناء الصحيح عبر `scripts/build-aab-release.ps1` (الذي يستخدم `tool/build_config.json`). هذا يفسّر "النجاح في التجارب" على أندرويد بينما بقية المنصّات/المزوّدات مكسورة.

**القيم الصحيحة موجودة** في `tool/build_config.json` (مصدر الحقيقة الموحّد) لكنها لم تُنسخ إلى `auth_config.json` ولا إلى `deploy-web.yml`.

---

## 2. خريطة الملفات المعنيّة (File Reference)

### كود Flutter (موقع الخلل الأساسي)
- `lib/main.dart` — **لا يستدعي `SocialAuthConfig.initialize()`** (موقع الإصلاح B1)
- `lib/core/auth/social_auth_config.dart` — يعرّف `initialize()` (السطور 23-40) لكنه لا يُستدعى؛ الحقول الفارغة (7-20)؛ الفحوص (42-73)
- `lib/core/constants/api.dart` — الـ base URL سليم (يضيف `/api` تلقائياً) — منخفض الخطورة
- `lib/providers/users_provider.dart` — منطق الدخول الاجتماعي كامل (يستخدم فحوص الإعداد)
- `lib/services/users_services.dart` — نقاط نهاية HTTP الاجتماعية (السطور 299-435)
- `lib/models/auth_data.dart` — تحليل JSON الاستجابة
- `lib/screens/authentication_screens/social_auth_action.dart` — `buildSocialSection` (السطور 273-302) يُرجع `SizedBox.shrink()` إن كانت `controls` فارغة
- `lib/screens/authentication_screens/widgets/google_web_button_adapter_web.dart` — سباق `prompt()` (B4)

### ملفات الإعداد/البناء
- `assets/config/auth_config.json` — **قيم وهمية** (موقع الإصلاح B2)
- `tool/build_config.json` — **القيم الصحيحة** (مصدر الحقيقة)
- `tool/generate_flutter_defines.dart` — مولّد الـ `--dart-define`
- `.github/workflows/deploy-web.yml` — **قيم مبتورة + URIs ناقصة `/api`** (موقع الإصلاح B3)
- `scripts/build-aab-release.ps1` — يستخدم `tool/build_config.json` (سليم)
- `scripts/run-web-dev.ps1` — يستخدم `tool/build_config.json` (سليم)

### ملفات Native (للتحقق فقط، لا تعديل مطلوب غالباً)
- `android/app/src/main/AndroidManifest.xml` — سليم
- `android/app/src/main/res/values/strings.xml` — `facebook_app_id=824178674089653` سليم
- `android/app/agconnect-services.json` — Huawei سليم (`app_id=116918405`)
- `ios/Runner/Info.plist` — Facebook scheme موجود؛ **تأكّد من Google URL scheme**
- `ios/Runner/Runner.entitlements` — Apple Sign-In entitlement موجود
- `ios/Runner/GoogleService-Info.plist` — موجود
- **مفقود:** `android/app/google-services.json` — مطلوب لـ FCM على أندرويد

---

## 3. خطة التنفيذ (Execution Plan)

### الموجة 1 (Wave 1) — إصلاحات أساسية مستقلة (موازية)

هذه المهام الثلاث مستقلة عن بعضها وتلامس ملفات مختلفة، فتنفّذ **بالتوازي**:

---

#### المهمة W1-T1: استدعاء `SocialAuthConfig.initialize()` في `main.dart` (إصلاح B1)

**الملف:** `lib/main.dart`

**المشكلة:** الدالة `SocialAuthConfig.initialize()` (المعرّفة في `lib/core/auth/social_auth_config.dart` السطور 23-40) تُحمّل القيم من `assets/config/auth_config.json`، لكن `main()` (السطور 54-135) لا تستدعيها إطلاقاً. نتيجة لذلك تبقى كل الحقول الديناميكية فارغة وتُرجع كل فحوص `isXxxConfiguredForCurrentPlatform` القيمة `false` فلا تُعرض أزرار الدخول الاجتماعي.

**الإصلاح المطلوب:**

1. أضف استيراد `social_auth_config.dart` في أعلى الملف ضمن مجموعة استيرادات `core/auth/...` (تقريباً بعد السطر 13):
```dart
import 'core/auth/social_auth_config.dart';
```

2. داخل `main()`، بعد كتلة typography الـ try/catch (تقريباً بعد السطر 79) وقبل إنشاء `TypographyConfigController`، أضف كتلة تهيئة مستقلة بنفس نمط try/catch الدفاعي المستخدم في بقية الإعدادت:
```dart
  // تهيئة إعدادات الدخول الاجتماعي من ملف الإعداد الديناميكي.
  // يجب أن تسبق runApp حتى تظهر أزرار الدخول الاجتماعي على شاشات الـ login/signup.
  try {
    await SocialAuthConfig.initialize();
  } catch (error, stackTrace) {
    debugPrint(
      'Startup social auth config initialization failed: $error\n$stackTrace',
    );
  }
```

**ملاحظة:** الدالة `initialize()` تبتلع أخطاءها داخلياً (السطور 36-39) وتطبع debugPrint فقط، لذلك لن ينهار التطبيق لو فشل تحميل JSON. الـ try/catch الإضافي هنا احتياط إضافي فقط ويُتّسق مع نمط باقي إعدادت الـ startup.

**التحقق:** بعد التعديل، `flutter analyze` يجب أن يمرّ بدون أخطاء. تأكّد أن الاستيراد يحلّ الرمز `SocialAuthConfig`.

---

#### المهمة W1-T2: استعادة القيم الصحيحة في `assets/config/auth_config.json` (إصلاح B2)

**الملف:** `assets/config/auth_config.json`

**المشكلة:** الملف الحالي يحتوي قيماً وهمية/مبتورة:
```json
{
  "GOOGLE_WEB_CLIENT_ID": "://googleusercontent.com",
  "APPLE_WEB_CLIENT_ID": "your-apple-service-id",
  "APPLE_REDIRECT_URI": "https://sahifati.org",
  "FACEBOOK_APP_ID": "your-facebook-app-id",
  "HUAWEI_WEB_CLIENT_ID": "your-huawei-client-id",
  "HUAWEI_WEB_REDIRECT_URI": "https://sahifati.org"
}
```

**الإصلاح المطلوب:** استبدل كامل محتوى الملف بالقيم الصحيحة المسحوبة من `tool/build_config.json` (مصدر الحقيقة الموحّد). اكتب الملف بهذا المحتوى بالضبط:
```json
{
  "GOOGLE_WEB_CLIENT_ID": "999583607802-m45lh6bbjmt4teb6m77uk7dfvp50crk7.apps.googleusercontent.com",
  "APPLE_WEB_CLIENT_ID": "org.sahifati.app.signin",
  "APPLE_REDIRECT_URI": "https://sahifati.org/api/auth/social/apple/callback",
  "FACEBOOK_APP_ID": "824178674089653",
  "HUAWEI_WEB_CLIENT_ID": "116918405",
  "HUAWEI_WEB_REDIRECT_URI": "https://sahifati.org/api/auth/social/huawei/callback"
}
```

**التحقق:** قارن قيم كل حقل مع `tool/build_config.json` (السطور 5-13). يجب أن تتطابق تماماً. لاحظ أن `APPLE_REDIRECT_URI` و`HUAWEI_WEB_REDIRECT_URI` يجب أن تتضمّن `/api` (المسار الكامل: `/api/auth/social/.../callback`).

---

#### المهمة W1-T3: إصلاح سباق `prompt()` في زر Google على الويب (إصلاح B4)

**الملف:** `lib/screens/authentication_screens/widgets/google_web_button_adapter_web.dart`

**المشكلة:** في الدالة `requestGoogleWebAccessToken` (السطور 25-66)، الـ `prompt()` callback (السطور 53-63) يُكمل الـ future بخطأ `SOCIAL_LOGIN_CANCELLED` عند **أي** `PromptMomentNotification`، بما في ذلك لحظة العرض الأولى (display moment). هذا يعني أن المستخدم يرى "تم الإلغاء" فوراً قبل أن يتمكن `callback` (السطور 35-48) من تسليم الاعتماد. هذا سباق تنافس: لو وصل `prompt` قبل `callback` يُنهي الـ completer بخطأ.

**الإصلاح المطلوب:** عدّل كتلة `prompt()` (السطور 53-63) لتُكمل بخطأ "cancelled" **فقط** عند الحالات الفعلية للإلغاء/الإخفاء/التخطّي، وليس عند كل notification. استبدل السطور 52-63 بالتالي:
```dart
  // [تم الإصلاح] استخدام فلو آمن للنافذة المنبثقة: لا نُلغي إلا عند الإشارات
  // الصريحة من الـ SDK بأن النافذة لم تُعرض أو تم تخطّيها أو إغلاقها.
  gis_id.id.prompt((gis_id.PromptMomentNotification notification) {
    if (completer.isCompleted) return;
    // نُكمل بخطأ الإلغاء فقط عند الحالات الفعلية للإخفاء/التخطّي،
    // وليس عند لحظة العرض (display) التي تُطلق دائماً عند الفتح.
    if (notification.isNotDisplayed() || notification.isSkippedMoment()) {
      completer.completeError({
        'errorCode': 'SOCIAL_LOGIN_CANCELLED',
        'provider': 'google',
        'message': 'social_cancelled'.tr
      });
    }
  });
```

**ملاحظة عن الـ API:** راجع توثيق `google_identity_services_web` للتأكد من أسماء الـ getters على `PromptMomentNotification`. في إصدار ^0.3.3+1 المتوفّر، الـ getters المتاحة عادة: `isDisplayed()`, `isNotDisplayed()`, `isSkippedMoment()`, `isDisplayingMoment()`, `isDismissed()`. لو اختلفت الأسماء الفعلية في الحزمة المثبتة، استخدم المكافئ الأقرب (مثل التحقق عبر `notification.getMomentType()` إن وُجد). الهدف: لا تُكمل الـ future بخطأ إلا عند الإلغاء/الإخفاء الحقيقي وليس عند لحظة العرض.

**التحقق:** `flutter analyze` بدون أخطاء. اختبر يدوياً: زر Google على الويب يجب أن يفتح النافذة ويبقى مفتوحاً حتى يختار المستخدم حساباً أو يُغلقه فعلياً.

---

### الموجة 2 (Wave 2) — إصلاح CI + توحيد مصدر الإعداد

تعتمد هذه على نجاح الموجة 1 (للتأكد أن `auth_config.json` صار صحيحاً قبل توحيد المصدر). تنفّذ بالتوازي حيث تلامس ملفات مختلفة:

---

#### المهمة W2-T1: إصلاح `deploy-web.yml` (إصلاح B3)

**الملف:** `.github/workflows/deploy-web.yml`

**المشكلة:** كتلة `--dart-define` (السطور 34-44) تحتوي:
- `GOOGLE_WEB_CLIENT_ID="://googleusercontent.com"` و`GOOGLE_SERVER_CLIENT_ID="://googleusercontent.com"` — **مبتورة/غير صالحة**.
- `API_BASE_URL="https://sahifati.org"` — ناقصة `/api` (رغم أن `api.dart` يضيفها تلقائياً، لكن النية خاطئة).
- `APPLE_REDIRECT_URI="https://sahifati.org/auth/social/apple/callback"` — ناقص `/api`.
- `HUAWEI_WEB_REDIRECT_URI="https://sahifati.org/auth/social/huawei/callback"` — ناقص `/api`.

ملاحظة: الـ `--dart-define` للحقول الديناميكية (`GOOGLE_WEB_CLIENT_ID`, `APPLE_WEB_CLIENT_ID`, `FACEBOOK_APP_ID`, `HUAWEI_WEB_CLIENT_ID`, `HUAWEI_WEB_REDIRECT_URI`, `APPLE_REDIRECT_URI`) **لا تؤثر فعلياً** لأن `social_auth_config.dart` لا يقرأها عبر `String.fromEnvironment` (هي تُحمّل من JSON فقط عبر `initialize()`). لكنها مضلّلة ويجب تصحيحها أو إزالتها لمنع الانطباع الخاطئ بأنها تعمل. الحقلان `GOOGLE_SERVER_CLIENT_ID` و`HUAWEI_APP_ID` **يؤثّران فعلياً** (يُقرآن عبر `fromEnvironment`).

**الإصلاح المطلوب (خياران — نفّذ الخيار A أولاً؛ إن تعذّر فالخيار B):**

**الخيار A (موصى به — توحيد المصدر):** استبدل كتلة الـ `--dart-define` المكتوبة يدوياً (السطور 34-44) بمولّد الـ defines الموحّد الذي يستخدمه سكربت الأندرويد. استبدل خطوة الـ build (السطور 31-44) بالتالي:
```yaml
      - name: Generate Flutter Defines from build_config.json
        run: dart run tool/generate_flutter_defines.dart --profile=release

      - name: Build Flutter Web
        run: |
          # المعرّفات تُولّد من tool/build_config.json لضمان تطابقها مع بناء الأندرويد/iOS
          # يُفترض أن المولّد يكتب الـ defines إلى ملف أو متغير بيئة يُستخدم هنا
          flutter build web --release --base-href "/app/" $(cat tool/flutter_defines.txt)
```
ملاحظة: راجع `tool/generate_flutter_defines.dart` لتحديد آلية إخراجه الفعلية (هل يكتب إلى ملف `tool/flutter_defines.txt`؟ أم يطبع على stdout؟ أم يضعها في env?). عدّل خطوة الـ shell أعلاه لتتوافق مع آلية المولّد الفعلية. الهدف النهائي: **عدم تكرار القيم يدوياً في الـ workflow**، بل توليدها من `tool/build_config.json` بنفس الطريقة التي يستخدمها `scripts/build-aab-release.ps1`.

**الخيار B (إن تعذّر الخيار A):** صحّح القيم يدوياً في السطور 34-44 لتطابق `tool/build_config.json` بالضبط:
```yaml
          flutter build web --release --base-href "/app/" \
            --dart-define=API_BASE_URL="https://sahifati.org/api" \
            --dart-define=GOOGLE_WEB_CLIENT_ID="999583607802-m45lh6bbjmt4teb6m77uk7dfvp50crk7.apps.googleusercontent.com" \
            --dart-define=GOOGLE_SERVER_CLIENT_ID="999583607802-pnju3l7iu58tfb2a8v8oiacuajsduqo0.apps.googleusercontent.com" \
            --dart-define=APPLE_WEB_CLIENT_ID="org.sahifati.app.signin" \
            --dart-define=APPLE_REDIRECT_URI="https://sahifati.org/api/auth/social/apple/callback" \
            --dart-define=FACEBOOK_AUTH_ENABLED="true" \
            --dart-define=FACEBOOK_APP_ID="824178674089653" \
            --dart-define=HUAWEI_APP_ID="116918405" \
            --dart-define=HUAWEI_WEB_CLIENT_ID="116918405" \
            --dart-define=HUAWEI_WEB_REDIRECT_URI="https://sahifati.org/api/auth/social/huawei/callback"
```
أيضاً أزل/صحّح التعليق المضلّل "تم الإصلاح جذرياً... حقن المعرّفات الجديدة الصحيحة" على السطر 33 لأنه لم يكن صحيحاً.

**التحقق:** افتح الملف وتأكّد أن كل قيمة تطابق `tool/build_config.json`. تأكّد أن الـ redirect URIs تتضمّن `/api/auth/social/.../callback`.

---

#### المهمة W2-T2 (اختياري لكن موصى به): توحيد معمارية مصدر الإعداد

**الملفات:** `lib/core/auth/social_auth_config.dart` + `tool/build_config.json` + `.github/workflows/deploy-web.yml` + `scripts/*.ps1`

**المشكلة الهيكلية:** يوجد مصدران متنافسان للإعداد:
- بعض الحقول من `String.fromEnvironment` (وقت البناء): `googleServerClientId`, `huaweiAppId`, `facebookAuthEnabled`, `facebookApiVersion`.
- باقي الحقول من `auth_config.json` (وقت التشغيل عبر `initialize()`): `googleWebClientId`, `appleWebClientId`, `appleRedirectUri`, `facebookAppId`, `huaweiWebClientId`, `huaweiWebRedirectUri`.

هذا الانقسام هو **السبب الجذري** لكل الخلل: الـ `--dart-define` للحقول الديناميكية لا يؤثر، والـ JSON لم يُحمّل. الـ `initialize()` الذي أضيف كـ "تجربة ديناميكية" لم يُوصّل أبداً.

**القرار الموصى به (اختر واحداً ونفّذه):**

- **القرار A (موصى به — أبسط وأقل تغييراً):** اترك `initialize()` كمصدر للحقول الديناميكية (لأنه يعمل بعد الموجة 1)، وأضف `String.fromEnvironment` **كقيمة ابتدائية (fallback)** لكل حقل ديناميكي في `social_auth_config.dart` بحيث لو وُجد `--dart-define` يُستخدم، و`initialize()` يُغطّيه فقط إن أتى بقيمة غير فارغة من JSON. مثال للحقل:
```dart
  static String googleWebClientId =
      const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');
```
ثم في `initialize()` (السطر 28) غيّر إلى:
```dart
      final jsonVal = config['GOOGLE_WEB_CLIENT_ID'] ?? '';
      if (jsonVal.isNotEmpty) googleWebClientId = jsonVal;
```
كرّر هذا النمط لكل الحقول الديناميكية الست. هذا يجعل كلا المصدرين يعملان بانسجام: `--dart-define` يوفّر قيمة افتراضية وقت البناء، والـ JSON يُغطّيها وقت التشغيل لو كان غير فارغ. وبالتالي حتى لو نُسي `initialize()` يوماً، تعمل القيم من البناء.

- **القرار B (أكثر جذرية):** احذف الـ JSON-loader بالكامل وحوّل كل الحقول الست إلى `String.fromEnvironment`، واحذف `auth_config.json` و`initialize()`. لكن هذا يُلغي ميزة "التعديل بعد التحميل" التي قصدها صاحب التجربة.

**نفّذ القرار A** لأنه يحقّق متانة أعلى مع أقل اضطراب.

**التحقق:** `flutter analyze`. تأكّد أن `initialize()` لا يزال يعمل. تأكّد أن بناءً بـ `--dart-define=GOOGLE_WEB_CLIENT_ID=...` يضع القيمة حتى دون استدعاء `initialize()`.

---

### الموجة 3 (Wave 3) — تحقّقات خارجية + ملفات native (لا تعتمد على الموجات السابقة برمجياً لكنها منطقياً بعد الإصلاح)

هذه مهام تحقق/إصلاح على مستوى السيرفر والملفات الـ native. **لا تلمس الباك-إند من تلقاء نفسك** — أعدّها كقائمة تحقق ونسّقها مع فريق السيرفر إن لزم.

---

#### المهمة W3-T1: التحقق من شكل استجابة الباك-إند + كودات الحالة (إصلاح B5 + B6)

**المسؤول:** المهندس + فريق الباك-إند (تحقق يدوي).

1. **كود الحالة:** راجع نقاط النهاية على السيرفر:
   - `POST /auth/social/google`
   - `POST /auth/social/facebook`
   - `POST /auth/social/apple`
   - `POST /auth/social/huawei`
   
   تأكّد أنها تُرجع **`200`** في كل من الدخول والتسجيل الجديد (وليس `201` للتسجيل). لو تُرجع `201` للتسجيل، عدّل الفحوص في `lib/services/users_services.dart` السطور 310, 335, 360, 385 لتقبل `200` أو `201`:
   ```dart
   if (response.statusCode == 200 || response.statusCode == 201) {
   ```
   كرّر للدوال الأربع `loginWithGoogle`, `loginWithFacebook`, `loginWithApple`, `loginWithHuawei`.

2. **شكل JSON:** تأكّد أن استجابة الباك-إند لكل نقطة نهاية اجتماعية **تتضمّن** إما:
   - (a) حقلاً بمستوى الجذر اسمه `id` أو `username` + حقل `token` (الشكل الذي تطبّعه `AuthData.fromJson` السطور 16-23)، **أو**
   - (b) شكلاً `{ "accessToken": "...", "refreshToken": "...", "user": { "id": ..., ... } }` — وفي هذه الحالة **يجب تحديث `AuthData.fromJson`** (السطور 14-30 في `lib/models/auth_data.dart`) لتقرأ `user` من `json['user']` وتقرأ التوكين من `json['accessToken']` في نفس الفرع. مثال إصلاح:
   ```dart
   factory AuthData.fromJson(Map<String, dynamic> json) {
     User? userData;
     if (json.containsKey('id') || json.containsKey('username')) {
       userData = User.fromJson(json);
       return AuthData(
           accessToken: json['token'],
           refreshToken: json['refreshToken'],
           user: userData);
     }
     if (json.containsKey('user') && json['user'] is Map<String, dynamic>) {
       userData = User.fromJson(json['user'] as Map<String, dynamic>);
       return AuthData(
         accessToken: json['accessToken'] ?? json['token'],
         refreshToken: json['refreshToken'],
         user: userData,
       );
     }
     return AuthData(
       accessToken: json['accessToken'],
       refreshToken: json['refreshToken'],
     );
   }
   ```
   **قارن** شكل استجابة الدخول بالبريد/كلمة المرور (الذي يعمل) مع شكل الدخول الاجتماعي لتتأكد أن كليهما يُحلّ بنفس الفرع الصحيح في `AuthData.fromJson`. لو اختلف الشكل، حدّث `AuthData.fromJson` ليعالج كلا الشكلين (كما في المثال أعلاه).

3. **توثيق:** بعد التحقق، سجّل النتيجة في تعليق قصير أعلى `lib/services/users_services.dart` أو في `docs/`.

---

#### المهمة W3-T2: التحقق من متغيّرات بيئة السيرفر (B3-مكمّل)

**المسؤول:** فريق السيرفر (تحقق يدوي عبر المهندس).

تأكّد أن متغيّرات البيئة التالية على خادم الإنتاج `sahifati.org` **ما زالت موجودة ولم تُحذف أثناء التجارب**:
- `FACEBOOK_APP_SECRET`
- `HUAWEI_WEB_CLIENT_SECRET`
- `HUAWEI_WEB_CLIENT_ID` = `116918405`
- `HUAWEI_WEB_REDIRECT_URI` = `https://sahifati.org/api/auth/social/huawei/callback` (تأكّد `/api`)
- مفاتيح Apple: مفتاح الخصوصية (private key)، `KEY_ID`، `TEAM_ID`، و`APPLE_WEB_CLIENT_ID` = `org.sahifati.app.signin`
- `APPLE_REDIRECT_URI` على السيرفر = `https://sahifati.org/api/auth/social/apple/callback` (تأكّد `/api`)

راجع `docs/platform-integration-reference-2026-05-20.md` و`docs/social-login-platform-status-2026-05-12.md` كمرجع لما كان يعمل.

---

#### المهمة W3-T3: التحقق من ملفات Native (منخفض الأولوية لكن مكتمل للتوثيق)

**الملفات:** `android/` و`ios/`

1. **أندرويد `google-services.json`:** الملف `android/app/google-services.json` **مفقود**. لو `firebase_messaging` (FCM) لا يعمل على أندرويد، هذا هو السبب. راجع مشروع Firebase `sahifati-1st-dim` على Google Cloud Console ونزّل `google-services.json` وضعه في `android/app/`. تأكّد أن الـ package name = `org.sahifati.app` وأن الـ SHA-1 المسجّل (`6F:DA:D4:C7:24:28:5A:F5:E3:A7:94:8B:00:4C:E3:81:D6:87:71:50` حسب `docs/platform-integration-reference-2026-05-20.md` السطر 66) مُسجّل على OAuth client الخاص بـ `GOOGLE_SERVER_CLIENT_ID`. ملاحظة: Google Sign-In على أندرويد 7.x قد يعمل بدون `google-services.json` لو `serverClientId` صحيح (وهو يأتي من `--dart-define`)، لكن FCM يحتاج الملف.

2. **iOS Google URL scheme:** راجع `ios/Runner/Info.plist` — تأكّد من وجود `REVERSED_CLIENT_ID` (نمط `com.googleusercontent.apps.<numeric>-...`) ضمن `CFBundleURLTypes` لو كان مكوّن Google Sign-In 7.x على iOS يتطلبه. راجع توثيق `google_sign_in` 7.2.0. لو كان مطلوباً ومفقوداً، أضفه. (الأرجح أن 7.x يعتمد على `GoogleService-Info.plist` الموجود، لكن يُستحسن التأكيد بالاختبار.)

3. **iOS Facebook:** موجود سليم (`FacebookAppID=824178674089653` و`FacebookClientToken` وscheme `fb824178674089653`).

4. **Huawei:** `agconnect-services.json` سليم (`app_id=116918405`)، وplugin `com.huawei.agconnect` مفعّل في `android/app/build.gradle`.

**ملاحظة أمان:** ملف `agconnect-services.json` مُدرج في الـ repo ويحتوي `client_secret` — يُستحسن نقله إلى CI حسب توثيق `docs/platform-integration-reference-2026-05-20.md` القسم 10. ليس خللاً وظيفياً لكنه مصدّ أمني.

---

## 4. سيناريو التحقق النهائي (بعد كل الموجات)

بعد إكمال الموجات 1 و 2، نفّذ الاختبارات التالية لتأكيد الإصلاح:

### على الويب (`flutter run -d chrome` أو بعد deploy-web):
1. افتح صفحة `/login`. تأكّد أن **أزرار Google + Facebook + Apple + Huawei كلها ظاهرة** (ليست `SizedBox.shrink()`).
2. اضغط زر Google → يجب أن تفتح نافذة GIS المنبثقة وتبقى مفتوحة حتى تختار حساباً (لا تُلغى فوراً).
3. اختر حساباً → يجب أن يصل الـ idToken إلى `signInWithGoogleIdToken` ويتم تبديله مع الباك-إند بنجاح وينتقل المستخدم لشاشة ما بعد الدخول.
4. اختبر Facebook → يجب أن يفتح OAuth flow ويعود بالـ access token.
5. اختبر Apple → يجب أن يفتح Apple Sign-In ويعود بالـ identityToken.
6. اختبر Huawei → يجب أن يفتح Huawei OAuth redirect ويعود.

### على أندرويد (بعد بناء صحيح بـ `scripts/build-aab-release.ps1`):
1. تأكّد ظهور أزرار Google + Huawei (Apple/Facebook على أندرويد يعتمدان على `initialize()` الآن بعد الموجة 1، فيجب أن يظهران أيضاً).
2. اختبر Google و Huawei (يعتمدان على `--dart-define` الصحيح الذي يوفّره `tool/build_config.json`).
3. اختبر Facebook و Apple (بعد الموجة 1، القيم تأتي من JSON المُصلّح).

### فحوص `flutter analyze`:
- بعد كل تعديل: `flutter analyze` يجب أن يمرّ بدون أخطاء (warnings مقبولة لكن يجب مراجعتها).

### فحص سجل التشخيص:
- عند الإقلاع يجب أن يظهر في الـ debug log: `Social Auth Config loaded successfully from JSON.` (من `initialize()` السطر 35). لو ظهر `Failed to load dynamic social auth config:` فهناك مشكلة في `auth_config.json` (تنسيق/مسار).

---

## 5. ملخّص الإصلاحات بترتيب التنفيذ

| الموجة | المهمة | الملف | النوع |
|--------|--------|------|------|
| W1 | T1 | `lib/main.dart` | إضافة استدعاء `SocialAuthConfig.initialize()` |
| W1 | T2 | `assets/config/auth_config.json` | استبدال القيم الوهمية بالقيم الصحيحة من `tool/build_config.json` |
| W1 | T3 | `lib/screens/authentication_screens/widgets/google_web_button_adapter_web.dart` | إصلاح سباق `prompt()` |
| W2 | T1 | `.github/workflows/deploy-web.yml` | تصحيح `--dart-define` (أو توحيدها عبر `tool/generate_flutter_defines.dart`) |
| W2 | T2 | `lib/core/auth/social_auth_config.dart` | توحيد مصدر الإعداد (fallback `fromEnvironment` + JSON overlay) |
| W3 | T1 | `lib/services/users_services.dart` + `lib/models/auth_data.dart` | تحقق/إصلاح كود الحالة + شكل JSON (مع فريق السيرفر) |
| W3 | T2 | (سيرفر) | التحقق من متغيّرات بيئة السيرفر |
| W3 | T3 | `android/app/google-services.json` + `ios/Runner/Info.plist` | ملفات native (منخفض الأولوية) |

**أولوية قصوى:** W1-T1 + W1-T2 هي الإصلاحان اللذان يُعيدان ظهور الأزرار وعمليّة الدخول الاجتماعي. هما مسؤول عن ~90% من الخلل. باقي المهام تحسين ومتانة وتحقق.

---

## 6. ملاحظات للموديل التنفيذي

- ابدأ بالموجة 1 فوراً. الموجة 1 وحدها (T1 + T2) كافية لإعادة خدمة الدخول الاجتماعي للعمل على الويب وكل المنصّات.
- W1-T3 مهم لـ Google على الويب تحديداً (بدونه يُلغى فوراً).
- W2-T2 (توحيد المصدر) هو إصلاح جوهري لمنع تكرار الخلل مستقبلاً — نفّذه حتى لو بدا اختيارياً.
- W3-T1 يتطلب فريق السيرفر. لو لم تستطع التحقق من شكل استجابة الباك-إند، أضف معالجة دفاعية في `AuthData.fromJson` (كما في مثال W3-T1) لتقبل الشكلين معاً — هذا آمن ولا يكسر شيئاً.
- لا تنسَ `flutter analyze` بعد كل تعديل.
- احتفظ بنسخة احتياطية قبل التعديل (git commit/stash) إن أمكن.

---

*نهاية الخطة — جاهزة للتسليم للموديل التنفيذي.*

---