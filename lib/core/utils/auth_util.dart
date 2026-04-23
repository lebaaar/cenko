String? validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'Enter your email';
  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
    return 'Enter a valid email';
  }
  return null;
}

String authErrorMessage(String code) {
  switch (code) {
    case 'user-not-found':
      return 'No account found for this email';
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password';
    case 'email-already-in-use':
      return 'An account already exists for this email';
    case 'weak-password':
      return 'Password is too weak';
    case 'invalid-email':
      return 'Invalid email address';
    case 'too-many-requests':
      return 'Too many attempts. Try again later';
    case 'network-request-failed':
      return 'Network error. Check your connection';
    default:
      return 'Something went wrong. Please try again';
  }
}
