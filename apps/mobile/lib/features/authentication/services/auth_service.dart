import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../services/api_client.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleInitialized = false;

  // ---------------------------------------------------------------------------
  // Authentication state
  // ---------------------------------------------------------------------------

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  bool get isAuthenticated => _firebaseAuth.currentUser != null;

  // ---------------------------------------------------------------------------
  // Google sign-in initialization
  // ---------------------------------------------------------------------------

  Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) {
      return;
    }

    await _googleSignIn.initialize();

    _googleInitialized = true;
  }

  // ---------------------------------------------------------------------------
  // Google sign-in
  // ---------------------------------------------------------------------------

  Future<UserCredential> signInWithGoogle() async {
    await _initializeGoogleSignIn();

    final googleUser = await _googleSignIn.authenticate();
    final googleAuthentication = googleUser.authentication;
    final idToken = googleAuthentication.idToken;

    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: 'Google ID token was not returned.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(
      credential,
    );

    // Register the user or retrieve the existing RideGuardian profile.
    // ApiClient attaches the Firebase ID token to this request.
    await ApiClient.instance.post(
      '/api/v1/auth/register',
      body: {},
    );

    return userCredential;
  }

  // ---------------------------------------------------------------------------
  // Phone authentication: send OTP
  // ---------------------------------------------------------------------------

  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function() onTimeout,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),

      verificationCompleted: onAutoVerified,

      verificationFailed: (FirebaseAuthException error) {
        debugPrint('========== FIREBASE PHONE AUTH ERROR ==========');
        debugPrint('Code: ${error.code}');
        debugPrint('Message: ${error.message}');
        debugPrint('Plugin: ${error.plugin}');
        debugPrint('Details: ${error.toString()}');
        debugPrint('================================================');

        onError(_phoneErrorMessage(error));
      },

      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        onTimeout();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Phone authentication: verify OTP
  // ---------------------------------------------------------------------------

  Future<UserCredential> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(
      credential,
    );

    return userCredential;
  }

  // ---------------------------------------------------------------------------
  // Firebase ID token
  // ---------------------------------------------------------------------------

  Future<String> getIdToken() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'No Firebase user is currently signed in.',
      );
    }

    final idToken = await user.getIdToken(true);

    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'token-unavailable',
        message: 'Firebase ID token was not available.',
      );
    }

    return idToken;
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    // Sign out from Firebase first.
    await _firebaseAuth.signOut();

    // Also clear the Google sign-in session when initialized.
    if (_googleInitialized) {
      try {
        await _googleSignIn.signOut();
      } catch (error) {
        debugPrint('Google sign-out failed: $error');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Phone authentication error messages
  // ---------------------------------------------------------------------------

  String _phoneErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'Please enter a valid phone number with country code.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'quota-exceeded':
        return 'SMS verification is temporarily unavailable.';

      case 'network-request-failed':
        return 'Check your internet connection and try again.';

      default:
        return error.message ?? 'Phone verification failed.';
    }
  }
}