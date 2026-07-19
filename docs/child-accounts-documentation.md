# توثيق نظام تسجيل حسابات الأطفال

## 1. نظرة عامة

يعمل نظام حسابات الأطفال وفق نمط **"الحساب المُدار" (Managed Child Account)**: كل طفل هو سجل `User` كامل في قاعدة البيانات مع `authProvider = 'managed_child'` وحقل `guardianUserId` يربطه بولي أمره. لا يملك الطفل بريد إلكتروني أو كلمة مرور خاصة به — بل يتم الوصول لحسابه عبر بيانات ولي الأمر أو رمز PIN اختياري.

---

## 2. نقاط نهاية API

### 2.1 إنشاء حساب طفل
```
POST /auth/child
Authorization: Bearer <guardian JWT>
Body: { username: string, birthYear?: number }
Response 201: { userId, username, authProvider: 'managed_child', birthYear, guardianUserId }
```

### 2.2 قائمة الأطفال
```
GET /auth/child
Authorization: Bearer <guardian JWT>
Response 200: [{ userId, username, birthYear, lastLoginAt, hasPin }]
```

### 2.3 التبديل إلى حساب الطفل
```
POST /auth/child/switch
Authorization: Bearer <guardian JWT>
Body: { childId: string, pin?: string }
Response 200: { accessToken, refreshToken, id, username, email, userRoleId, authProvider: 'managed_child', guardianUserId, licenseStatus }
```

### 2.4 تعيين رمز PIN للطفل
```
POST /auth/child/pin
Authorization: Bearer <guardian JWT>
Body: { childId: string, pin: string }
Response 200: { message: 'PIN set successfully' }
```

### 2.5 حذف حساب الطفل
```
DELETE /auth/child/:childId
Authorization: Bearer <guardian JWT>
Response 200: { message: 'Child account deleted successfully' }
```

### 2.6 إعادة تسمية حساب الطفل
```
PATCH /auth/child/:childId/rename
Authorization: Bearer <guardian JWT>
Body: { username: string }
Response 200: { message: 'Child account renamed successfully' }
```

### 2.7 تسجيل دخول الطفل (عام)
```
POST /auth/child/login
Body: { guardianEmail: string, password: string, childId: string }
Response 200: { accessToken, refreshToken, user: {...}, authProvider: 'managed_child', guardianUserId }
```

### 2.8 خيارات تسجيل دخول الطفل (عام)
```
POST /auth/child/login/options
Body: { guardianEmail: string, password: string }
Response 200: [{ childId, username, birthYear, lastLoginAt }]
```

---

## 3. قواعد التحقق (Validation)

### 3.1 الواجهة (Flutter)
| الحقل | القاعدة |
|-------|---------|
| اسم الطفل | مطلوب، 2-50 حرف |
| سنة الميلاد | اختياري، نطاق آخر 16 سنة (العمر 3-18) |
| رمز PIN | أقصى 6 أرقام، لوحة أرقام |
| بريد ولي الأمر | تنسيق بريد إلكتروني صحيح |
| كلمة مرور ولي الأمر | غير فارغة |

### 3.2 الخادم (API - DTOs)
| الحقل | التحقق |
|-------|--------|
| `username` | `@IsString`, `@MinLength(2)`, `@MaxLength(50)` |
| `birthYear` | `@IsOptional`, `@IsInt`, `@Min(1924)`, `@Max(currentYear)` |
| `guardianEmail` | `@IsEmail()` |
| `childId` | `@IsString()` |
| `pin` | `@IsString()` |

---

## 4. قواعد العمل والأمن

1. **لا يمكن للحساب الفرعي إنشاء حسابات فرعية أخرى** — يتم التحقق من أن `guardian.authProvider !== 'managed_child'`
2. **لا يمكن للحساب الفرعي إدارة الأطفال** — يتم إخفاء قائمة "إدارة حسابات الأطفال" من الدرج الجانبي إذا كان المستخدم الحالي طفلاً
3. **رمز PIN يُخزن مشفراً بـ bcrypt** (cost factor 12) ولا يُعاد أبداً في استجابات API
4. **عند التبديل لحساب طفل** — إذا كان لديه PIN، يجب تقديمه وإلا فشل التبديل
5. **الاسم المكرر** يُرجع `ConflictException('child_name_taken')`
6. **ولي الأمر يجب أن يملك بريداً مُحققاً منه** — يُمنع تسجيل الدخول كطفل إذا لم يتحقق البريد
7. **الاسم الداخلي** بصيغة `child_<guardianId>_<timestamp>_<random>` — يمنع التصادم ويخفي البنية
8. **حقول محمية**: `guardianUserId` و `childPinHash` في `PRIVILEGE_ONLY_FIELDS` — تُزال من تحديثات المستخدم العادية

---

## 5. هيكل قاعدة البيانات (MongoDB Schema)

| الحقل | النوع | الخصائص | الغرض |
|-------|------|---------|-------|
| `authProvider` | `String` | enum: `['email','google','facebook','apple','huawei','managed_child']`, default: `'email'`, indexed | يميز حسابات الأطفال |
| `guardianUserId` | `Mixed` | ref: `'User'`, indexed, sparse, default: null | يربط الطفل بولي أمره |
| `childPinHash` | `String` | select: false, default: null | تجزئة bcrypt لرمز PIN |
| `dateOfBirth` | `Date` | default: null | تاريخ ميلاد الطفل |
| `email` | `String` | unique, sparse, indexed | "مطلوب للبريد/التسجيل الاجتماعي؛ غائب لـ managed_child" |
| `firstName` | `String` | — | الاسم المعروض لحسابات الأطفال |

---

## 6. ملفات الواجهة (Flutter App)

| # | الملف | الدور |
|---|-------|-------|
| 1 | `lib/screens/authentication_screens/add_child_screen.dart` | نموذج إنشاء حساب طفل |
| 2 | `lib/screens/authentication_screens/child_login_screen.dart` | شاشة تسجيل دخول الطفل من أي جهاز |
| 3 | `lib/screens/authentication_screens/select_user_screen.dart` | مختار الحسابات (يوجّه حسابات الأطفال إلى ChildLoginScreen) |
| 4 | `lib/screens/settings_screen/manage_children_screen.dart` | إدارة الأطفال (قائمة/تبديل/إعادة تسمية/PIN/حذف) |
| 5 | `lib/screens/settings/security_settings_screen.dart` | يعرض `managed_child` كـ "حساب فرعي" |
| 6 | `lib/screens/widgets/global_drawer.dart` | يخفي "إدارة الأطفال" من الحسابات الفرعية |
| 7 | `lib/models/user.dart` | نموذج المستخدم مع `guardianUserId`, `isChildAccount`, اشتقاق مفتاح الحساب |
| 8 | `lib/providers/users_provider.dart` | إدارة الحالة: createChildAccount, getChildAccounts, switchToChild, setChildPin, deleteChildAccount, renameChildAccount, loginAsChild, getChildLoginOptions |
| 9 | `lib/services/users_services.dart` | خدمة HTTP: getChildLoginOptions, loginChild |
| 10 | `lib/core/auth/post_auth_navigation.dart` | التنقل بعد تسجيل الدخول |
| 11 | `assets/json/intl_ar.json` | مفاتيح الترجمة العربية لكل نصوص child_ |

---

## 7. ملفات الخادم (API)

| # | الملف | الدور |
|---|-------|-------|
| 1 | `src/auth/auth.controller.ts` | نقاط نهاية REST لعمليات الأطفال |
| 2 | `src/auth/auth.service.ts` | المنطق البرمجي: createChildAccount, listChildren, switchToChild, setChildPin, deleteChild, renameChild, loginChild, getChildLoginOptions |
| 3 | `src/auth/dto.ts` | DTOs: CreateChildAccountDto, SwitchToChildDto, SetChildPinDto, RenameChildDto, ChildLoginOptionsDto, ChildLoginDto |
| 4 | `src/auth/auth.module.ts` | ربط الوحدات |
| 5 | `src/auth/auth.service.spec.ts` | اختبارات وحدة لتسجيل دخول الطفل |
| 6 | `src/users/users.schema.ts` | مخطط Mongoose مع guardianUserId, childPinHash, dateOfBirth, managed_child |
| 7 | `src/users/users.service.ts` | طبقة البيانات: createManagedChild, findChildrenOf, findChildOfGuardian, childHasPin, verifyChildPin, setChildPinHash |
| 8 | `src/users/users.service.spec.ts` | اختبار createManagedChild |
| 9 | `src/users/users.controller.ts` | قائمة المستخدمين الإدارية مع فلاتر authProvider/guardianUserId |

---

## 8. تدفق العمليات

### 8.1 إنشاء حساب طفل جديد
```
ولي الأمر → AddChildScreen → UsersProvider.createChildAccount()
→ POST /auth/child { username, birthYear }
→ AuthService.createChildAccount()
   ├── التحقق من أن ولي الأمر ليس حساباً فرعياً
   ├── UsersService.createManagedChild()
   │   ├── توليد internalUsername = 'child_<guardianId>_<timestamp>_<random>'
   │   ├── تعيين authProvider = 'managed_child'
   │   ├── تعيين emailVerified = true
   │   └── تعيين roleNum = 0
   └── إرجاع بيانات الطفل
```

### 8.2 التبديل إلى حساب الطفل
```
ولي الأمر → ManageChildrenScreen → UsersProvider.switchToChild(childId, pin?)
→ POST /auth/child/switch { childId, pin? }
→ AuthService.switchToChild()
   ├── التحقق من أن الطفل ينتمي لولي الأمر
   ├── إذا كان PIN مُفعّلاً: التحقق من صحة PIN
   ├── إصدار JWT tokens مع authProvider = 'managed_child'
   └── إرجاع { accessToken, refreshToken, user, licenseStatus }
```

### 8.3 تسجيل دخول الطفل من جهاز جديد
```
الطفل → SelectUserScreen → ChildLoginScreen
→ إدخال بريد + كلمة مرور ولي الأمر
→ UsersProvider.getChildLoginOptions()
→ POST /auth/child/login/options { guardianEmail, password }
→ AuthService.getChildLoginOptions()
   ├── مصادقة ولي الأمر
   └── إرجاع قائمة الأطفال
→ اختيار الطفل
→ UsersProvider.loginAsChild()
→ POST /auth/child/login { guardianEmail, password, childId }
→ AuthService.loginChild()
   ├── مصادقة ولي الأمر
   ├── التحقق من أن الطفل ينتمي لولي الأمر
   └── إصدار JWT tokens
```

---

## 9. مفاتيح الترجمة العربية

| المفتاح | القيمة العربية |
|--------|---------------|
| `child_add_title` | إضافة حساب طفل |
| `child_add_subtitle` | أدخل اسم الطفل وتاريخ ميلاده (اختياري) |
| `child_add_confirm` | إضافة الحساب |
| `child_add_fab` | إضافة طفل |
| `child_name_label` | اسم الطفل |
| `child_name_required` | الاسم مطلوب |
| `child_name_too_short` | الاسم قصير جداً، أدخل حرفين على الأقل |
| `child_name_too_long` | الاسم طويل جداً، الحد الأقصى 50 حرفاً |
| `child_name_taken` | هذا الاسم مستخدم بالفعل |
| `child_name_unknown` | طفل |
| `child_dob_label` | تاريخ الميلاد |
| `child_dob_optional` | اختياري |
| `child_dob_picker_title` | اختر تاريخ الميلاد |
| `child_login_title` | تسجيل دخول الطفل |
| `child_login_subtitle` | استخدم بريد ولي الأمر واسم الطفل ورمز PIN |
| `child_login_action` | دخول كطفل |
| `child_login_guardian_email_label` | بريد ولي الأمر |
| `child_login_guardian_password_label` | كلمة مرور وليّ الأمر |
| `child_login_children_label` | الأطفال المرتبطون |
| `child_login_load_children` | جارٍ تحميل الأطفال... |
| `child_login_no_children` | لا توجد حسابات أطفال متاحة |
| `child_login_child_required` | اختر طفلًا أولًا |
| `child_manage_title` | حسابات الأطفال |
| `child_manage_settings_entry` | إدارة حسابات الأطفال |
| `child_manage_empty_title` | لا توجد حسابات أطفال |
| `child_action_switch` | التبديل إلى هذا الحساب |
| `child_action_rename` | تعديل الاسم |
| `child_action_set_pin` | تعيين رمز PIN |
| `child_action_change_pin` | تغيير رمز PIN |
| `child_action_delete` | حذف الحساب |
| `child_pin_active` | رمز PIN مفعّل |
| `child_pin_none` | لا يوجد رمز PIN |
| `child_pin_not_set` | هذا الطفل لا يملك رمز PIN بعد |
| `child_pin_prompt_title` | أدخل رمز PIN |
| `child_set_pin_title` | تعيين رمز PIN |
| `child_rename_title` | تعديل اسم الطفل |
| `child_rename_success` | تم تعديل الاسم بنجاح |
| `child_delete_confirm_title` | حذف حساب الطفل |
| `child_delete_confirm_message` | هل تريد حذف حساب |
| `child_create_error` | تعذر إنشاء الطفل |
| `child_session_expired_title` | انتهت الجلسة |
| `child_session_expired_body` | حساب الطفل لا يُفعَّل من هنا |

---

## 10. DTOs التفصيلية

### CreateChildAccountDto
```typescript
class CreateChildAccountDto {
  @IsString()
  @MinLength(2)
  @MaxLength(50)
  username: string;

  @IsOptional()
  @IsInt()
  @Min(1924)
  @Max(currentYear)
  birthYear?: number;
}
```

### SwitchToChildDto
```typescript
class SwitchToChildDto {
  @IsString()
  childId: string;

  @IsOptional()
  @IsString()
  pin?: string;
}
```

### SetChildPinDto
```typescript
class SetChildPinDto {
  @IsString()
  childId: string;

  @IsString()
  pin: string;
}
```

### RenameChildDto
```typescript
class RenameChildDto {
  @IsString()
  @MinLength(2)
  @MaxLength(50)
  username: string;
}
```

### ChildLoginOptionsDto
```typescript
class ChildLoginOptionsDto {
  @IsEmail()
  guardianEmail: string;

  @IsString()
  password: string;
}
```

### ChildLoginDto
```typescript
class ChildLoginDto {
  @IsEmail()
  guardianEmail: string;

  @IsString()
  password: string;

  @IsString()
  childId: string;
}
```

---

## 11. وثائق إضافية في المشروع

- `E:\Sahifati\sahifati_api\docs\child-accounts-technical-design-2026-05-10.md` — التصميم التقني لحسابات الأطفال
- `E:\Sahifati\sahifati_api\docs\child-managed-accounts-decision-2026-05-10.md` — قرار البنية المعمارية