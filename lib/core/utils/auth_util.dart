String? validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'Enter your email';
  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
    return 'Enter a valid email';
  }
  return null;
}

/// Maps Supabase AuthException messages to user-friendly strings.
String authErrorMessage(String message) {
  final m = message.toLowerCase();
  if (m.contains('invalid login credentials') || m.contains('invalid credentials')) {
    return 'Incorrect email or password';
  }
  if (m.contains('user already registered') || m.contains('already been registered')) {
    return 'An account already exists for this email';
  }
  if (m.contains('password should be at least') || m.contains('weak password')) {
    return 'Password must be at least 6 characters';
  }
  if (m.contains('unable to validate email') || m.contains('invalid format')) {
    return 'Invalid email address';
  }
  if (m.contains('email not confirmed')) {
    return 'Please confirm your email before signing in';
  }
  if (m.contains('too many requests') || m.contains('rate limit')) {
    return 'Too many attempts. Try again later';
  }
  if (m.contains('network') || m.contains('connection')) {
    return 'Network error. Check your connection';
  }
  return 'Something went wrong. Please try again';
}
