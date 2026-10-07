import 'package:shared_preferences/shared_preferences.dart';

const String seniorCodeKey = 'senior_family_code';
const String seniorNameKey = 'senior_name';
const String familyCodeKey = 'family_member_code';
const String familyMemberIdKey = 'family_member_id';
const String selectedRoleKey = 'selected_role';
const String seniorRole = 'senior';
const String familyRole = 'family';

Future<String?> getSavedFamilyCode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(familyCodeKey);
}

Future<String?> getSavedRole() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(selectedRoleKey);
}

Future<void> saveRole(String role) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(selectedRoleKey, role);
}

Future<void> clearSavedRole() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(selectedRoleKey);
}
