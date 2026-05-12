import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../providers/users_provider.dart';
import '../widgets/custom_back_button.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int? _birthYear;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickYear() async {
    final now = DateTime.now();
    final years = List.generate(16, (i) => now.year - 3 - i);
    final picked = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: 340,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'child_dob_picker_title'.tr,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: years.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(
                    years[i].toString(),
                    textAlign: TextAlign.center,
                  ),
                  selected: years[i] == _birthYear,
                  selectedTileColor:
                      AppColors.primaryPurple.withValues(alpha: 0.08),
                  onTap: () => Navigator.pop(ctx, years[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _birthYear = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final usersProvider =
          Provider.of<UsersProvider>(context, listen: false);
      await usersProvider.createChildAccount(
        _nameController.text.trim(),
        birthYear: _birthYear,
      );
      if (mounted) {
        Get.back(result: true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(
            backgroundColor: AppColors.backgroundColor,
            elevation: 0,
            leading: CustomBackButton(
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'child_add_title'.tr,
              style: AppTypography.of(context)
                  .appBarTitle
                  .copyWith(color: AppColors.blackFontColor),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'child_add_subtitle'.tr,
                style: AppTypography.of(context)
                    .bodySecondary
                    .copyWith(color: AppColors.mutedText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: 'child_name_label'.tr,
                  prefixIcon: const Icon(Icons.person_outline,
                      color: AppColors.primaryPurple),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primaryPurple,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'child_name_required'.tr;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: _pickYear,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'child_dob_label'.tr,
                    prefixIcon: const Icon(Icons.cake_outlined,
                        color: AppColors.primaryPurple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    suffixIcon: _birthYear != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () =>
                                setState(() => _birthYear = null),
                          )
                        : null,
                  ),
                  child: Text(
                    _birthYear != null
                        ? _birthYear.toString()
                        : 'child_dob_optional'.tr,
                    style: AppTypography.of(context).bodyDefault.copyWith(
                          color: _birthYear != null
                              ? AppColors.blackFontColor
                              : AppColors.mutedText,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    disabledBackgroundColor:
                        AppColors.primaryPurple.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'child_add_confirm'.tr,
                          style: AppTypography.of(context)
                              .buttonPrimary
                              .copyWith(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
