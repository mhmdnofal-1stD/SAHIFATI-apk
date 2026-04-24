import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/utils/size_config.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/colors.dart';
import '../../models/profile_location_lookup.dart';
import '../../models/user.dart';
import '../../providers/general_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/users_provider.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/no_pop_scope.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<Map<String, String>> _genderOptions = [
    {'value': 'male', 'labelKey': 'settings_gender_male'},
    {'value': 'female', 'labelKey': 'settings_gender_female'},
  ];

  static const List<Map<String, String>> _educationLevelOptions = [
    {'value': 'illiterate', 'labelKey': 'settings_education_illiterate'},
    {'value': 'preparatory', 'labelKey': 'settings_education_preparatory'},
    {'value': 'high_school', 'labelKey': 'settings_education_high_school'},
    {
      'value': 'college_diploma',
      'labelKey': 'settings_education_college_diploma',
    },
    {'value': 'bachelor', 'labelKey': 'settings_education_bachelor'},
    {'value': 'master', 'labelKey': 'settings_education_master'},
    {'value': 'doctorate', 'labelKey': 'settings_education_doctorate'},
    {'value': 'professor', 'labelKey': 'settings_education_professor'},
  ];

  static const List<Map<String, String>> _workTypeOptions = [
    {'value': 'commercial', 'labelKey': 'settings_work_commercial'},
    {'value': 'educational', 'labelKey': 'settings_work_educational'},
    {'value': 'technical', 'labelKey': 'settings_work_technical'},
    {'value': 'craftsman', 'labelKey': 'settings_work_craftsman'},
    {'value': 'legal', 'labelKey': 'settings_work_legal'},
    {'value': 'healthcare', 'labelKey': 'settings_work_healthcare'},
    {'value': 'logistics', 'labelKey': 'settings_work_logistics'},
    {'value': 'child', 'labelKey': 'settings_work_child'},
    {'value': 'student', 'labelKey': 'settings_work_student'},
    {'value': 'not_working', 'labelKey': 'settings_work_not_working'},
    {'value': 'housewife', 'labelKey': 'settings_work_housewife'},
    {'value': 'retired', 'labelKey': 'settings_work_retired'},
  ];

  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  late TapGestureRecognizer _emailRecognizer;

  ProfileLocationLookup? _locationLookup;
  ProfileCountry? _selectedCountry;
  String? _selectedCity;
  String? _selectedGender;
  String? _selectedEducationLevel;
  String? _selectedWorkType;
  int? _selectedBirthYear;
  bool _locationLookupLoaded = false;
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _emailRecognizer = TapGestureRecognizer()..onTap = _launchEmail;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Provider.of<LanguageProvider>(context, listen: false)
          .fetchLanguages();
      await _loadLocationLookup();
      await _loadProfile();
    });
  }

  @override
  void dispose() {
    _emailRecognizer.dispose();
    _fullNameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationLookup() async {
    try {
      final rawLookup = await rootBundle
          .loadString('assets/json/profile_location_lookup.json');
      final lookup = ProfileLocationLookup.fromJson(
        jsonDecode(rawLookup) as Map<String, dynamic>,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _locationLookup = lookup;
        _locationLookupLoaded = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationLookupLoaded = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings_location_lookup_load_error'.trParams({
              'error': error.toString(),
            }),
          ),
        ),
      );
    }
  }

  Future<void> _loadProfile() async {
    try {
      final user = await context.read<UsersProvider>().loadCurrentUserProfile();
      if (!mounted || user == null) {
        return;
      }
      _applyUserProfile(user);
    } catch (error) {
      if (mounted) {
        setState(() {
          _profileLoaded = true;
        });
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings_profile_load_error'.trParams({
              'error': error.toString(),
            }),
          ),
        ),
      );
    }
  }

  void _applyUserProfile(User user) {
    final resolvedCountry = _locationLookup?.findByName(user.country) ??
        _locationLookup?.findByPhoneCode(user.countryCode);
    final resolvedCity = (user.city?.trim().isNotEmpty ?? false)
        ? user.city!.trim()
        : ((user.state?.trim().isNotEmpty ?? false)
            ? user.state!.trim()
            : null);

    setState(() {
      _fullNameController.text = user.fullName;
      _mobileController.text = user.mobile ?? '';
      _selectedGender = user.gender;
      _selectedBirthYear = user.birthYear;
      _selectedCountry = resolvedCountry;
      _selectedCity = resolvedCity;
      _selectedEducationLevel = _normalizeOptionValue(
        user.educationLevel,
        _educationLevelOptions,
      );
      _selectedWorkType = _normalizeOptionValue(
        user.workType,
        _workTypeOptions,
      );
      _profileLoaded = true;
    });
  }

  String? _normalizeOptionValue(
    String? value,
    List<Map<String, String>> options,
  ) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final optionExists = options.any((option) => option['value'] == value);
    return optionExists ? value : null;
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'info@sahifati.com',
      query: 'subject=Feedback',
    );
    try {
      if (!await launchUrl(emailLaunchUri) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings_email_client_error'.tr),
          ),
        );
      }
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  Future<T?> _showSearchablePicker<T>({
    required String title,
    required String searchLabel,
    required List<T> items,
    required String Function(T item) itemLabel,
    String Function(T item)? itemSubtitle,
    required String emptyMessage,
  }) async {
    final searchController = TextEditingController();

    final selected = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = searchController.text.trim().toLowerCase();
            final filteredItems = items.where((item) {
              final label = itemLabel(item).toLowerCase();
              final subtitle = itemSubtitle?.call(item).toLowerCase() ?? '';
              return query.isEmpty ||
                  label.contains(query) ||
                  subtitle.contains(query);
            }).toList();

            return SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.78,
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: searchLabel,
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) {
                        setSheetState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredItems.isEmpty
                        ? Center(
                            child: Text(
                              emptyMessage,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final subtitle = itemSubtitle?.call(item);
                              return ListTile(
                                title: Text(itemLabel(item)),
                                subtitle: subtitle == null || subtitle.isEmpty
                                    ? null
                                    : Text(subtitle),
                                onTap: () {
                                  Navigator.of(sheetContext).pop(item);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
    return selected;
  }

  Future<void> _pickCountry() async {
    final lookup = _locationLookup;
    if (lookup == null) {
      _showValidationMessage('settings_country_list_load_error'.tr);
      return;
    }

    final selectedCountry = await _showSearchablePicker<ProfileCountry>(
      title: 'settings_picker_country_title'.tr,
      searchLabel: 'settings_picker_country_search'.tr,
      items: lookup.countries,
      itemLabel: (country) => country.displayName,
      itemSubtitle: (country) => '+${country.phoneCode}',
      emptyMessage: 'settings_picker_country_empty'.tr,
    );

    if (selectedCountry == null) {
      return;
    }

    setState(() {
      _selectedCountry = selectedCountry;
      if (!_selectedCountry!.hasCity(_selectedCity)) {
        _selectedCity = null;
      }
    });
  }

  Future<void> _pickCity() async {
    final selectedCountry = _selectedCountry;
    if (selectedCountry == null) {
      _showValidationMessage('settings_validation_pick_country_first'.tr);
      return;
    }
    if (selectedCountry.cities.isEmpty) {
      _showValidationMessage('settings_validation_no_cities'.tr);
      return;
    }

    final selectedCity = await _showSearchablePicker<String>(
      title: 'settings_picker_city_title'.tr,
      searchLabel: 'settings_picker_city_search'.tr,
      items: selectedCountry.cities,
      itemLabel: (city) => city,
      emptyMessage: 'settings_picker_city_empty'.tr,
    );

    if (selectedCity == null) {
      return;
    }

    setState(() {
      _selectedCity = selectedCity;
    });
  }

  List<int> _buildDecades() {
    final currentYear = DateTime.now().year;
    final currentDecade = currentYear - (currentYear % 10);
    final minYear = currentYear - 99;
    final minDecade = minYear - (minYear % 10);
    final decades = <int>[];

    for (int decade = currentDecade; decade >= minDecade; decade -= 10) {
      decades.add(decade);
    }

    return decades;
  }

  List<int> _buildYearsForDecade(int decadeStart) {
    final currentYear = DateTime.now().year;
    final minYear = currentYear - 99;
    final decadeEnd = decadeStart + 9;
    final maxYear = decadeEnd > currentYear ? currentYear : decadeEnd;
    final years = <int>[];

    for (int year = maxYear; year >= decadeStart; year--) {
      if (year >= minYear) {
        years.add(year);
      }
    }

    return years;
  }

  Future<void> _pickBirthYear() async {
    final selectedYear = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        int? activeDecade;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SizedBox(
              height: 420,
              child: Column(
                children: [
                  ListTile(
                    leading: activeDecade != null
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {
                              setSheetState(() {
                                activeDecade = null;
                              });
                            },
                          )
                        : const Icon(Icons.event),
                    title: Text(
                      activeDecade == null
                          ? 'settings_birth_year_pick_decade'.tr
                          : 'settings_birth_year_pick_year'.tr,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      children: activeDecade == null
                          ? _buildDecades().map((decadeStart) {
                              final decadeEnd = decadeStart + 9;
                              return ListTile(
                                title: Text('$decadeStart - $decadeEnd'),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () {
                                  setSheetState(() {
                                    activeDecade = decadeStart;
                                  });
                                },
                              );
                            }).toList()
                          : _buildYearsForDecade(activeDecade!).map((year) {
                              return ListTile(
                                title: Text(year.toString()),
                                onTap: () => Navigator.of(sheetContext).pop(year),
                              );
                            }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selectedYear != null) {
      setState(() {
        _selectedBirthYear = selectedYear;
      });
    }
  }

  String? _validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final normalized = value.trim();
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(normalized)) {
      return 'settings_validation_invalid_mobile'.tr;
    }

    return null;
  }

  Future<void> _saveProfile() async {
    final formState = _profileFormKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    if (_selectedGender == null) {
      _showValidationMessage('settings_validation_pick_gender'.tr);
      return;
    }
    if (_selectedBirthYear == null) {
      _showValidationMessage('settings_validation_pick_birth_year'.tr);
      return;
    }
    if (_selectedCountry == null) {
      _showValidationMessage('settings_validation_pick_country'.tr);
      return;
    }
    if (_selectedCity == null || _selectedCity!.trim().isEmpty) {
      _showValidationMessage('settings_validation_pick_city'.tr);
      return;
    }
    if (_selectedEducationLevel == null) {
      _showValidationMessage('settings_validation_pick_education_level'.tr);
      return;
    }
    if (_selectedWorkType == null) {
      _showValidationMessage('settings_validation_pick_work_type'.tr);
      return;
    }

    try {
      final user = await context.read<UsersProvider>().updateStructuredProfile(
            fullName: _fullNameController.text.trim(),
            gender: _selectedGender!,
            birthYear: _selectedBirthYear!,
            country: _selectedCountry!.name,
            countryCode: _selectedCountry!.phoneCode,
            city: _selectedCity!.trim(),
            mobile: _mobileController.text.trim().isEmpty
                ? null
                : _mobileController.text.trim(),
            educationLevel: _selectedEducationLevel,
            workType: _selectedWorkType,
          );
      if (!mounted) {
        return;
      }
      _applyUserProfile(user);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings_profile_save_success'.tr)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings_profile_save_error'.trParams({
              'error': error.toString(),
            }),
          ),
        ),
      );
    }
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  String _optionLabel(Map<String, String> option) {
    final labelKey = option['labelKey'];
    if (labelKey != null && labelKey.isNotEmpty) {
      return labelKey.tr;
    }

    return option['label'] ?? '';
  }

  String _labelForOption(
    List<Map<String, String>> options,
    String? value,
    String fallbackKey,
  ) {
    final match = options.firstWhere(
      (option) => option['value'] == value,
      orElse: () => {'labelKey': fallbackKey},
    );
    return _optionLabel(match);
  }

  Widget _buildProfileSection(UsersProvider usersProvider) {
    if (!_profileLoaded || !_locationLookupLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_locationLookup == null) {
      return Card(
        color: Colors.white,
        elevation: 0.5,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'settings_profile_location_source_error'.tr,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return Card(
      color: Colors.white,
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _profileFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'settings_profile_section_title'.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'settings_profile_section_subtitle'.tr,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: _inputDecoration('settings_profile_full_name'.tr),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'settings_profile_full_name_required'.tr;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: _inputDecoration('settings_profile_email'.tr).copyWith(
                  helperText: 'settings_profile_email_read_only'.tr,
                ),
                child: Text(
                  usersProvider.selectedUser?.email ?? '',
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobileController,
                decoration: _inputDecoration('settings_profile_mobile'.tr),
                keyboardType: TextInputType.phone,
                validator: _validateMobile,
              ),
              const SizedBox(height: 16),
              Text(
                'settings_profile_gender'.tr,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              RadioGroup<String>(
                groupValue: _selectedGender,
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
                child: Column(
                  children: _genderOptions.map((option) {
                    return RadioListTile<String>(
                      value: option['value']!,
                      title: Text(_optionLabel(option)),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickBirthYear,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: _inputDecoration('settings_profile_birth_year'.tr),
                  child: Text(
                    _selectedBirthYear?.toString() ??
                        'settings_profile_birth_year_placeholder'.tr,
                    style: TextStyle(
                      color: _selectedBirthYear == null
                          ? Colors.black54
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickCountry,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: _inputDecoration('settings_profile_country'.tr),
                  child: Text(
                    _selectedCountry == null
                        ? 'settings_profile_country_placeholder'.tr
                        : _selectedCountry!.displayName,
                    style: TextStyle(
                      color: _selectedCountry == null
                          ? Colors.black54
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: _inputDecoration(
                  'settings_profile_country_code'.tr,
                ).copyWith(
                  helperText: 'settings_profile_country_code_helper'.tr,
                ),
                child: Text(
                  _selectedCountry == null
                      ? 'settings_profile_country_code_auto'.tr
                      : '+${_selectedCountry!.phoneCode}',
                  style: TextStyle(
                    color: _selectedCountry == null
                        ? Colors.black54
                        : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectedCountry == null ? null : _pickCity,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: _inputDecoration('settings_profile_city'.tr).copyWith(
                    helperText: _selectedCountry == null
                        ? 'settings_profile_city_helper_pick_country'.tr
                        : 'settings_profile_city_helper_canonical'.tr,
                  ),
                  child: Text(
                    _selectedCity == null || _selectedCity!.trim().isEmpty
                        ? 'settings_profile_city_placeholder'.tr
                        : _selectedCity!,
                    style: TextStyle(
                      color: _selectedCity == null || _selectedCity!.trim().isEmpty
                          ? Colors.black54
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('education-${_selectedEducationLevel ?? 'empty'}'),
                initialValue: _selectedEducationLevel,
                decoration: _inputDecoration('settings_profile_education'.tr),
                items: _educationLevelOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option['value'],
                    child: Text(_optionLabel(option)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedEducationLevel = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('work-${_selectedWorkType ?? 'empty'}'),
                initialValue: _selectedWorkType,
                decoration: _inputDecoration('settings_profile_work_type'.tr),
                items: _workTypeOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option['value'],
                    child: Text(_optionLabel(option)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedWorkType = value;
                  });
                },
              ),
              if (_selectedEducationLevel != null || _selectedWorkType != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'settings_profile_canonical_note'.trParams({
                      'education': _labelForOption(
                        _educationLevelOptions,
                        _selectedEducationLevel,
                        'settings_profile_unspecified',
                      ),
                      'work': _labelForOption(
                        _workTypeOptions,
                        _selectedWorkType,
                        'settings_profile_unspecified',
                      ),
                    }),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: usersProvider.isProfileLoading ? null : _saveProfile,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: usersProvider.isProfileLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('settings_profile_save_button'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NoPopScope(
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AppBar(
              backgroundColor: AppColors.backgroundColor,
              elevation: 0,
              leading: const CustomBackButton(),
              title: Text(
                'settings'.tr,
                style: const TextStyle(color: AppColors.blackFontColor),
              ),
              centerTitle: true,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              children: [
                Consumer<UsersProvider>(
                  builder: (context, usersProvider, _) {
                    return _buildProfileSection(usersProvider);
                  },
                ),
                const SizedBox(height: 16),
                Consumer<LanguageProvider>(
                  builder: (context, languageProvider, _) {
                    return ListTile(
                      title: Text(
                        'language'.tr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: languageProvider.isLoadingLanguages
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : DropdownButton<String>(
                              value: languageProvider.languages.any(
                                (language) =>
                                    language['code'] ==
                                    languageProvider.langCode,
                              )
                                  ? languageProvider.langCode
                                  : 'ar',
                              underline: const SizedBox(),
                              items: languageProvider.languages
                                  .map<DropdownMenuItem<String>>((language) {
                                return DropdownMenuItem<String>(
                                  value: language['code'],
                                  child: Text(language['name']),
                                );
                              }).toList(),
                              onChanged: (String? value) async {
                                if (value != null) {
                                  await languageProvider.changeLanguage(value);
                                  if (mounted) {
                                    setState(() {});
                                  }
                                }
                              },
                            ),
                    );
                  },
                ),
                const Divider(),
                Consumer<GeneralProvider>(
                  builder: (context, generalProvider, _) {
                    return SwitchListTile(
                      title: Text(
                        'dark_mode'.tr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: generalProvider.themeMode == ThemeMode.dark,
                      onChanged: (_) {
                        generalProvider.toggleTheme();
                      },
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.privacy_tip,
                    color: AppColors.primaryPurple,
                  ),
                  title: Text(
                    'privacy_policy_title'.tr,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Get.to(() => const PrivacyPolicyScreen());
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(
                    'delete_account'.tr,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: Text('delete_account_confirm_title'.tr),
                          content: Text('delete_account_confirm_message'.tr),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: Text('cancel'.tr),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: Text('confirm'.tr),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmed == true && context.mounted) {
                      try {
                        final usersProvider =
                            Provider.of<UsersProvider>(context, listen: false);
                        await usersProvider.deleteAccount();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('delete_account_success'.tr),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('delete_account_error'.tr),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                const Divider(),
                SizeConfig.customSizedBox(null, 4, null),
                Padding(
                  padding: EdgeInsets.only(
                    bottom: SizeConfig.getProportionalHeight(10),
                  ),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(text: '${'feedback'.tr} '),
                        TextSpan(
                          text: '  info@sahifati.com',
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: _emailRecognizer,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
