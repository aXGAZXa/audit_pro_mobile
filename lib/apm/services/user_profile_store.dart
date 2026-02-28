import 'package:shared_preferences/shared_preferences.dart';

import 'package:audit_pro_mobile/apm/models/user_profile.dart';

class UserProfileStore {
  static const _emailKey = 'user_profile_email';
  static const _displayNameKey = 'user_profile_display_name';
  static const _companyNameKey = 'user_profile_company_name';

  Future<void> setProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, profile.email);
    await prefs.setString(_displayNameKey, profile.displayName);
    if (profile.companyName != null) {
      await prefs.setString(_companyNameKey, profile.companyName!);
    } else {
      await prefs.remove(_companyNameKey);
    }
  }

  Future<UserProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_emailKey);
    final displayName = prefs.getString(_displayNameKey);
    final companyName = prefs.getString(_companyNameKey);

    if (email == null ||
        email.isEmpty ||
        displayName == null ||
        displayName.isEmpty) {
      return null;
    }

    return UserProfile(
      email: email,
      displayName: displayName,
      companyName: companyName,
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_companyNameKey);
  }
}
