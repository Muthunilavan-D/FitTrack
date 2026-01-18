import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      // Validate email and password
      if (email.isEmpty || password.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-input',
          message: 'Email and password cannot be empty',
        );
      }

      // Attempt sign in
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user exists in Firestore
      final userDoc =
          await _firestore.collection('users').doc(credential.user?.uid).get();

      // If user doesn't exist in Firestore, create their document
      if (!userDoc.exists && credential.user != null) {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        // Update last login time
        await _firestore.collection('users').doc(credential.user?.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-email':
        case 'user-disabled':
          rethrow;
        default:
          throw FirebaseAuthException(
            code: 'auth-error',
            message: 'Authentication failed. Please try again.',
          );
      }
    } catch (e) {
      throw FirebaseAuthException(
        code: 'unknown-error',
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  // Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      // Validate email and password
      if (email.isEmpty || password.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-input',
          message: 'Email and password cannot be empty',
        );
      }

      if (password.length < 6) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: 'Password must be at least 6 characters',
        );
      }

      // Create user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      if (credential.user != null) {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
        case 'invalid-email':
        case 'operation-not-allowed':
        case 'weak-password':
          rethrow;
        default:
          throw FirebaseAuthException(
            code: 'registration-error',
            message: 'Registration failed. Please try again.',
          );
      }
    } catch (e) {
      throw FirebaseAuthException(
        code: 'unknown-error',
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw FirebaseAuthException(
        code: 'sign-out-error',
        message: 'Failed to sign out. Please try again.',
      );
    }
  }

  // Check if user is logged in
  bool get isUserLoggedIn => _auth.currentUser != null;

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      if (_auth.currentUser == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();

      return doc.data();
    } catch (e) {
      return null;
    }
  }
}
