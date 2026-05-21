import 'package:flutter/material.dart';
import 'package:sahifaty/services/school_services.dart';

import '../models/school.dart';

class SchoolProvider with ChangeNotifier {
  List<School> schools = const [];
  bool isLoading = false;
  final SchoolServices _schoolServices = SchoolServices();

  /// Backward-compat getter: first visible school (or null if none loaded yet)
  School? get quickQuestionsSchool => schools.isNotEmpty ? schools.first : null;

  /// Delegates to [loadVisibleSchools] for backward compatibility.
  Future<void> getQuickQuestionsSchool() => loadVisibleSchools();

  /// Loads all schools visible to users via GET /schools/public.
  Future<void> loadVisibleSchools() async {
    setLoading();
    schools = await _schoolServices.getPublicSchools();
    resetLoading();
  }

  void setLoading() {
    isLoading = true;
    notifyListeners();
  }

  void resetLoading() {
    isLoading = false;
    notifyListeners();
  }
}
