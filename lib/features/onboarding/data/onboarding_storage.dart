import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStorage {
  OnboardingStorage._();

  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';

  static final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  static Future<bool> hasCompletedOnboarding() async {
    return await _preferences.getBool(_hasCompletedOnboardingKey) ?? false;
  }

  static Future<void> markOnboardingCompleted() async {
    await _preferences.setBool(_hasCompletedOnboardingKey, true);
  }

  static Future<void> resetOnboarding() async {
    await _preferences.remove(_hasCompletedOnboardingKey);
  }
}
