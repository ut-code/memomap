import 'dart:developer' as developer;

const _errorMessages = <String, String>{
  'invalid_credentials': 'Invalid email or password',
  'user_already_exists': 'This email is already registered',
  'email_exists': 'This email is already registered',
  'email_not_confirmed': 'Please verify your email first',
  'weak_password': 'Password is too weak',
  'over_request_rate_limit': 'Too many attempts. Please try again later',
  'over_email_send_rate_limit': 'Too many attempts. Please try again later',
  'user_not_found': 'No account found with this email',
  'user_banned': 'This account has been suspended',
  'session_not_found': 'Session expired. Please sign in again',
  // Better Auth error messages
  'Invalid password': 'Invalid email or password',
  'Password is too short': 'Password must be at least 8 characters',
  'User already exists': 'This email is already registered',
  'Invalid email or password': 'Invalid email or password',
  'CREDENTIAL_ALREADY_IN_USE': 'This email is already registered with another sign-in method',
};

String getAuthErrorMessage(Object error) {
  developer.log('Auth error: $error', name: 'AuthExceptionHandler');

  final message = error.toString();
  for (final entry in _errorMessages.entries) {
    if (message.contains(entry.key)) {
      return entry.value;
    }
  }

  // Show actual error for debugging
  return message;
}
