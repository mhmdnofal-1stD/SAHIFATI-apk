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
  - `GOOGLE_SERVER_CLIENT_ID` (build script default): `821809289982-m9g7reu9a9vfju911rg3uqg009rr12rp.apps.googleusercontent.com` (انظر `scripts/build_android_release.ps1`)
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
- أين تُستخدم: `scripts/build_android_release.ps1`، وواجهة Flutter على الويب وAndroid، وخلفية التحقق من Apple token.
- الحالة الحالية: تم تأكيد نجاح تجربة Sign in with Apple بعد نشر التصحيح بتاريخ 2026-05-20، وأصبح التدفق يعمل بعد عودة Apple وإرسال التوكن إلى الخلفية بالشكل المتوقع.
- ملاحظة تشغيلية: على Android لا يكفي أن يصل callback إلى `/auth/social/apple/callback`. يجب أن يعيد الخادم Deeplink من نوع `intent://callback ... scheme=signinwithapple` حتى تستلم حزمة `sign_in_with_apple` النتيجة داخل التطبيق. أما على الويب فيبقى الرد HTML relay عبر `postMessage`.
- ملاحظة توافق: endpoint `POST /auth/social/apple` في الخلفية يقبل الآن `idToken` كاسم الحقل الصحيح، ويقبل أيضًا `token` مؤقتًا للتوافق مع عملاء أقدم.

### Huawei (HMS)
- `HUAWEI_APP_ID` = `116918405` (انظر `agconnect-services.json` و build args)
- `agconnect-services.json` محتوى (مقتطفات):
  - `app_id`: `116918405`
  - `package_name`: `org.sahifati.app`
  - `client_id` / `project_id` موجود داخل `client` و `oauth_client`
- أين تُستخدم: المصدر التشغيلي الحقيقي على Android هو `android/app/agconnect-services.json` عبر AG Connect وHMS native SDK. قيمة `--dart-define=HUAWEI_APP_ID` تبقى مفيدة للتوثيق والبناء، لكنها ليست المصدر الوحيد الذي يجب أن يعتمد عليه التطبيق أثناء التشغيل.

### Signing / Keystore
- `frontend_users/ui/android/key.properties`:
  - `storeFile=../../../Public-data-/UP.Key.jks`
  - `keyAlias=upload`
  - `storePassword=<keystore-password-from-secure-store>`
  - `keyPassword=<keystore-password-from-secure-store>`
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
- ملاحظة تشغيلية: بناء `apk` عبر `scripts/build_android_release.ps1` يستهدف الآن `android-arm64` افتراضيًا، ومع بقاء `SplitPerAbi` مفعّلًا تكون الحزمة الناتجة المتوقعة هي `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- رفع على Huawei AppGallery:
  1. سجل دخول إلى AppGallery Connect.
  2. في App / Distribute → Create Release، ارفع `app-release.aab`.
  3. تأكد من أن `package name` و`app id` في AppGallery يطابقان `org.sahifati.app` و`116918405`.
  4. في حال طلبت المراجع أذونات أو توثيق، أرفق لقطات الشاشة ودليل خطوات الاختبار (انظر قسم "ملاحظات المراجع" أدناه).

### 4.1.1 ملاحظة تصحيحية مهمة لخطأ Huawei

- الخطأ `huawei app id is not configured` ظهر لأن طبقة Flutter كانت تعتبر Huawei غير مهيأ إذا غابت قيمة `HUAWEI_APP_ID` الممررة عبر `--dart-define`، حتى لو كان `agconnect-services.json` موجودًا داخل مشروع Android ومهيأ بشكل صحيح.
- هذا الشرط كان أشد من اللازم مقارنةً بالطرف الأصلي: حزمة `huawei_account` وطبقة AG Connect على Android تقرآن `client/app_id` مباشرة من `agconnect-services.json` أثناء التشغيل.
- النتيجة: بعض builds اليدوية أو التشغيل عبر `flutter run` قد يفقد `dart-define` ويظهر الخطأ على جهاز Huawei رغم أن إعداد HMS الفعلي موجود.
- التصحيح المعتمد في الكود: تم إلغاء جعل زر Huawei وتشغيله معتمدين على `dart-define` فقط، وأصبح التمكين على Android يعتمد على وجود المنصة نفسها، بينما تظل ملفات AG Connect هي المصدر التشغيلي الحقيقي.
- ما يجب التحقق منه إذا عاد الخطأ مستقبلًا:
  1. وجود `android/app/agconnect-services.json` داخل الحزمة المستخدمة للبناء.
  2. تطابق `package_name` داخل الملف مع `org.sahifati.app`.
  3. بقاء plugin `com.huawei.agconnect` مفعّلًا في `android/app/build.gradle`.
  4. إن كان البناء يدويًا، فمرّر `HUAWEI_APP_ID` أيضًا حفاظًا على اتساق الوثائق والسجلات، لكن غيابه وحده لا ينبغي أن يعطل Huawei في الواجهة.

صيانة/تحديث:
- لتدوير Upload Key: قم بإنشاء keystore جديد واطلب عبر Huawei/Play Console إجراء رفع مفتاح جديد (اتبع خطوات المنصة). احتفظ بنسخة احتياطية في مكان آمن.
- عند تغيير `app_id` أو `package_name` يجب إعادة إنشاء التكوينات في منصة المطور وتحديث `agconnect-services.json`/console.

### 4.2 Google (Android / Web)

- تأكد من أن SHA1 الصحيح مسجل داخل Google Cloud Console OAuth client المرتبط بـ `GOOGLE_SERVER_CLIENT_ID`.
- لإضافة/تعديل Google client IDs: افتح Google Cloud Console → Credentials → OAuth 2.0 Client IDs.
- تحديث القيم في CI (`codemagic.yaml`) أو pass `--dart-define` عند البناء.
- ملاحظة اعتمادية على الويب: منذ 2026-05-28 صار `web/flutter_bootstrap.js` مخصصا بدون تسجيل service worker، لأن بعض المتصفحات كانت تستمر في تحميل bundle قديم وتُظهر أخطاء social auth من نوع "غير مهيأ" رغم أن قيم Google/Facebook/Apple الصحيحة كانت موجودة في الإصدار الحي. وجود القيم في build لم يعد وحده دليلا كافيا؛ يجب التحقق من أن الصفحة الحمّلت الإصدار الجديد فعلا.

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

### 4.4.1 ملاحظة تصحيحية مهمة لخطأ Apple

- إذا ظهر فشل Apple رغم أن الطلب وصل إلى `POST /auth/social/apple/callback` فهذا لا يعني أن التدفق اكتمل. الوصول إلى callback هو منتصف المسار فقط.
- سبب الفشل الذي ثبت في الشيفرة كان مزدوجًا:
  1. عميل Flutter كان يرسل Apple JWT إلى `POST /auth/social/apple` تحت الحقل `token` بينما الخادم كان يتوقع `idToken`.
  2. callback على Android كان يعيد HTML relay خاصًا بالويب فقط، بينما حزمة `sign_in_with_apple` على Android تتطلب Deeplink راجعًا إلى التطبيق بصيغة `intent://callback?...#Intent;scheme=signinwithapple;...`.
- التصحيح المعتمد:
  1. الواجهة ترسل الآن `idToken` بالاسم الصحيح.
  2. الخلفية تقبل `idToken` و`token` للتوافق العكسي.
  3. redirectUri على Android يضيف `?platform=android`، والخادم يعيد عندها Deeplink Android بدل صفحة `postMessage` الخاصة بالويب.
- النتيجة المؤكدة بعد النشر: التجربة نجحت فعليًا، ما يثبت أن سبب الفشل لم يكن في وصول طلب الربط من Apple بحد ذاته، بل في طبقة ما بعد callback بين شكل البيانات العائدة إلى التطبيق وشكل الحقل الذي تستقبله الخلفية.
- ما يجب التحقق منه إذا عاد الخطأ مستقبلًا:
  1. وجود `APPLE_WEB_CLIENT_ID` و`APPLE_REDIRECT_URI` في build الفعلي.
  2. أن Return URL المسجل في Apple Developer يطابق `https://sahifati.org/api/auth/social/apple/callback`.
  3. أن الحزمة النهائية على Android ما زالت تحتوي `SignInWithAppleCallback` داخل `AndroidManifest.xml`.
  4. أن logs الخادم تبيّن بعد callback طلبًا لاحقًا إلى `POST /auth/social/apple`، لا الاكتفاء برؤية callback وحده.

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

## 6.1 ملاحظة توثيقية مهمة عن موثوقية الحالة

- هذه الوثيقة توثق القيم ومسارات الدمج داخل المشروع، لكنها لا تعتبر وحدها إثباتا نهائيا على أن Google أو Facebook أو Apple في وضع Live وصالحين إنتاجيا.
- النجاح الفعلي على الويب يتطلب ثلاثة شروط معا:
  1. build يحمل القيم الصحيحة.
  2. المتصفح يحمّل الإصدار الأحدث فعلا لا bundle قديما من الكاش.
  3. إعدادات المزود الخارجية نفسها مكتملة وصالحة على الدومين والإصدار الجاري اختباره.
- لذلك أي ادعاء بأن التسجيل "يعمل" يجب أن يسنده اختبار حي بعد النشر، لا الاكتفاء بمطابقة القيم داخل الملفات.

## 6.2 نتيجة التحقق الحي الأخيرة - 2026-05-29

- تم نشر نسخة الويب التي تحتوي `web/flutter_bootstrap.js` الجديد على الإنتاج، وتأكد مباشرة عبر HTTP أن الملف المنشور يستخدم استدعاء تحميل بدون `serviceWorkerSettings` في طبقة bootstrap المخصصة.
- تم التحقق حيًا من عودة صفحة الدخول على `https://sahifati.org/app/#/login` ومن ظهور أزرار `Google`, `Facebook`, `Apple`, `Huawei` على النسخة الحية.
- Google وFacebook بدآ التدفق من الواجهة الحية، لكن جلسة الاختبار المؤتمت نفسها واجهت حجب popup من المتصفح، لذلك لم يُسجل نجاح مصادقة كامل داخل هذه الجلسة.
- Huawei Web ليس مكتملًا على الإنتاج بعد: endpoint `GET /api/auth/social/huawei/start` أعاد `400` برسالة `Huawei web client ID is not configured` قبل محاولة حقن متغيرات البيئة، ثم ثبت لاحقًا من فحص logs أن الخلفية تتطلب أيضًا `HUAWEI_WEB_CLIENT_SECRET` مع `HUAWEI_WEB_CLIENT_ID` و `HUAWEI_WEB_REDIRECT_URI` كحزمة واحدة.
- تم التراجع عن إدخال متغيرات Huawei Web الجزئية بعد أن تسببت في فشل إقلاع الـ API، ثم أُعيد نشر الحزمة واستعادت المنصة حالتها السليمة (`Landing site`, `Flutter web`, `API root`, `Admin UI` كلها عادت `200`).
- بناءً على ذلك، لا يجوز حاليا ختم Google/Facebook/Apple/Huawei بعبارة `تم التحقق حيًا` كنجاح كامل للمصادقة، بل فقط توثيق ما تم التحقق منه فعليًا: النشر، الواجهة الحية، ظهور الأزرار، وبداية بعض التدفقات مع بقاء قيود تشغيلية أو بيئية تمنع الإقرار النهائي بالنجاح.

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
  - `storePassword=<keystore-password-from-secure-store>`
  - `keyPassword=<keystore-password-from-secure-store>`

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


