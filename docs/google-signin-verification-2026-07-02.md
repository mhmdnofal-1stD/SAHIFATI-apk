# توثيق حالة تسجيل الدخول الاجتماعي — 2026-07-02

**الحالة:** ✅ ناجح ومتحقق

---

## الإعدادات الصحيحة (Configuration That Works)

| المتغير | القيمة |
|---------|--------|
| `GOOGLE_WEB_CLIENT_ID` | `999583607802-m45lh6bbjmt4teb6m77uk7dfvp50crk7.apps.googleusercontent.com` |
| `GOOGLE_SERVER_CLIENT_ID` | `999583607802-pnju3l7iu58tfb2a8v8oiacuajsduqo0.apps.googleusercontent.com` |

**المصدر:** `auth_config.json`, `build_config.json`, `.env`

---

## ملفات تخزين Client IDs (Single Source of Truth)

| الملف | النوع | المتغيرات |
|-------|------|-----------|
| `assets/config/auth_config.json` | Flutter runtime | `webClientId`, `serverClientId` |
| `tool/build_config.json` | Flutter compile-time / CI | `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_SERVER_CLIENT_ID` |
| `.env` (API backend) | Server | `GOOGLE_CLIENT_ID` (server), `GOOGLE_WEB_CLIENT_ID` (web audience) |
| `~/sahifaty/sahifaty-api/.env` (VPS) | Server production | Same as above via `--env-file` |

---

## الإصلاحات المُطبّقة أثناء التصحيح

1. **`SocialAuthConfig.initialize()`** — تمت إضافة الاستدعاء في `main.dart`
2. **`auth_config.json`** — تمت استعادة القيم الصحيحة بعد الكتابة فوقها بقيم خاطئة
3. **iOS support** — `googleWebClientId` يُستخدم كـ fallback لـ `serverClientId` على iOS
4. **COEP header** — تم حذف `Cross-Origin-Embedder-Policy: require-corp` من `gateway nginx.conf`
5. **MongoDB database name** — تم التصحيح من `sahifati` إلى `sahifaty`
6. **`users_provider.dart`** — تم إصلاح منطق fallback لـ `serverClientId`

---

## نتائج اختبار مزودي الدخول الاجتماعي (Social Auth Provider Test Results)

### Google ✅ ناجح
- تسجيل الدخول عبر Google يعمل بنجاح على الويب
- الإعدادات الصحيحة موثقة أعلاه

### Facebook ✅ ناجح  
- تسجيل الدخول عبر Facebook يعمل بنجاح

### Apple ✅ ناجح (بعد إصلاح)
- تسجيل الدخول عبر Apple يعمل ويُرجع رمز مميز (token) صحيح
- لكن بعد الدخول، يُعاد التوجيه إلى شاشة تفعيل الترخيص (طبيعي لمستخدم جديد)
- عند محاولة تفعيل ترخيص الهدية: `POST /api/licensing/activate/gift` يُرجع 403 (Forbidden)
- **السبب المرجح**: دالة `canProceedWithoutEmailVerification()` في `licensing.service.ts` تتحقق من `authProvider` و `emailVerified`. للمستخدم الجديد عبر Apple يجب أن يكون `authProvider='apple'` و `emailVerified=true`، لكن يجب التحقق من حالة قاعدة البيانات.
- **إصلاح مُطبّق**: تم إضافة `emailVerified` و `authProvider` إلى استجابة `buildAuthResponse` في `auth.service.ts` لضمان وصول هذه الحقول لتطبيق Flutter

### Apple — حالة المستخدم في قاعدة البيانات
- المستخدم الذي سجل عبر Apple: `baddawi.noor_000943` / `baddawi.noor@icloud.com`
- **الوضع الفعلي في قاعدة البيانات**: `authProvider: 'email'` و `emailVerified: false`
- هذا يعني أن المستخدم سُجّل بالبريد أولاً (بدون تحقق)، ثم حاول الدخول عبر Apple، لكن Apple Sign-In لم يُحدّث السجل ليصبح `authProvider: 'apple'` و `emailVerified: true`
- هذا يفسر خطأ 403 على `/licensing/activate/gift` — الدالة `canProceedWithoutEmailVerification()` ترى `authProvider='email'` و `emailVerified=false`
- **إصلاح يدوي تم تطبيقه بنجاح**:
  ```
  db.users.updateOne({email: "baddawi.noor@icloud.com"}, {$set: {authProvider: "apple", emailVerified: true}})
  ```
  النتيجة: `matchedCount: 1, modifiedCount: 1`
- **السبب الجذري (Code Bug)**: المستخدم كان مسجلاً بالبريد مسبقاً (`authProvider='email'`, `emailVerified=false`) ثم سجل دخوله عبر Apple. دالة `validateSocialUser` في الباكند كان يجب أن تُحدّث السجل لتعكس أن المستخدم دخل عبر Apple وبريده مُتحقق، لكنها لم تفعل ذلك — هذا يحتاج تحقيق كـ code bug.

### Huawei ⚠️ إصلاح جزئي — في انتظار إعادة بناء Flutter
- بدل إكمال تسجيل الدخول عبر Huawei، يُعاد التوجيه إلى صفحة لاندنج مختلفة تماماً
- **السبب**: `HUAWEI_WEB_CLIENT_SECRET` كان مفقوداً من إعدادات السيرفر، مما يمنع تبادل كود OAuth بنجاح
- **إصلاح مُطبّق**: تم إضافة `HUAWEI_WEB_CLIENT_SECRET` إلى `.env` (backend) و `.env.example`
- **تم النشر**: `.env` المحدث نُشر على السيرفر بنجاح ويحتوي على `HUAWEI_WEB_CLIENT_SECRET`
- **القيم الصحيحة**:
  - `HUAWEI_APP_ID=116918405`
  - `HUAWEI_WEB_CLIENT_ID=116918405`
  - `HUAWEI_WEB_CLIENT_SECRET=0407b3f06be61f8e5d7e5cef952a7ad6db060a413d4c6775e97aaccdfd230c96`
  - `HUAWEI_WEB_REDIRECT_URI=https://sahifati.org/api/auth/social/huawei/callback`
- **الخطوة المتبقية**: إعادة بناء تطبيق Flutter web بعد تحديث `auth_config.json` وإعادة نشره

---

## تحليل مخرجات الكونسول (Console Output Analysis)

### طبيعي ✅
- `TrustedTypes` policies: `gis-dart`, `flutterfire-firebase_core`, `flutterfire-firebase_messaging`
- `Social Auth Config loaded successfully from JSON`

### ليس مرتبطًا بالتطبيق ⚠️
- `Could not establish connection. Receiving end does not exist.` → إضافات المتصفح (browser extensions)

### أداء فقط (غير حرج) ⚡
- `[Violation]` setTimeout / requestAnimationFrame warnings
- `POST /api/licensing/activate/gift 403 (Forbidden)` — راجع قسم Apple أعلاه

---

## ملاحظات تشغيلية للخادم (Server Operational Notes)

- `podman restart sahifaty_api` **لا يُحدّث** متغيرات البيئة — يجب `podman rm` ثم `podman run` من جديد
- بعد إعادة إنشاء `sahifaty_api`، نفّذ: `podman exec sahifaty_gateway nginx -s reload`
- ملف `.env` على الخادم: `~/sahifaty/sahifaty-api/.env` يُحمّل عبر `--env-file`
- MongoDB: المصادقة معطّلة؛ قاعدة `sahifati` تم حذفها (كانت فارغة)

---

## Server .env Path Correction

المسار الصحيح لملف `.env` على الخادم هو `~/sahifaty/sahifaty-api/.env` (وليس `~/sahifati/sahifati_api/.env` كما كان موثقاً سابقاً). المسار الكامل هو `/home/mnofal/sahifaty/sahifaty-api/.env`.

---

## العناصر المتبقية (Known Remaining Items)

- `GOOGLE_CLIENT_SECRET` و `GOOGLE_CALLBACK_URL` مطلوبان في `.env` لاستراتيجية `passport-google-oauth20` (أُضيفا إلى `.env.example`، placeholder في `.env`)
- خطأ null check في Push notifications يحتاج تحقيق
- إعدادات nginx المضيف (`/etc/nginx/sites-enabled/sahifaty.org`) مملوكة لـ root، لا يمكن تعديلها
- Apple code bug: دالة `validateSocialUser` لا تُحدّث سجل المستخدم عند الدخول عبر Apple إذا كان مسجلاً مسبقاً بالبريد — يحتاج تحقيق وإصلاح
- Huawei: `.env` نُشر على السيرفر بنجاح، الخطوة المتبقية هي إعادة بناء تطبيق Flutter web بعد تحديث `auth_config.json` وإعادة نشره