import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../models/profile_location_lookup.dart';
import '../../models/user.dart';
import '../../providers/users_provider.dart';

class ProfileDetailsForm extends StatefulWidget {
  const ProfileDetailsForm({super.key});

  @override
  State<ProfileDetailsForm> createState() => _ProfileDetailsFormState();
}

class _ProfileDetailsFormState extends State<ProfileDetailsForm> {
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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  ProfileLocationLookup? _locationLookup;
  ProfileCountry? _selectedCountry;
  ProfileCity? _selectedCity;
  String? _selectedGender;
  String? _selectedEducationLevel;
  String? _selectedWorkType;
  int? _selectedBirthYear;
  bool _locationLookupLoaded = false;
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadLocationLookup();
      await _loadProfile();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
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
    final usersProvider = context.read<UsersProvider>();
    try {
      final cachedUser = await usersProvider.getCachedCurrentUserProfile();
      if (!mounted) {
        return;
      }
      if (cachedUser != null) {
        _applyUserProfile(cachedUser);
        unawaited(
          usersProvider.refreshCurrentUserProfileInBackground(
            onUpdated: (user) {
              if (!mounted) {
                return;
              }
              _applyUserProfile(user);
            },
          ),
        );
        return;
      }
      final user = await usersProvider.loadCurrentUserProfile();
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
    final rawCity = (user.city?.trim().isNotEmpty ?? false)
        ? user.city!.trim()
        : ((user.state?.trim().isNotEmpty ?? false)
            ? user.state!.trim()
            : null);
    final resolvedCity = rawCity == null
        ? null
        : (resolvedCountry?.findCity(rawCity) ??
            ProfileCity(value: rawCity, displayName: rawCity));

    setState(() {
      _usernameController.text = user.username;
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

  Future<T?> _showSearchablePicker<T>({
    required String title,
    required String searchLabel,
    required List<T> items,
    required String Function(T item) itemLabel,
    String Function(T item)? itemSubtitle,
    Iterable<String> Function(T item)? searchTerms,
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
              final terms = <String>[
                itemLabel(item),
                if (itemSubtitle != null) itemSubtitle(item),
                ...?searchTerms?.call(item),
              ]
                  .where((term) => term.trim().isNotEmpty)
                  .map((term) => term.toLowerCase())
                  .join(' ');
              return query.isEmpty || terms.contains(query);
            }).toList();

            return SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.78,
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      title,
                      style: AppTypography.of(context).listTileTitle,
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
                              style: AppTypography.of(context)
                                  .bodySecondary
                                  .copyWith(color: Colors.black54),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
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
      searchTerms: (country) =>
          [country.name, country.localizedName, country.iso2],
      emptyMessage: 'settings_picker_country_empty'.tr,
    );
    if (selectedCountry == null) {
      return;
    }
    setState(() {
      _selectedCountry = selectedCountry;
      if (!_selectedCountry!.hasCity(_selectedCity?.value)) {
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
    final selectedCity = await _showSearchablePicker<ProfileCity>(
      title: 'settings_picker_city_title'.tr,
      searchLabel: 'settings_picker_city_search'.tr,
      items: selectedCountry.cities,
      itemLabel: (city) => city.effectiveDisplayName,
      searchTerms: (city) => [city.value],
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
                      style: AppTypography.of(context).listTileTitle,
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
                                onTap: () =>
                                    Navigator.of(sheetContext).pop(year),
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
    if (_selectedCity == null || _selectedCity!.value.trim().isEmpty) {
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
      final user =
          await context.read<UsersProvider>().updateStructuredProfile(
                username: _usernameController.text.trim(),
                gender: _selectedGender!,
                birthYear: _selectedBirthYear!,
                country: _selectedCountry!.name,
                countryCode: _selectedCountry!.phoneCode,
                city: _selectedCity!.value.trim(),
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

  @override
  Widget build(BuildContext context) {
    final usersProvider = context.watch<UsersProvider>();

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
            style: AppTypography.of(context)
                .bodySecondary
                .copyWith(color: Colors.black54),
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
                style: AppTypography.of(context).sectionTitle,
              ),
              const SizedBox(height: 8),
              Text(
                'settings_profile_section_subtitle'.tr,
                style: AppTypography.of(context)
                    .bodySecondary
                    .copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: _inputDecoration('اسم المستخدم'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'اسم المستخدم مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration:
                    _inputDecoration('settings_profile_email'.tr).copyWith(
                  helperText: 'settings_profile_email_read_only'.tr,
                ),
                child: Text(
                  usersProvider.selectedUser?.email ?? '',
                  style: AppTypography.of(context)
                      .bodyDefault
                      .copyWith(color: Colors.black87),
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
                style: AppTypography.of(context).inputLabel,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: _genderOptions
                    .map(
                      (option) => ButtonSegment<String>(
                        value: option['value']!,
                        label: Text(_optionLabel(option)),
                      ),
                    )
                    .toList(),
                selected: _selectedGender != null
                    ? {_selectedGender!}
                    : const <String>{},
                emptySelectionAllowed: true,
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedGender = set.isEmpty ? null : set.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor:
                      Theme.of(context).colorScheme.primary,
                  selectedForegroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickBirthYear,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration:
                      _inputDecoration('settings_profile_birth_year'.tr),
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
                  decoration:
                      _inputDecoration('settings_profile_city'.tr).copyWith(
                    helperText: _selectedCountry == null
                        ? 'settings_profile_city_helper_pick_country'.tr
                        : 'settings_profile_city_helper_canonical'.tr,
                  ),
                  child: Text(
                    _selectedCity == null ||
                            _selectedCity!.effectiveDisplayName.trim().isEmpty
                        ? 'settings_profile_city_placeholder'.tr
                        : _selectedCity!.effectiveDisplayName,
                    style: TextStyle(
                      color: _selectedCity == null ||
                              _selectedCity!
                                  .effectiveDisplayName.trim().isEmpty
                          ? Colors.black54
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(
                    'education-${_selectedEducationLevel ?? 'empty'}'),
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
              if (_selectedEducationLevel != null ||
                  _selectedWorkType != null)
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
                onPressed:
                    usersProvider.isProfileLoading ? null : _saveProfile,
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
}
