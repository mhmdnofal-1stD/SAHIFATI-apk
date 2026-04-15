# Frontend Users UI Bundled Remediation Backlog

تاريخ التحديث: 2026-04-15
النطاق: E:\Sahifati\frontend_users\ui
المرجع: docs/project-analysis-2026-04-14.md

## الهدف

هذه الوثيقة تحول الملاحظات الحالية في frontend_users/ui إلى backlog تنفيذية مجمعة ومحددة الحدود. المقصود ليس إعادة صياغة التحليل العام، بل استخراج ست حزم يمكن تنفيذ كل واحدة منها لاحقاً بشكل مستقل مع وضوح الأولوية والتبعيات ومتطلبات التحقق.

## Evidence Anchors From Quick Analysis

- main.dart يقيد التطبيق على portrait في الجذر، ويشغّل فحص الاتصال داخل build، ويحوّل حالة عدم الاتصال مباشرة إلى MainScreen.
- size_config.dart يبني القياسات على baseline ثابتة 375x812.
- login_screen.dart يحتوي nested SingleChildScrollView ويخلط بين منطق الواجهة وحفظ access token محلياً.
- users_provider.dart وselect_user_screen.dart يحفظان كلمات المرور محلياً ويستخدمانها لإعادة تسجيل الدخول.
- sahifaty_api.dart يقرأ accessToken وrefreshToken من shared preferences ويطبع معلومات session في debug.
- content_item_card.dart وindex_page.dart يحملان بيانات القراءة والتقييم بشكل متكرر وعلى مستوى عناصر أو شاشات ثقيلة.

## Bundle Map

| ID | Priority | Bundle | Backend Coordination | Owner Visual Review | Benchmark Verification |
| --- | --- | --- | --- | --- | --- |
| UI-B01 | P0 | Credential and session storage hardening | No | Not Required | No |
| UI-B02 | P0 | Auto-login and session bootstrap gating | Conditional | Not Required | No |
| UI-B03 | P0 | Social auth contract alignment with backend | Yes | Not Required | No |
| UI-B04 | P1 | Web layout responsiveness and desktop-fit | No | Required | No |
| UI-B05 | P1 | Login/auth scroll and interaction stability | No | Required | No |
| UI-B06 | P1 | Questions/Quran performance and async loading consolidation | No | Not Required | Required |

## Bundle Details

### UI-B01 - Credential And Session Storage Hardening

**Goal**

إغلاق مسارات تخزين الأسرار محلياً بصيغة قابلة للقراءة، ومنع أي اعتماد لاحق على كلمة المرور أو session secrets خارج طبقة session المقصودة.

**Primary Surfaces**

- lib/providers/users_provider.dart
- lib/services/sahifaty_api.dart
- lib/services/users_services.dart
- lib/screens/authentication_screens/login_screen.dart
- lib/screens/authentication_screens/select_user_screen.dart

**Root Cause**

هناك خلط بين cached user data وsession state. التطبيق يحفظ كلمات المرور ضمن stored device users، ويستخدم shared preferences مباشرة للوصول إلى tokens، ويطبع معلومات حساسة في debug.

**Scope**

- إزالة حفظ كلمة المرور محلياً نهائياً.
- منع الاعتماد على credential مخزنة لإعادة تسجيل الدخول من select-user flow.
- إزالة أي debug logging يكشف token أو session headers.
- توحيد الوصول إلى accessToken وrefreshToken من خلال session path واحدة واضحة.

**Out Of Scope**

- إعادة تصميم كاملة لطبقة auth في backend.
- إضافة provider جديدة أو إعادة بناء UX المصادقة بالكامل.

**Dependencies / Order**

تنفذ أولاً، لأنها أساس UI-B02 وUI-B03.

**Acceptance Outputs**

- لا تبقى كلمة المرور جزءاً من local storage أو cached user payload.
- لا تبقى session secrets مطبوعة في logs.
- يصبح للتطبيق مصدر حقيقة واحد لقراءة وكتابة session credentials.

**Expected Verification**

- smoke check لمسارات login, logout, app restart دون أي اعتماد على كلمة مرور مخزنة.
- search verification للتأكد من غياب logging الحساسة في المسارات المتأثرة.

**Backend Coordination**

No

**Owner Visual Review**

Not Required

### UI-B02 - Auto-Login And Session Bootstrap Gating

**Goal**

منع وصول المستخدم إلى main flow اعتماداً على user cache محلية أو قرار bootstrap متفائل قبل التحقق من صلاحية session فعلياً.

**Primary Surfaces**

- lib/main.dart
- lib/providers/users_provider.dart
- lib/screens/authentication_screens/select_user_screen.dart
- lib/screens/main_screen/main_screen.dart

**Root Cause**

المنطق الحالي يعتبر وجود userData أو selectedUser مؤشراً كافياً للمتابعة، مع FutureBuilder connectivity داخل جذر التطبيق وتحويل غير منضبط بين authenticated وoffline وunauthenticated states.

**Scope**

- جعل قرار startup routing مبنياً على session state صالحة بدلاً من مجرد وجود بيانات محلية.
- فصل حالات bootstrap إلى restoring, authenticated, unauthenticated, offline-limited.
- منع الوصول إلى MainScreen عندما تكون session غير صالحة أو restore فاشلة.
- منع select-user flow من تنفيذ دخول متفائل يعتمد على password مخزنة محلياً.

**Out Of Scope**

- offline mode كامل.
- إعادة هيكلة عامة لكل state management في التطبيق.

**Dependencies / Order**

تعتمد على UI-B01. تنفذ قبل responsive polishing حتى لا يعاد فتح نفس العيب في startup path.

**Acceptance Outputs**

- startup gating تصبح موحدة وصريحة.
- لا يصل المستخدم إلى main flow بجلسة غير مكتملة أو منتهية.
- حالات عدم الاتصال أو فشل restore تصبح معروضة بوضوح وليست side effect ضمني.

**Expected Verification**

- فحص سيناريوهات startup: cached user بلا token، token منتهية، token صالحة، وعدم وجود اتصال.
- التحقق من routing بعد restart ومن select-user behavior بعد hardening.

**Backend Coordination**

Conditional

مطلوب فقط إذا لم تكن هناك endpoint حالية يمكن استخدامها للتحقق من صلاحية session أثناء bootstrap.

**Owner Visual Review**

Not Required

### UI-B03 - Social Auth Contract Alignment With Backend

**Goal**

تطابق Google/Facebook social login في UI مع العقد الخلفية الحالية بدل الاعتماد على payloads أو assumptions قديمة.

**Primary Surfaces**

- lib/services/users_services.dart
- lib/providers/users_provider.dart
- lib/screens/authentication_screens/login_screen.dart
- lib/services/sahifaty_api.dart

**Root Cause**

social auth في UI منفصلة عن hardening session الحالي، ما يجعل success/failure handling معتمدة على افتراضات قديمة بشأن المدخلات أو الاستجابة من backend.

**Scope**

- مراجعة request payloads المطلوبة لكل provider مقابل backend الحالية.
- توحيد success/failure handling بدل silent fallbacks.
- توضيح الحدود بين provider token acquisition في الواجهة وبين verification في backend.

**Out Of Scope**

- إضافة social provider جديدة.
- إعادة بناء backend social auth flows بالكامل.

**Dependencies / Order**

تعتمد على UI-B01، ويستحسن تنفيذها بعد UI-B02 حتى تكون session semantics النهائية واضحة.

**Acceptance Outputs**

- social auth requests تصبح مطابقة للعقد الخلفية الحالية.
- failure states تظهر للمستخدم بصورة متماسكة وقابلة للتشخيص.
- لا يبقى bypass محلي بسبب mismatch بين UI وbackend contract.

**Expected Verification**

- contract verification مع backend endpoints المتاحة.
- successful and failed login checks لكل provider مدعوم.

**Backend Coordination**

Yes

**Owner Visual Review**

Not Required

### UI-B04 - Web Layout Responsiveness And Desktop-Fit

**Goal**

إزالة الاعتماد على baseline الهاتف الضيقة وتمكين التطبيق من التمدد والتقلص على web/tablet/desktop دون كسر shell أو dashboard أو surfaces القراءة.

**Primary Surfaces**

- lib/main.dart
- lib/core/utils/size_config.dart
- lib/screens/main_screen/main_screen.dart
- lib/screens/sahifa_screen/sahifa_screen.dart
- lib/screens/questions_screen/questions_screen.dart

**Root Cause**

القياسات مبنية على 375x812 مع افتراضات portrait mobile في الجذر وبعض الشاشات، ما ينتج انحرافاً واضحاً على web خصوصاً في widths وspacing وchart containers وقراءة المحتوى.

**Scope**

- تخفيف أو إزالة الافتراضات الصلبة الخاصة بمقاس الهاتف في SizeConfig والجذر.
- إدخال responsive width strategy مناسبة للشاشات الواسعة.
- ضبط spacing وwidth caps وchart sizing وscroll shells في الأسطح الأساسية.

**Out Of Scope**

- redesign بصري شامل.
- تعديل business logic أو data flows غير المتعلقة بالتخطيط.

**Dependencies / Order**

يمكن تنفيذها بعد اكتمال P0 security/session bundles، وتسبق UI-B05 حتى لا تعاد معالجة auth surfaces مرتين.

**Acceptance Outputs**

- main وsahifa وquestions surfaces تتكيف بشكل معقول على mobile وtablet وdesktop web.
- لا تبقى dashboard أو controls الأساسية محصورة في narrow portrait assumptions.
- العرض الأفقي أو الشاشات الواسعة لا ينتج قصاً أو فراغات غير عملية.

**Expected Verification**

- visual review على mobile وtablet وdesktop web.
- evidence بصري للشاشات الأساسية بعد responsive refit.

**Backend Coordination**

No

**Owner Visual Review**

Required

### UI-B05 - Login/Auth Scroll And Interaction Stability

**Goal**

إزالة nested scroll والقص والتذبذب التفاعلي في login/select-user، خصوصاً على web ومع اختلاف الارتفاعات والـ keyboard states.

**Primary Surfaces**

- lib/screens/authentication_screens/login_screen.dart
- lib/screens/authentication_screens/select_user_screen.dart

**Root Cause**

login flow يستخدم nested SingleChildScrollView وقياسات مرتبطة بـ SizeConfig بصورة تجعل overflow وسلوك التركيز والتحميل غير مستقرين.

**Scope**

- إزالة scroll nesting غير الضروري.
- تثبيت keyboard avoidance وoverflow behavior وحالات التحميل والفشل.
- ضبط الحقول والأزرار لتبقى قابلة للاستخدام على web والشاشات الضيقة والمتوسطة.

**Out Of Scope**

- إعادة تصميم هوية شاشة auth بالكامل.
- تغيير business logic خارج ما يلزم لاستقرار التفاعل.

**Dependencies / Order**

يفضل بعد UI-B04 حتى تستفيد من responsive foundation، وبعد UI-B02 حتى لا تختلط إصلاحات الواجهة مع bootstrap fixes.

**Acceptance Outputs**

- لا يبقى nested scroll معطل في auth flow.
- الحقول والأزرار تظل قابلة للاستخدام دون قص أو اهتزاز layout.
- loading and error states لا تكسر التخطيط ولا تعطل الإجراء التالي.

**Expected Verification**

- visual review على mobile وtablet وdesktop web.
- keyboard and overflow checks أثناء login والفشل وإعادة المحاولة.

**Backend Coordination**

No

**Owner Visual Review**

Required

### UI-B06 - Questions And Quran Performance And Async Loading Consolidation

**Goal**

تقليل التحميل المتكرر وfan-out غير الضروري في questions وquran surfaces، وتحويل المسارات الثقيلة إلى تحميل مركزي قابل للقياس.

**Primary Surfaces**

- lib/screens/questions_screen/questions_screen.dart
- lib/screens/questions_screen/content_item_card.dart
- lib/screens/quran_view/quran_view.dart
- lib/screens/quran_view/index_page.dart

**Root Cause**

بعض البيانات تُحمَّل وتُفحص على مستوى العناصر أو عند كل انتقال داخل شاشات ثقيلة، مثل _checkCompletion لكل content item، وإعادة تحميل evaluation state في reading surfaces، وبناء قوائم كاملة داخل PageView.

**Scope**

- تجميع async loading في questions flow بدلاً من per-item fan-out متكرر.
- تقليل full rebuild patterns وعمليات التحميل المتكررة في quran surfaces.
- إعادة استخدام البيانات المحلية للشاشة نفسها بدل إعادة الجلب والتحليل دون داع.

**Out Of Scope**

- offline architecture كاملة.
- استبدال شامل لـ provider/get أو إعادة هيكلة state management على مستوى التطبيق كله.

**Dependencies / Order**

يمكن تنفيذها بعد P0 bundles مباشرة. وإذا كانت responsive changes ستلمس نفس الأسطح، فيفضل تنسيقها مع UI-B04 لتجنب تكرار العمل.

**Acceptance Outputs**

- انخفاض واضح في async fan-out داخل questions flow.
- تقليل عمليات التحميل أو evaluation fetch المتكررة في quran surfaces.
- التمرير والتنقل في الشاشات الثقيلة يصبحان أكثر استقراراً.

**Expected Verification**

- profiling قبل وبعد باستخدام Flutter DevTools أو مؤشرات build/frame مكافئة.
- قياس عدد مرات التحميل أو parsing في المسارات المتأثرة قبل وبعد التنفيذ.

**Backend Coordination**

No

**Owner Visual Review**

Not Required

## Suggested Execution Order

1. UI-B01 ثم UI-B02 لأن session hardening وstartup gating يزيلان المخاطر الأساسية قبل أي polishing أو responsive refit.
2. UI-B03 بعد تثبيت semantics الخاصة بالجلسة لأن social auth تعتمد على العقد النهائية نفسها.
3. UI-B04 كأساس web-fit للشاشات الأساسية.
4. UI-B05 بعد responsive foundation حتى لا تعاد معالجة auth layouts مرتين.
5. UI-B06 بعد استقرار P0، أو بالتوازي إذا بقيت معزولة عن الأسطح التي ستتغير responsive.

## Split By Coordination Need

**UI-Only Bundles**

- UI-B01
- UI-B04
- UI-B05
- UI-B06

**Conditional Coordination**

- UI-B02 إذا احتاج bootstrap session validation endpoint غير متوفرة حالياً.

**Backend-Coordinated Bundle**

- UI-B03

## Readiness Notes

- هذه الوثيقة backlog تنفيذية وليست task implementation بديلة.
- الحزم الست منفصلة قصداً حتى لا يختلط hardening الأمني مع responsive polishing أو performance work.
- أي تنفيذ لاحق يجب أن يظل bounded داخل bundle واحدة في كل task مستقلة.# Bundled Remediation Backlog For Sahifaty UI

تاريخ الإنشاء: 2026-04-15  
النطاق: `E:\Sahifati\frontend_users\ui`  
المرجع التحليلي: `docs/project-analysis-2026-04-14.md`

## الهدف

هذه الوثيقة تحول الملاحظات الحالية في `frontend_users/ui` إلى رزم تنفيذية bounded يمكن تحويل كل واحدة منها لاحقاً إلى task مستقلة.  
الترتيب هنا مقصود: الأمن والجلسة أولاً، ثم web-fit والاستقرار التفاعلي، ثم الأداء الثقيل.

## قواعد التقسيم

- كل bundle تمثل سبباً جذرياً واحداً أو شريحة تنفيذية متماسكة، لا قائمة أعراض عامة.
- الرزم الأمنية منفصلة عن web-fit والأداء حتى لا يختلط hardening مع polishing بصري.
- أي bundle تحتاج backend coordination تم وسمها صراحة.
- أي bundle تحتاج visual review تم وسمها صراحة.
- أي benchmark أو profiling مطلوب بعد التنفيذ تم ذكره ضمن verification المتوقعة.

## Bundle Map

| ID | Priority | Bundle | Coordination | Visual Review | Benchmark |
| --- | --- | --- | --- | --- | --- |
| UI-B01 | P0 | Credential and session secret hardening | No | No | No |
| UI-B02 | P0 | Auto-login and session bootstrap gating | No | No | No |
| UI-B03 | P0 | Social auth contract alignment with backend | Yes | No | No |
| UI-B04 | P1 | Web layout responsiveness and desktop-fit foundation | No | Yes | No |
| UI-B05 | P1 | Login/auth scroll and interaction stability | No | Yes | No |
| UI-B06 | P1 | Questions and Quran async/performance consolidation | No | No | Yes |

## Bundle Details

### UI-B01 - Credential And Session Secret Hardening

**Priority**  
`P0`

**Goal**  
إغلاق مسارات تخزين الأسرار محلياً بصيغة غير آمنة، ومنع أي اعتماد لاحق على كلمات مرور أو tokens مكشوفة داخل التخزين أو السجلات.

**Primary Surfaces**
- `lib/models/user.dart`
- `lib/services/sahifaty_api.dart`
- `lib/services/users_services.dart`
- `lib/controllers/users_controller.dart`
- `lib/providers/users_provider.dart`

**Root Cause**  
التطبيق يخلط بين بيانات الجلسة وبيانات المستخدم المخزنة محلياً، مع وجود مسارات logging أو serialization تجعل الأسرار جزءاً من state غير المقصودة.

**Scope**
- إزالة حفظ كلمة المرور محلياً نهائياً.
- حصر التخزين المحلي على session artifacts اللازمة فقط وبصياغة آمنة.
- حذف أي `print`, `debugPrint`, أو `toString()` يكشف token أو credential أو session payload.
- توحيد مصدر الحقيقة الخاص بـ access/refresh tokens.

**Out Of Scope**
- إعادة تصميم كاملة لطبقة الهوية في backend.
- تغيير UX الشاشات إلا إذا كان ضرورياً لمنع تسريب الأسرار.

**Dependencies / Order**  
تنفذ أولاً قبل أي bundle تعتمد على session bootstrap أو social auth.

**Acceptance Outputs**
- لا تبقى كلمة المرور جزءاً من local storage أو cached user model.
- لا تبقى tokens مطبوعة داخل logs المحلية.
- يوجد مسار واضح واحد لاسترجاع session credentials داخل التطبيق.

**Verification Expected**
- فحص تنفيذي أن login/logout/restore session تعمل دون أي اعتماد على كلمة مرور محفوظة.
- مراجعة نصية للبحث عن logging الحساسة.
- smoke verification لمسار session بعد إعادة تشغيل التطبيق.

**Backend Coordination**  
`No`

**Owner Visual Review**  
`Not Required`

### UI-B02 - Auto-Login And Session Bootstrap Gating

**Priority**  
`P0`

**Goal**  
منع دخول التطبيق إلى الشاشات الرئيسية بناءً على user cache أو حالة محلية غير موثقة بدلاً من session صالحة فعلياً.

**Primary Surfaces**
- `lib/main.dart`
- `lib/controllers/users_controller.dart`
- `lib/providers/users_provider.dart`
- `lib/screens/authentication_screens/select_user_screen.dart`
- `lib/screens/main_screen/main_screen.dart`

**Root Cause**  
منطق الإقلاع الحالي لا يميز بدقة بين user presence محلياً وبين session قابلة للاستخدام، لذلك يمكن أن يمر bootstrap إلى main flow قبل اكتمال التحقق.

**Scope**
- جعل bootstrap decision مبنياً على session validation وليس على وجود `userData` فقط.
- فصل حالات الإقلاع: authenticated, unauthenticated, restoring, offline-limited.
- منع الانتقال إلى `MainScreen` عند غياب token صالح أو فشل restore.
- ضبط select-user/login flow حتى لا يعيد فتح main flow بشكل متفائل.

**Out Of Scope**
- أي caching strategy جديدة للبيانات غير المرتبطة بالجلسة.
- offline mode الكامل.

**Dependencies / Order**  
تعتمد على UI-B01 وتسبق UI-B03 وUI-B04.

**Acceptance Outputs**
- الإقلاع يمر عبر gating موحدة ومقروءة.
- لا يصل المستخدم إلى main flow بجلسة غير مكتملة.
- حالات الفشل والاستعادة أصبحت صريحة لا ضمنية.

**Verification Expected**
- سيناريوهات bootstrap: user cached بلا token، token منتهي، token صالح، وعدم وجود اتصال.
- widget أو integration checks لمسارات startup routing.

**Backend Coordination**  
`No`

**Owner Visual Review**  
`Not Required`

### UI-B03 - Social Auth Contract Alignment With Backend

**Priority**  
`P0`

**Goal**  
تطابق عقود Google/Facebook/Apple داخل UI مع واجهات backend الحالية بدلاً من الاعتماد على assumptions قديمة أو payloads غير مدعومة.

**Primary Surfaces**
- `lib/services/sahifaty_api.dart`
- `lib/services/users_services.dart`
- `lib/controllers/users_controller.dart`
- `lib/screens/authentication_screens/login_screen.dart`

**Root Cause**  
social auth flow في UI لم يعد مضمون التطابق مع API الحالية بعد hardening backend، ما يهدد نجاح login أو يدفع التطبيق إلى fallbackات غير صحيحة.

**Scope**
- مراجعة payloads المتوقعة لكل provider مقابل backend contract الحالي.
- إزالة أي provider-side assumptions لم تعد مقبولة.
- توحيد success/failure handling لسيناريوهات social login.
- توضيح أين تنتهي مسؤولية UI وأين تبدأ مسؤولية backend token verification.

**Out Of Scope**
- إضافة provider جديد.
- إعادة بناء backend social auth.

**Dependencies / Order**  
تعتمد على UI-B01 وUI-B02.

**Acceptance Outputs**
- social auth requests صارت مطابقة للعقد الخلفي الحالي.
- فشل التحقق يعاد للمستخدم برسالة متماسكة بدل silent fallback.
- لا يوجد bypass محلي بسبب contract mismatch.

**Verification Expected**
- contract verification ضد backend endpoints الحالية.
- successful/failed login checks لكل provider المتاح.

**Backend Coordination**  
`Yes`

**Owner Visual Review**  
`Not Required`

### UI-B04 - Web Layout Responsiveness And Desktop-Fit Foundation

**Priority**  
`P1`

**Goal**  
إزالة الانجراف الناتج عن baseline الهاتف الثابتة، وتمكين صفحات الويب من التمدد والتقلص بشكل صحيح على tablet/desktop دون كسر layout.

**Primary Surfaces**
- `lib/main.dart`
- `lib/core/utils/size_config.dart`
- `lib/screens/main_screen/main_screen.dart`
- `lib/screens/sahifa_screen/sahifa_screen.dart`
- `lib/screens/widgets/bar_chart_widget.dart`

**Root Cause**  
الاعتماد على baseline `375x812` مع قيود اتجاه ودوال قياس ثابتة خلق layout drift على web، خاصة في dashboard، spacing، وأحجام controls.

**Scope**
- إزالة الافتراضات الصلبة الخاصة بمقاس الهاتف كوحدة قياس وحيدة.
- تعريف responsive breakpoints أو layout rules مناسبة للويب.
- معالجة chart and dashboard sizing بحيث لا تبقى مبنية على narrow portrait assumptions.
- تحسين alignment, spacing, width caps, وscroll behavior في الواجهات الأساسية على web.

**Out Of Scope**
- polishing بصري شامل لكل شاشة في التطبيق.
- إعادة branding أو theme system.

**Dependencies / Order**  
يمكن تنفيذها بعد تثبيت session bundles، وتسبق أي polishing تفصيلي للشاشات الفردية.

**Acceptance Outputs**
- الشاشة الرئيسية وsurface القراءة تتكيفان بشكل مفهوم على mobile/tablet/desktop web.
- لا تبقى dashboard/chart محصورة في افتراض portrait phone.
- controls الأساسية لا تظهر بأبعاد غير عملية على الشاشات الواسعة.

**Verification Expected**
- visual review على mobile, tablet, desktop web.
- مقارنة لقطات أو checklist responsive لسطح dashboard والقراءة.

**Backend Coordination**  
`No`

**Owner Visual Review**  
`Required`

### UI-B05 - Login/Auth Scroll And Interaction Stability

**Priority**  
`P1`

**Goal**  
إزالة مشاكل nested scroll والارتباك التفاعلي في شاشات الدخول والاختيار، خصوصاً على web والأحجام الصغيرة أو المتوسطة.

**Primary Surfaces**
- `lib/screens/authentication_screens/login_screen.dart`
- `lib/screens/authentication_screens/select_user_screen.dart`

**Root Cause**  
شاشات auth الحالية تعاني من scroll nesting وقياسات محتوى غير مستقرة، ما يؤثر في قابلية التفاعل، keyboard avoidance، وسلاسة التنقل.

**Scope**
- إزالة scroll nesting غير الضروري.
- توحيد سلوك overflow والتمرير والتركيز في login/select-user.
- ضبط hit areas والأحجام النصية والمسافات للشاشات الأصغر والويب.
- تثبيت interaction states أثناء التحميل والفشل.

**Out Of Scope**
- تعديل business logic الخاص بالمصادقة خارج ما يلزم لاستقرار الواجهة.
- إعادة تصميم كامل لشكل auth.

**Dependencies / Order**  
يفضل بعد UI-B02 وUI-B04 حتى لا تعاد معالجة نفس الشاشات مرتين.

**Acceptance Outputs**
- لا يوجد nested scroll معطل في login flow.
- الحقول والأزرار تظل قابلة للاستخدام على web/mobile دون قص أو اهتزاز.
- حالات التحميل والخطأ لا تكسر التخطيط.

**Verification Expected**
- visual review لشاشات auth على mobile/tablet/web.
- keyboard and overflow checks.

**Backend Coordination**  
`No`

**Owner Visual Review**  
`Required`

### UI-B06 - Questions And Quran Async/Performance Consolidation

**Priority**  
`P1`

**Goal**  
تقليل N+1 loading والتكرار الثقيل في `questions` و`quran_view` وتحويل القراءة والتحميل إلى مسارات مركزية قابلة للقياس.

**Primary Surfaces**
- `lib/screens/questions_screen/questions_screen.dart`
- `lib/screens/questions_screen/content_item_card.dart`
- `lib/screens/quran_view/index_page.dart`
- `lib/screens/quran_view/quran_view.dart`

**Root Cause**  
بعض الشاشات تحمل البيانات وتعيد تقييمها بشكل متكرر داخل loops أو lifecycle غير مركزي، ما يرفع كلفة build والتمرير والانتقال.

**Scope**
- تجميع async loading في questions screen بدلاً من per-item fan-out.
- منع تحميل/تحليل متكرر للمصادر نفسها داخل reading surfaces.
- تحسين بناء القوائم الثقيلة والحد من full rebuild patterns.
- توحيد caching/reuse المحلي للشاشات المذكورة فقط.

**Out Of Scope**
- offline architecture كاملة.
- إعادة هيكلة كل state management في التطبيق.

**Dependencies / Order**  
يمكن تنفيذها بالتوازي بعد P0، ويفضل بعد UI-B04 إذا كانت بعض surfaces ستتغير responsive أيضاً.

**Acceptance Outputs**
- تقليل واضح في async fan-out داخل questions flow.
- تقليل عمليات التحميل المتكرر داخل quran surfaces.
- التمرير والتنقل أكثر استقراراً في الشاشات الثقيلة.

**Verification Expected**
- profiling قبل/بعد باستخدام Flutter DevTools أو مؤشرات frame/build مناسبة.
- قياس عدد مرات التحميل أو parsing قبل وبعد التنفيذ.

**Backend Coordination**  
`No`

**Owner Visual Review**  
`Not Required`

## Execution Order

1. `UI-B01` ثم `UI-B02` لأن أي web-fit أو social-flow لاحق فوق session غير مستقرة سيعيد فتح نفس العيوب.
2. `UI-B03` مباشرة بعد تثبيت session لأن social auth تعتمد على contract واضحة مع backend.
3. `UI-B04` كأساس responsive/web-fit قبل التعديلات الدقيقة على auth surfaces.
4. `UI-B05` بعد foundation responsive لتجنب تكرار نفس إصلاحات القياس والscroll.
5. `UI-B06` بعد تثبيت session والlayout، أو بالتوازي إذا بقيت معزولة عن التعديلات البصرية.

## UI-Only vs Coordination Split

### UI-Only Bundles
- `UI-B01`
- `UI-B02`
- `UI-B04`
- `UI-B05`
- `UI-B06`

### Bundles Requiring Backend Coordination
- `UI-B03`
  - السبب: يجب تأكيد social auth request/response contract مع backend الحالية بعد hardening الأخير.

## Readiness Notes

- هذه الوثيقة backlog تنفيذية، وليست بديلاً عن task implementation docs اللاحقة.
- لا ينبغي دمج `UI-B01`, `UI-B02`, و`UI-B03` داخل task واحدة كبيرة؛ الفصل الحالي يحافظ على وضوح السبب الجذري والتحقق.
- لا ينبغي أيضاً دمج `UI-B04` و`UI-B05` إلا إذا ظهر أثناء التخطيط اللاحق أن أسطح auth هي الشريحة الوحيدة المتأثرة responsive.
