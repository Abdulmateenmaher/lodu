import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthMode { signIn, signUp }

class AuthUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool isEmailVerified;
  final String? phoneNumber;

  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.isEmailVerified = false,
    this.phoneNumber,
  });

  factory AuthUser.fromFirebase(User user) {
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      isEmailVerified: user.emailVerified,
      phoneNumber: user.phoneNumber,
    );
  }

  String get displayLabel => displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : email.split('@').first;
}

class AuthException implements Exception {
  final String code;
  final String message;
  AuthException(this.code, this.message);

  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  FirebaseAuth? _auth;
  FirebaseAuth get _firebaseAuth {
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _firebaseAvailable = false;
  bool get isFirebaseAvailable => _firebaseAvailable;

  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  StreamSubscription<User?>? _userSub;

  Future<void> initialize() async {
    try {
      final user = _firebaseAuth.currentUser;
      _firebaseAvailable = true;
      _currentUser = user != null ? AuthUser.fromFirebase(user) : null;
      notifyListeners();

      _userSub = _firebaseAuth.authStateChanges().listen((u) {
        _currentUser = u != null ? AuthUser.fromFirebase(u) : null;
        notifyListeners();
      });
    } catch (e) {
      _firebaseAvailable = false;
      _currentUser = null;
      debugPrint('AuthService init failed: $e');
    }
  }

  Stream<AuthUser?> get userStream {
    if (!_firebaseAvailable) return Stream.value(null);
    return _firebaseAuth.authStateChanges().map((u) {
      _currentUser = u != null ? AuthUser.fromFirebase(u) : null;
      notifyListeners();
      return _currentUser;
    });
  }

  Future<AuthUser> signInWithGoogle() async {
    _ensureFirebase();
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      final credential = await _firebaseAuth.signInWithPopup(googleProvider);
      final user = credential.user;
      if (user == null) throw AuthException('cancelled', 'Google sign-in was cancelled.');
      _currentUser = AuthUser.fromFirebase(user);
      notifyListeners();
      return _currentUser!;
    }

    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.signIn();
    } catch (e) {
      throw AuthException('google-play-unavailable', 'Google Play services unavailable. Make sure Google Play Services are up to date. ($e)');
    }
    if (googleUser == null) {
      throw AuthException('cancelled', 'Google sign-in was cancelled.');
    }

    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null) {
      throw AuthException('no-id-token', 'Could not get ID token from Google. Check SHA-1 in Firebase Console > Project Settings > Your apps.');
    }

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    try {
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) throw AuthException('unknown', 'Failed to sign in with Google.');
      _currentUser = AuthUser.fromFirebase(user);
      notifyListeners();
      return _currentUser!;
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          msg = 'An account already exists with this email. Sign in with the original method.';
          break;
        case 'invalid-credential':
          msg = 'Invalid credential. Check google-services.json and SHA-1 fingerprint.';
          break;
        case 'user-disabled':
          msg = 'This account has been disabled.';
          break;
        default:
          msg = 'Firebase Auth error (${e.code}): ${e.message}';
      }
      throw AuthException(e.code, msg);
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _ensureFirebase();
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) throw AuthException('unknown', 'Account creation failed.');

    await user.updateDisplayName(displayName.trim());
    await user.reload();
    final reloaded = _firebaseAuth.currentUser;
    _currentUser = reloaded != null ? AuthUser.fromFirebase(reloaded) : _currentUser;
    notifyListeners();
    return _currentUser!;
  }

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _ensureFirebase();
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) throw AuthException('unknown', 'Sign in failed.');

    _currentUser = AuthUser.fromFirebase(user);
    notifyListeners();
    return _currentUser!;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _ensureFirebase();
    await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    if (!_firebaseAvailable) return;
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
    _currentUser = null;
    notifyListeners();
  }

  void _ensureFirebase() {
    if (!_firebaseAvailable) {
      throw AuthException('unavailable', 'Firebase is not configured. Please add google-services.json or GoogleService-Info.plist.');
    }
  }

  Future<void> disposeAsync() async {
    await _userSub?.cancel();
    await _googleSignIn.signOut();
  }
}
