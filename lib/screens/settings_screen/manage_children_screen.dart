import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../widgets/soft_pattern_background.dart';

import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../providers/users_provider.dart';
import '../widgets/custom_back_button.dart';
import '../authentication_screens/add_child_screen.dart';

class ManageChildrenScreen extends StatefulWidget {
  const ManageChildrenScreen({super.key});

  @override
  State<ManageChildrenScreen> createState() => _ManageChildrenScreenState();
}

class _ManageChildrenScreenState extends State<ManageChildrenScreen> {
  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;
  String? _error;

  String _childUsername(Map<String, dynamic> child) {
    return child['username']?.toString() ??
        child['displayName']?.toString() ??
        'child_name_unknown'.tr;
  }

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final usersProvider =
          Provider.of<UsersProvider>(context, listen: false);
      final list = await usersProvider.getChildAccounts();
      if (mounted) {
        setState(() {
          _children = list;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAddChild() async {
    final result = await Get.to(() => const AddChildScreen());
    if (result == true) {
      await _loadChildren();
    }
  }

  Future<void> _switchToChild(Map<String, dynamic> child) async {
    final usersProvider =
        Provider.of<UsersProvider>(context, listen: false);

    final childId = child['userId']?.toString() ?? child['id']?.toString();
    if (childId == null) return;

    final bool? hasPin = child['hasPin'] as bool?;
    String? pin;

    if (hasPin == true && mounted) {
      pin = await _promptForPin(_childUsername(child));
      if (pin == null) return; // user cancelled
    }

    try {
      await usersProvider.switchToChild(childId, pin: pin);
      if (mounted) {
        // Navigate to root — the main screen handles routing based on license state
        Get.offAllNamed('/');
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
    }
  }

  Future<String?> _promptForPin(String childName) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('child_pin_prompt_title'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${'child_pin_prompt_for'.tr} $childName',
                style: AppTypography.of(dialogContext).bodySecondary,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'child_pin_label'.tr,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text('cancel'.tr),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text('confirm'.tr),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _setPinForChild(Map<String, dynamic> child) async {
    final childId = child['userId']?.toString() ?? child['id']?.toString();
    if (childId == null) return;

    final controller = TextEditingController();
    final pin = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('child_set_pin_title'.tr),
          content: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'child_new_pin_label'.tr,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text('cancel'.tr),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text('confirm'.tr),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (pin == null || pin.isEmpty || !mounted) return;

    try {
      final usersProvider =
          Provider.of<UsersProvider>(context, listen: false);
      await usersProvider.setChildPin(childId, pin);
      await _loadChildren();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('child_pin_set_success'.tr),
            backgroundColor: AppColors.successColor,
          ),
        );
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
    }
  }

  Future<void> _deleteChild(Map<String, dynamic> child) async {
    final childId = child['userId']?.toString() ?? child['id']?.toString();
    final childName = _childUsername(child);
    if (childId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('child_delete_confirm_title'.tr),
          content: Text('${'child_delete_confirm_message'.tr} $childName؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('cancel'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('confirm'.tr),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final usersProvider =
          Provider.of<UsersProvider>(context, listen: false);
      await usersProvider.deleteChildAccount(childId);
      // Also remove from device storage if they were saved
      final idNum = int.tryParse(childId);
      if (idNum != null) {
        await usersProvider.removeUserFromDeviceById(idNum);
      }
      await _loadChildren();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    final name = _childUsername(child);
    final hasPin = child['hasPin'] == true;
    final dobRaw = child['dateOfBirth']?.toString();
    String? dobLabel;
    if (dobRaw != null) {
      try {
        final dt = DateTime.parse(dobRaw);
        dobLabel =
            '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Card(
      elevation: 0,
      color: AppColors.panelColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE4EDE9)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.child_care_rounded,
                color: AppColors.primaryPurple,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.of(context).userDisplayName.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryPurple,
                        ),
                  ),
                  if (dobLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      dobLabel,
                      style: AppTypography.of(context)
                          .listTileSubtitle
                          .copyWith(color: AppColors.mutedText, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        hasPin ? Icons.lock_rounded : Icons.lock_open_rounded,
                        size: 12,
                        color: hasPin
                            ? AppColors.successColor
                            : AppColors.mutedText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasPin
                            ? 'child_pin_active'.tr
                            : 'child_pin_none'.tr,
                        style: AppTypography.of(context)
                            .badgeLabel
                            .copyWith(
                              fontSize: 11,
                              color: hasPin
                                  ? AppColors.successColor
                                  : AppColors.mutedText,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.mutedText),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'switch':
                    _switchToChild(child);
                    break;
                  case 'pin':
                    _setPinForChild(child);
                    break;
                  case 'delete':
                    _deleteChild(child);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'switch',
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded,
                          color: AppColors.primaryPurple, size: 18),
                      const SizedBox(width: 10),
                      Text('child_action_switch'.tr),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'pin',
                  child: Row(
                    children: [
                      Icon(
                        hasPin
                            ? Icons.lock_reset_rounded
                            : Icons.lock_outline_rounded,
                        color: AppColors.primaryPurple,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(hasPin
                          ? 'child_action_change_pin'.tr
                          : 'child_action_set_pin'.tr),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 10),
                      Text('child_action_delete'.tr,
                          style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
              'child_manage_title'.tr,
              style: AppTypography.of(context)
                  .appBarTitle
                  .copyWith(color: AppColors.blackFontColor),
            ),
            centerTitle: true,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddChild,
        backgroundColor: AppColors.primaryPurple,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: Text(
          'child_add_fab'.tr,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SoftPatternBackground(
        child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryPurple,
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: AppTypography.of(context)
                              .bodySecondary
                              .copyWith(color: Colors.red)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _loadChildren,
                        child: Text('retry'.tr),
                      ),
                    ],
                  ),
                )
              : _children.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.child_care_rounded,
                            size: 48,
                            color: AppColors.primaryPurple.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'child_manage_empty_title'.tr,
                            style: AppTypography.of(context)
                                .subsectionTitle
                                .copyWith(color: AppColors.primaryPurple),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'child_manage_empty_body'.tr,
                            style: AppTypography.of(context)
                                .bodySecondary
                                .copyWith(color: AppColors.mutedText),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      itemCount: _children.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _buildChildCard(_children[index]),
                    ),
      ),
    );
  }
}
