# صفحة الملف الشخصي (`/me`) - توثيق كامل

## نظرة عامة

صفحة `/me` (اسم الكلاس: `UserOverviewScreen`) تعرض نظرة شاملة على تقدم المستخدم في حفظ القرآن الكريم. تتضمن:
- رسم بياني دائري (Donut) للنسبة الإجمالية للحفظ
- بطاقة لكل سورة تحتوي على رسم بياني عمودي مخصص لعرض حالة كل آية
- إمكانية النقر على أي آية في الرسم البياني لعرض نصها وتقييمها
- إمكانية النقر على اسم السورة لاختيار آيات وتقييمها
- نظام تصفية (أثلاث، نوع الآية)

---

## المسار (Route)

**الملف:** `lib/main.dart` (سطر 320-324)

```dart
GetPage(
  name: UserOverviewScreen.routeName, // '/me'
  page: () => const AuthenticatedRouteGate(
    child: UserOverviewScreen(),
  ),
),
```

الصفحة محمية بـ `AuthenticatedRouteGate` — لا يمكن الوصول إليها إلا للمستخدمين المسجلين.

---

## الملفات الأساسية

| الملف | الغرض |
|-------|--------|
| `lib/screens/user_overview_screen/user_overview_screen.dart` | الصفحة الرئيسية — كل واجهة المستخدم ومعالجة البيانات |
| `lib/screens/widgets/surah_verse_chart.dart` | الرسم البياني المخصص لكل سورة + نافذة الآية المنبثقة |
| `lib/screens/widgets/verse_picker_sheet.dart` | شيت اختيار الآيات للتقييم الجماعي |
| `lib/screens/widgets/assessment_input_dialog.dart` | حوار اختيار التقييم (حفظ/فهم) |
| `lib/screens/supervision_screen/supervision_metric_utils.dart` | دوال التقييم: النقاط، الألوان، الأولوية |
| `lib/providers/evaluations_provider.dart` | إدارة الحالة: التقييمات، تقييمات المستخدم |
| `lib/services/evaluations_services.dart` | خدمة API للتواصل مع الخادم |
| `lib/controllers/ayat_controller.dart` | تحميل كل الآيات من ملف JSON المحلي |

---

## تدفق البيانات (Data Flow)

### 1. تحميل البيانات — `_load()` (سطر 231-257)

عند فتح الصفحة، يتم تحميل ثلاثة مصادر بيانات بالتوازي:

```dart
final results = await Future.wait<Object>([
  _evaluationsServices.getAllEvaluations(type: 'memorization'),
  evaluationsProvider.loadResolvedUserEvaluations(userId),
  _ayatController.loadAllAyat(),
]);
```

| المصدر | الوصف | المصدر |
|--------|-------|--------|
| `getAllEvaluations(type: 'memorization')` | تعريفات أنواع التقييم (متمكن، مراجعة، سهل، صعب) | API: `GET /evaluations?type=memorization` |
| `loadResolvedUserEvaluations(userId)` | كل تقييمات المستخدم مع دمج التقييمات غير المتصلة | API: `GET /user-evaluations?userId={userId}&limit=1000&page={n}` (صفحات) |
| `loadAllAyat()` | كل آيات القرآن (6236 آية) مع عدد الحروف لكل آية | ملف محلي: `assets/json/data.json` |

### 2. معالجة البيانات — `_buildOverview()` (سطر 259-403)

تحوّل البيانات الخام إلى نموذج جاهز للعرض عبر 4 خطوات:

#### الخطوة 1: بناء فهرس التقييمات (سطر 264-279)

```dart
final evaluationPayloadById = <int, Map<String, dynamic>>{};
// كل تقييم يُخزن بـ: evaluationId, code, name, nameAr, color

final userEvaluationByAyahId = <int, UserEvaluation>{};
// تقييم المستخدم يُفهرس برقم الآية
```

#### الخطوة 2: بناء إحصائيات السور (سطر 282-343)

لكل آية:
- تُجمّع حسب `surah.id` في كائنات `_MutableSurahProgress`
- تُحسب: `totalVerses`, `evaluatedVerses`, `proficientVerses`
- يُنشأ `VerseChartEntry` لكل آية يحتوي على:
  - `letterCount` — يحدد **عرض** العمود
  - `score` — يحدد **ارتفاع** العمود
  - `color` — يحدد **لون** العمود
  - `evaluationLabel` — يظهر في النافذة المنبثقة

#### الخطوة 3: بناء الشرائح الإجمالية (سطر 345-382)

تُجمّع أعداد الحروف لكل نوع تقييم عبر كل الآيات، وتُحسب النسب المئوية، وتُبنى قائمة `_OverviewSegment` مرتبة حسب الأولوية.

#### الخطوة 4: بناء بطاقات السور (سطر 384-402)

تُنشأ `_SurahProgressCardData` لكل سورة تحتوي على آية واحدة على الأقل مقيّمة، مرتبة حسب رقم السورة.

---

## نظام التقييم (Memorization Rating System)

**الملف:** `lib/screens/supervision_screen/supervision_metric_utils.dart`

### دالة `supervisionEvaluationScore()` (سطر 120-126)

تحوّل التقييم إلى رقم يحدد ارتفاع العمود:

| التقييم | الكود (code) | النقاط (score) | الارتفاع |
|---------|-------------|----------------|----------|
| متمكن/متقن | `g`, `mtkn*` | **3** | أعلى عمود |
| مراجعة | `s`, `mraj*` | **2** | متوسط-عالي |
| سهل/جيد | `easy`, `gid`, `good` | **1** | متوسط-منخفض |
| غير مصنف | — | **0** | خط أساسي (2px) |
| صعب/ضعيف | `hard`, `daeif*` | **-1** | أسفل خط الصفر |

### دالة `supervisionResolveEvaluationColor()` (سطر 96-115)

| التقييم | اللون الافتراضي |
|---------|-----------------|
| متمكن | `#4FD99A` (أخضر) |
| مراجعة | `#6EC5FF` (أزرق) |
| سهل | `#FFB256` (برتقالي) |
| صعب | `#FF6E73` (أحمر) |
| غير مصنف | `#94A3B8` (رمادي) |

> إذا حدد المدير لونًا مخصصًا (hex) للتقييم، يُستخدم بدلاً من الافتراضي.

### دالة `supervisionEvaluationPriority()` (سطر 80-94)

ترتيب الأولوية: متمكن (0) → مراجعة (1) → سهل (2) → صعب (3) → غير مصنف (10)

---

## آلية الرسم البياني

### 1. الرسم الدائري الإجمالي (Donut Chart)

**الملف:** `user_overview_screen.dart` — كلاس `_UserSummaryHeader` (سطر 673-873)

- يستخدم مكتبة **`fl_chart`** (`PieChart`)
- كل شريحة (`_OverviewSegment`) تُحوّل إلى `PieChartSectionData`
- المسافة المركزية (centerSpaceRadius) = 24 (شكل donut)
- مسافة بين الشرائح = 2 درجة
- النص المركزي يعرض النسبة المئوية واسم التقييم للشريحة البارزة
- حالة الفراغ: حلقة رمادية كنائب

### 2. الرسم البياني لكل سورة (Per-Surah Verse Bar Chart)

**الملف:** `lib/screens/widgets/surah_verse_chart.dart`

هذا رسم **مخصص بالكامل** باستخدام `CustomPaint` — لا مكتبة خارجية.

#### نموذج `VerseChartEntry` (سطر 19-45)

```dart
class VerseChartEntry {
  final int ayahId;          // رقم الآية
  final int ayahNumber;      // رقم الآية في السورة
  final int letterCount;     // عرض العمود يتناسب مع هذا
  final double score;         // ارتفاع العمود: 3=متمكن, 2=مراجعة, 1=سهل, 0=غير مصنف, -1=صعب
  final Color color;          // لون العمود
  final String evaluationLabel; // يظهر في النافذة المنبثقة
  final String text;           // نص الآية الكامل للنافذة المنبثقة
}
```

#### ويدجت `SurahVerseChart` (سطر 58-143)

- يُلف بـ `LayoutBuilder` + `GestureDetector`
- عند النقر، `_findTappedEntry()` يحدد أي عمود تم النقر عليه
- عند الإصابة، يعرض `_VersePopupDialog` عبر `showDialog()`

#### `_VerseChartPainter` (سطر 149-226)

آلية الرسم:

```
مدى النقاط: -1 إلى 3 (المدى الكلي = 4)
scaleX = العرض / إجمالي_الحروف
scaleY = الارتفاع / مدى_النقاط
خط الصفر: zeroY = الارتفاع - ((0 - scoreMin) * scaleY)
```

- الأعمدة تُرسم **من اليمين إلى اليسار** (RTL — الآية 1 تبدأ من اليمين)
- كل عمود: عرضه = `letterCount × scaleX`، ارتفاعه = `|score| × scaleY`
- الأعمدة السالبة (صعب = -1) تمتد **لأسفل** من خط الصفر
- الأعمدة ذات نقطة 0 (غير مصنف) لها ارتفاع أدنى = 2px
- خطوط فاصلة بيضاء (1px) بين الأعمدة
- خط صفر رمادي أفقي عبر العرض الكامل
- لون الخلفية: `#F7F3EE`

#### `_VersePopupDialog` (سطر 232-324)

عند النقر على عمود آية:
- يعرض ملصق التقييم في شارة ملونة (pill badge)
- يعرض نص الآية الكامل مع الرقم: `{text} ﴿{ayahNumber}﴾`
- الأرقام تُحول لأرقام عربية هندية عبر `_toArabicNumerals()`
- زر إغلاق بعنوان "إغلاق"

#### `_DynamicLegend` (سطر 330-383)

- يجمع أزواج `evaluationLabel → color` الفريدة من المدخلات
- يعرضها كـ `Wrap` بنقاط ملونة + أسماء باتجاه RTL

---

## آلية عرض الآيات عند النقر

### المسار الكامل للتفاعل

```
النقر على اسم السورة
        │
        ▼
_openVersePicker() (سطر 405-462)
        │
        ├── 1. عرض شيت اختيار الآيات (VersePickerSheet)
        │      - قائمة بجميع آيات السورة مع خانات اختيار
        │      - اختيار متعدد
        │      - زر "تقييم X آية"
        │      - يُرجع List<int> من أرقام الآيات المختارة
        │
        ├── 2. عرض حوار التقييم (AssessmentInputDialog)
        │      - خيارات تقييم الحفظ كـ ChoiceChip
        │      - خيارات تقييم الفهم كـ ChoiceChip
        │      - يُرجع AssessmentSelection {memoId, compreId, comment}
        │
        ├── 3. إرسال التقييم للخادم
        │      EvaluationsController.sendMultipleEvaluationSelection()
        │      → POST /user-evaluations/bulk
        │
        └── 4. إعادة تحميل البيانات: _reload()
```

### المسار البديل: النقر على عمود في الرسم البياني

```
النقر على عمود آية في SurahVerseChart
        │
        ▼
_findTappedEntry() — تحديد العمود المضغوط
        │
        ▼
showDialog() → _VersePopupDialog
        - عرض ملصق التقييم (متمكن/مراجعة/سهل/صعب)
        - عرض نص الآية الكامل مع رقمها
        - زر إغلاق
```

---

## نظام التصفية (Filtering)

الصفحة تدعم تصفية بطاقات السور حسب:

| الفلتر | الوصف |
|--------|-------|
| أثلاث القرآن | الأول/الثاني/الثالث حسب رقم الصفحة |
| نوع الآية | مدني/مكي |

**التنفيذ:**
- `UnifiedFilterSelection` و `showUnifiedQuranFilterSheet()` في `unified_quran_filter_sheet.dart`
- `_surahMatchesFilter()` (سطر 149-162) يتحقق من مطابقة السورة للفلتر
- `_computeFilteredSegments()` (سطر 164-202) يعيد حساب النسب المئوية بناءً على السور المفلترة

---

## النماذج الأساسية (Key Models)

### `_UserOverviewData` (سطر 1199-1211)

```dart
class _UserOverviewData {
  final List<_OverviewSegment> segments;      // شرائح الرسم الدائري
  final _OverviewSegment? highlight;          // الشريحة البارزة
  final List<_SurahProgressCardData> surahCards; // بطاقات السور
  final Map<int, List<Ayat>> ayatBySurahId;    // الآيات مجمعة حسب السورة
}
```

### `_OverviewSegment` (سطر 1213-1231)

```dart
class _OverviewSegment {
  final String label;           // اسم التقييم
  final double percent;          // النسبة المئوية
  final int verseCount;          // عدد الآيات
  final Color color;             // اللون
  final int priority;            // الأولوية في الترتيب
  final bool isProficient;       // هل تقييم متمكن؟
  final bool isReview;           // هل تقييم مراجعة؟
}
```

### `_SurahProgressCardData` (سطر 1244-1270)

```dart
class _SurahProgressCardData {
  final int surahId;
  final String surahName;
  final int totalVerses;
  final int proficientVerses;
  final int evaluatedVerses;
  final List<VerseChartEntry> verseEntries;
  // محسوبة:
  double get proficientRatio;     // proficientVerses / totalVerses
  String get proficientPercent;  // نسبة مئوية منسّقة
  int get remainingVerses;        // totalVerses - proficientVerses
  String get remainingPercent;   // نسبة المتبقي
}
```

### `VerseChartEntry` (surah_verse_chart.dart سطر 19-45)

```dart
class VerseChartEntry {
  final int ayahId;
  final int ayahNumber;
  final int letterCount;         // عرض العمود
  final double score;             // ارتفاع العمود
  final Color color;              // لون العمود
  final String evaluationLabel;   // ملصق التقييم
  final String text;              // نص الآية
}
```

---

## إدارة الحالة (State Management)

### `EvaluationsProvider` (ChangeNotifier)

**الملف:** `lib/providers/evaluations_provider.dart`

| الخاصية/الدالة | الوصف |
|----------------|--------|
| `evaluations` | قائمة تعريفات أنواع التقييم |
| `userEvaluations` | قائمة تقييمات المستخدم لكل آية |
| `getAllEvaluations()` (سطر 109) | تحميل تعريفات التقييمات |
| `loadResolvedUserEvaluations(userId)` (سطر 336) | تحميل ودمج تقييمات المستخدم مع الطوابير غير المتصلة |
| `findEvaluationById(id)` (سطر 552) | البحث عن تقييم بالرقم |

المزود يعمل بنظام **أولوية عدم الاتصال** (offline-first):
- يخزن التقييمات محلياً عند انقطاع الاتصال
- يزامن عند عودة الاتصال
- يدمج التقييمات المحلية مع بيانات الخادم عبر `OfflineAssessmentStore`

### `EvaluationsServices`

**الملف:** `lib/services/evaluations_services.dart`

| الدالة | API |
|--------|-----|
| `getAllEvaluations(type)` | `GET /evaluations?type=memorization` |
| `getUserEvaluationsPage(userId, ...)` | `GET /user-evaluations?userId={userId}&limit=1000&page={n}` |
| `evaluateAyah(body)` | `POST /user-evaluations` |
| `evaluateMultipleAyat(body)` | `POST /user-evaluations/bulk` |

### `AyatController`

**الملف:** `lib/controllers/ayat_controller.dart`

يحمّل كل الآيات من `assets/json/data.json` (ملف JSON محلي مُضمّن في التطبيق). يستخدم `static cached future` لضمان التحميل مرة واحدة فقط.

---

## ملخص تدفق العمل الكامل

```
┌─────────────────────────────────────────────────────────────┐
│                    UserOverviewScreen                        │
│                                                              │
│  1. _load()                                                  │
│     ├── GET /evaluations?type=memorization                   │
│     ├── GET /user-evaluations (paginated)                    │
│     └── loadAllAyat() from local JSON                        │
│                                                              │
│  2. _buildOverview()                                         │
│     ├── فهرسة التقييمات                                      │
│     ├── تجميع الآيات حسب السورة + بناء VerseChartEntry      │
│     │   (score, letterCount, color, evaluationLabel)         │
│     ├── حساب الشرائح الإجمالية                               │
│     └── بناء بطاقات السور                                    │
│                                                              │
│  3. بناء الواجهة                                              │
│     ├── _UserSummaryHeader                                   │
│     │   └── PieChart (fl_chart) ← _OverviewSegment[]         │
│     │                                                        │
│     └── _SurahProgressCard[] ← _SurahProgressCardData[]      │
│         ├── اسم السورة (قابل للنقر → _openVersePicker)       │
│         ├── نسبة الإتقان                                      │
│         └── SurahVerseChart (CustomPaint)                    │
│             ├── أعمدة متغيرة العرض (letterCount)              │
│             ├── أعمدة متغيرة الارتفاع (score)                │
│             ├── ألوان من تقييم المستخدم                       │
│             └── النقر → _VersePopupDialog                    │
│                  ├── شارة التقييم الملونة                     │
│                  └── نص الآية + رقمها                        │
│                                                              │
│  4. التفاعل                                                  │
│     ├── النقر على عمود آية → عرض النص والتقييم               │
│     └── النقر على اسم السورة → اختيار آيات → تقييم جماعي    │
│         → POST /user-evaluations/bulk                         │
│         → إعادة تحميل البيانات                                │
└─────────────────────────────────────────────────────────────┘
```