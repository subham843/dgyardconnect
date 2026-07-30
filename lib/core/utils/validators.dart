import '../constants/app_constants.dart';

/// Form and input validators. Production-ready.
abstract final class Validators {
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final regex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != password) return 'Passwords do not match.';
    return null;
  }

  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required.';
    if (value.trim().length < AppConstants.minNameLength) {
      return 'Name must be at least ${AppConstants.minNameLength} characters.';
    }
    if (value.trim().length > AppConstants.maxNameLength) {
      return 'Name must be at most ${AppConstants.maxNameLength} characters.';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required.';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != AppConstants.phoneLength) {
      return 'Enter a valid ${AppConstants.phoneLength}-digit phone number.';
    }
    return null;
  }

  static String? minAmount(String? value, num min) {
    if (value == null || value.trim().isEmpty) return 'Amount is required.';
    final n = num.tryParse(value.trim());
    if (n == null || n < min) return 'Amount must be at least $min.';
    return null;
  }
}
