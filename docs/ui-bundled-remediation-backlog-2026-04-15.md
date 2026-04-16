# Frontend Users UI Bundled Remediation Backlog

تاريخ التحديث: 2026-04-15
النطاق: E:\Sahifati\frontend_users\ui
المرجع: docs/project-analysis-2026-04-14.md

## الهدف

هذه الوثيقة تحول الملاحظات الحالية في frontend_users/ui إلى backlog تنفيذية مجمعة ومحددة الحدود، من دون إعادة صياغة التحليل العام. المقصود هو إبقاء ست حزم مستقلة بترتيبها واعتمادها الحاليين.

## Evidence Anchors From Quick Analysis

- `main.dart` يقيد التطبيق على portrait في الجذر ويشغل فحص الاتصال داخل build.
- `size_config.dart` يبني القياسات على baseline ثابتة `375x812`.
- `login_screen.dart` يحتوي nested `SingleChildScrollView`.
- `users_provider.dart` و`select_user_screen.dart` يحفظان بيانات حساسة محلياً.
- `sahifaty_api.dart` يقرأ session artifacts مباشرة من shared preferences.
- `content_item_card.dart` و`index_page.dart` يحملان بيانات القراءة والتقييم بشكل متكرر.

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
- Goal: إغلاق مسارات تخزين الأسرار محلياً ومنع الاعتماد على كلمة المرور أو session secrets خارج طبقة session المقصودة.
- Primary Surfaces: `lib/providers/users_provider.dart`, `lib/services/sahifaty_api.dart`, `lib/services/users_services.dart`, `lib/screens/authentication_screens/login_screen.dart`, `lib/screens/authentication_screens/select_user_screen.dart`.
- Root Cause: خلط بين cached user data وsession state مع حفظ كلمات مرور وطباعة معلومات حساسة في debug.
- Scope: إزالة حفظ كلمة المرور محلياً، منع login المتفائل من بيانات مخزنة، إزالة logging الحساسة، وتوحيد access/refresh token path.
- Out Of Scope: إعادة تصميم auth backend أو إعادة بناء UX المصادقة بالكامل.
- Dependencies / Order: تنفذ أولاً، لأنها أساس UI-B02 وUI-B03.
- Acceptance Outputs: لا تبقى كلمة المرور ضمن local storage، لا تبقى session secrets في logs، ويوجد مصدر حقيقة واحد لبيانات الجلسة.
- Verification Expected: smoke check لمسارات login/logout/app restart، ومراجعة نصية لغياب logging الحساسة.
- Backend Coordination: `No`
- Owner Visual Review: `Not Required`

### UI-B02 - Auto-Login And Session Bootstrap Gating
- Goal: منع دخول التطبيق إلى main flow اعتماداً على user cache أو حالة محلية غير موثقة بدلاً من session صالحة فعلياً.
- Primary Surfaces: `lib/main.dart`, `lib/controllers/users_controller.dart`, `lib/providers/users_provider.dart`, `lib/screens/authentication_screens/select_user_screen.dart`, `lib/screens/main_screen/main_screen.dart`.
- Root Cause: منطق الإقلاع الحالي لا يميز بدقة بين user presence محلياً وبين session قابلة للاستخدام.
- Scope: جعل bootstrap decision مبنياً على session validation، فصل حالات restoring/authenticated/unauthenticated/offline-limited، ومنع الانتقال إلى `MainScreen` عند غياب token صالح أو فشل restore.
- Out Of Scope: caching strategy جديدة أو offline mode كامل.
- Dependencies / Order: تعتمد على UI-B01 وتسبق UI-B03 وUI-B04.
- Acceptance Outputs: startup gating تصبح موحدة وصريحة، ولا يصل المستخدم إلى main flow بجلسة غير مكتملة.
- Verification Expected: سيناريوهات bootstrap المختلفة، وchecks لمسارات startup routing.
- Backend Coordination: `Conditional`
- Owner Visual Review: `Not Required`

### UI-B03 - Social Auth Contract Alignment With Backend
- Goal: تطابق social auth داخل UI مع واجهات backend الحالية بدلاً من assumptions قديمة أو payloads غير مدعومة.
- Primary Surfaces: `lib/services/sahifaty_api.dart`, `lib/services/users_services.dart`, `lib/controllers/users_controller.dart`, `lib/screens/authentication_screens/login_screen.dart`.
- Root Cause: social auth flow في UI لم يعد مضمون التطابق مع API الحالية بعد hardening backend.
- Scope: مراجعة payloads لكل provider، إزالة assumptions القديمة، وتوحيد success/failure handling.
- Out Of Scope: إضافة provider جديد أو إعادة بناء backend social auth.
- Dependencies / Order: تعتمد على UI-B01 وUI-B02.
- Acceptance Outputs: social auth requests تصير مطابقة للعقد الخلفي الحالي، ولا يبقى bypass محلي بسبب contract mismatch.
- Verification Expected: contract verification ضد endpoints الحالية، وsuccessful/failed login checks لكل provider متاح.
- Backend Coordination: `Yes`
- Owner Visual Review: `Not Required`

### UI-B04 - Web Layout Responsiveness And Desktop-Fit Foundation
- Goal: إزالة الانجراف الناتج عن baseline الهاتف الثابتة وتمكين صفحات الويب من التمدد والتقلص بشكل صحيح على tablet/desktop.
- Primary Surfaces: `lib/main.dart`, `lib/core/utils/size_config.dart`, `lib/screens/main_screen/main_screen.dart`, `lib/screens/sahifa_screen/sahifa_screen.dart`, `lib/screens/widgets/bar_chart_widget.dart`.
- Root Cause: الاعتماد على baseline `375x812` مع قيود اتجاه ودوال قياس ثابتة خلق layout drift على web.
- Scope: إزالة الافتراضات الصلبة الخاصة بمقاس الهاتف، تعريف responsive rules مناسبة للويب، وتحسين chart/dashboard sizing وalignment وspacing.
- Out Of Scope: polishing بصري شامل أو إعادة branding/theme system.
- Dependencies / Order: يمكن تنفيذها بعد تثبيت session bundles، وتسبق أي polishing تفصيلي للشاشات الفردية.
- Acceptance Outputs: الشاشة الرئيسية وsurface القراءة تتكيفان بشكل مفهوم على mobile/tablet/desktop web، ولا تبقى chart/dashboard محصورة في portrait phone.
- Verification Expected: visual review على mobile/tablet/desktop web ومقارنة responsive لسطح dashboard والقراءة.
- Backend Coordination: `No`
- Owner Visual Review: `Required`

### UI-B05 - Login/Auth Scroll And Interaction Stability
- Goal: إزالة مشاكل nested scroll والارتباك التفاعلي في شاشات الدخول والاختيار، خصوصاً على web والأحجام الصغيرة أو المتوسطة.
- Primary Surfaces: `lib/screens/authentication_screens/login_screen.dart`, `lib/screens/authentication_screens/select_user_screen.dart`.
- Root Cause: شاشات auth الحالية تعاني من scroll nesting وقياسات محتوى غير مستقرة.
- Scope: إزالة scroll nesting غير الضروري، توحيد سلوك overflow والتركيز، وضبط interaction states أثناء التحميل والفشل.
- Out Of Scope: تعديل business logic الخاص بالمصادقة أو إعادة تصميم كامل لشكل auth.
- Dependencies / Order: يفضل بعد UI-B02 وUI-B04 حتى لا تعاد معالجة نفس الشاشات مرتين.
- Acceptance Outputs: لا يوجد nested scroll معطل، وتبقى الحقول والأزرار قابلة للاستخدام دون قص أو اهتزاز.
- Verification Expected: visual review لشاشات auth على mobile/tablet/web وkeyboard/overflow checks.
- Backend Coordination: `No`
- Owner Visual Review: `Required`

### UI-B06 - Questions And Quran Async/Performance Consolidation
- Goal: تقليل N+1 loading والتكرار الثقيل في `questions` و`quran_view` وتحويل القراءة والتحميل إلى مسارات مركزية قابلة للقياس.
- Primary Surfaces: `lib/screens/questions_screen/questions_screen.dart`, `lib/screens/questions_screen/content_item_card.dart`, `lib/screens/quran_view/index_page.dart`, `lib/screens/quran_view/quran_view.dart`.
- Root Cause: بعض الشاشات تحمل البيانات وتعيد تقييمها بشكل متكرر داخل loops أو lifecycle غير مركزي.
- Scope: تجميع async loading في questions screen، منع التحميل المتكرر للمصادر نفسها، وتحسين بناء القوائم الثقيلة والحد من full rebuild patterns.
- Out Of Scope: offline architecture كاملة أو إعادة هيكلة كل state management في التطبيق.
- Dependencies / Order: يمكن تنفيذها بالتوازي بعد P0، ويفضل بعد UI-B04 إذا كانت بعض surfaces ستتغير responsive أيضاً.
- Acceptance Outputs: تقليل واضح في async fan-out وعمليات التحميل المتكرر، وتحسن استقرار التمرير والتنقل في الشاشات الثقيلة.
- Verification Expected: profiling قبل/بعد وقياس عدد مرات التحميل أو parsing.
- Backend Coordination: `No`
- Owner Visual Review: `Not Required`

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
