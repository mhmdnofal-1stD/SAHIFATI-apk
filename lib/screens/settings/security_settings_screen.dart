import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/users_provider.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({Key? key}) : super(key: key);

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearMessages() {
    setState(() {
      _error = null;
      _success = null;
    });
  }

  Future<void> _setLocalPassword() async {
    _clearMessages();

    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'كلمة المرور مطلوبة');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'كلمات المرور غير متطابقة');
      return;
    }

    setState(() => _loading = true);

    try {
      final result = await context.read<UsersProvider>().setLocalPassword(
            password: _passwordController.text,
            confirmPassword: _confirmPasswordController.text,
          );

      if (result) {
        setState(() {
          _success =
              'تم تعيين كلمة المرور بنجاح! يمكنك الآن الدخول بالبريد الإلكتروني وكلمة المرور.';
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
      } else {
        setState(() => _error = 'حدث خطأ أثناء تعيين كلمة المرور');
      }
    } catch (e) {
      setState(() => _error = 'خطأ: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = context.watch<UsersProvider>();
    final user = usersProvider.selectedUser;
    final authProvider = user?.authProvider ?? 'email';
    final isSocialAuth = authProvider != 'email';

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الأمان'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Auth Provider Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نوع الحساب الحالي',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getAuthProviderDisplayName(authProvider),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isSocialAuth) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'حسابك مسجل لدينا عبر $authProvider. يمكنك الدخول مباشرة باستخدام زره دون الحاجة لكلمة مرور.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isSocialAuth) ...[
              Text(
                'تعيين كلمة مرور محليّة',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'تحويل حسابك ليقبل الدخول بالبريد وكلمة مرور إضافة إلى $authProvider',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  hintText: 'يجب أن تحتوي على أحرف وأرقام ورموز',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _showPassword = !_showPassword);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: !_showConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  hintText: 'أعد إدخال كلمة المرور',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(
                          () => _showConfirmPassword = !_showConfirmPassword);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              if (_success != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _success!,
                    style: TextStyle(color: Colors.green.shade900),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _setLocalPassword,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('تعيين كلمة المرور'),
                ),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.lock_outlined,
                        size: 48,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'حسابك محمي',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'أنت تستخدم بالفعل كلمة مرور محليّة للدخول إلى حسابك.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getAuthProviderDisplayName(String provider) {
    const names = {
      'email': 'بريد إلكتروني وكلمة مرور',
      'google': 'Google',
      'apple': 'Apple',
      'facebook': 'Facebook',
      'huawei': 'Huawei',
      'managed_child': 'حساب فرعي',
    };
    return names[provider] ?? provider;
  }
}
