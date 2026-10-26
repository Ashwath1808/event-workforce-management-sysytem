import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // CURRENT FIREBASE USER
  // ============================================================

  User? get currentUser => _auth.currentUser;

  // ============================================================
  // SIGN UP
  // ============================================================

  Future<UserModel> signup({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      print('========================================');
      print('SIGN UP STARTED');
      print('========================================');

      // --------------------------------------------------------
      // 1. CREATE FIREBASE AUTH ACCOUNT
      // --------------------------------------------------------

      print('1. Creating Firebase Authentication account...');

      final credential =
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception(
          'Unable to create Firebase account.',
        );
      }

      print('2. Firebase Authentication successful!');
      print('Firebase UID: ${user.uid}');

      // --------------------------------------------------------
      // 2. UPDATE DISPLAY NAME
      // --------------------------------------------------------

      await user.updateDisplayName(name.trim());

      print('3. Display name updated.');

      // --------------------------------------------------------
      // 3. CREATE USER MODEL
      // --------------------------------------------------------

      final userModel = UserModel(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        role: role.trim().toLowerCase(),
      );

      print('4. User model created.');
      print('User data: ${userModel.toMap()}');

      // --------------------------------------------------------
      // 4. SAVE USER TO FIRESTORE
      // --------------------------------------------------------

      print('5. Connecting to Cloud Firestore...');
      print('Collection: users');
      print('Document ID: ${user.uid}');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toMap());

      print('6. Firestore save successful!');
      print('User document created successfully.');

      print('========================================');
      print('SIGN UP COMPLETED');
      print('========================================');

      return userModel;
    }

    // ==========================================================
    // FIREBASE AUTHENTICATION ERROR
    // ==========================================================

    on FirebaseAuthException catch (e) {
      print('========================================');
      print('FIREBASE AUTH ERROR');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('========================================');

      throw Exception(
        _authErrorMessage(e.code),
      );
    }

    // ==========================================================
    // FIREBASE / FIRESTORE ERROR
    // ==========================================================

    on FirebaseException catch (e) {
      print('========================================');
      print('FIREBASE / FIRESTORE ERROR');
      print('Plugin: ${e.plugin}');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('========================================');

      throw Exception(
        'Firebase error: ${e.code}\n'
            '${e.message ?? 'Unknown Firebase error.'}',
      );
    }

    // ==========================================================
    // OTHER ERROR
    // ==========================================================

    catch (e) {
      print('========================================');
      print('GENERAL SIGNUP ERROR');
      print('Error: $e');
      print('========================================');

      throw Exception(
        'Something went wrong: $e',
      );
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<UserModel> login({
    required String email,
    required String password,
    required String selectedRole,
  }) async {
    try {
      print('========================================');
      print('LOGIN STARTED');
      print('========================================');

      // --------------------------------------------------------
      // 1. FIREBASE AUTHENTICATION
      // --------------------------------------------------------

      print('1. Logging into Firebase Authentication...');

      final credential =
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception(
          'Unable to login.',
        );
      }

      print('2. Firebase Authentication successful!');
      print('Firebase UID: ${user.uid}');

      // --------------------------------------------------------
      // 2. GET USER PROFILE FROM FIRESTORE
      // --------------------------------------------------------

      print('3. Getting user profile from Firestore...');

      final document = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      // --------------------------------------------------------
      // 3. CHECK DOCUMENT
      // --------------------------------------------------------

      if (!document.exists) {
        print('User document does not exist.');

        await _auth.signOut();

        throw Exception(
          'Your account profile was not found.',
        );
      }

      final data = document.data();

      if (data == null) {
        print('User document contains no data.');

        await _auth.signOut();

        throw Exception(
          'Your account profile is incomplete.',
        );
      }

      print('4. User profile found.');
      print('User data: $data');

      // --------------------------------------------------------
      // 4. CREATE USER MODEL
      // --------------------------------------------------------

      final userModel = UserModel.fromMap(data);

      print('5. User role from Firestore: ${userModel.role}');
      print('Selected login role: $selectedRole');

      // --------------------------------------------------------
      // 5. CHECK WORKER / ORGANIZER ROLE
      // --------------------------------------------------------

      if (userModel.role.toLowerCase() !=
          selectedRole.toLowerCase()) {
        await _auth.signOut();

        throw Exception(
          'This account is registered as ${userModel.role}. '
              'Please use the ${userModel.role} login.',
        );
      }

      print('6. Role verification successful.');

      print('========================================');
      print('LOGIN COMPLETED');
      print('========================================');

      return userModel;
    }

    // ==========================================================
    // FIREBASE AUTH ERROR
    // ==========================================================

    on FirebaseAuthException catch (e) {
      print('========================================');
      print('FIREBASE AUTH LOGIN ERROR');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('========================================');

      throw Exception(
        _authErrorMessage(e.code),
      );
    }

    // ==========================================================
    // FIRESTORE ERROR
    // ==========================================================

    on FirebaseException catch (e) {
      print('========================================');
      print('FIRESTORE LOGIN ERROR');
      print('Plugin: ${e.plugin}');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('========================================');

      throw Exception(
        'Firebase error: ${e.code}\n'
            '${e.message ?? 'Database error occurred.'}',
      );
    }

    // ==========================================================
    // OTHER ERROR
    // ==========================================================

    catch (e) {
      print('========================================');
      print('GENERAL LOGIN ERROR');
      print('Error: $e');
      print('========================================');

      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Something went wrong. Please try again.',
      );
    }
  }

  // ============================================================
  // GET CURRENT USER MODEL
  // ============================================================

  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    try {
      print('Getting current user profile...');

      final document = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!document.exists) {
        print('Current user document does not exist.');
        return null;
      }

      final data = document.data();

      if (data == null) {
        return null;
      }

      return UserModel.fromMap(data);
    } on FirebaseException catch (e) {
      print('Error getting current user:');
      print('Code: ${e.code}');
      print('Message: ${e.message}');

      return null;
    } catch (e) {
      print('Error getting current user: $e');

      return null;
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    try {
      await _auth.signOut();

      print('User logged out successfully.');
    } catch (e) {
      print('Logout error: $e');

      throw Exception(
        'Unable to logout. Please try again.',
      );
    }
  }

  // ============================================================
  // FIREBASE AUTH ERROR MESSAGES
  // ============================================================

  String _authErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'user-not-found':
        return 'No account exists with this email.';

      case 'wrong-password':
        return 'Incorrect password.';

      case 'invalid-credential':
        return 'Incorrect email or password.';

      case 'email-already-in-use':
        return 'An account already exists with this email.';

      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';

      case 'network-request-failed':
        return 'Internet connection problem. Please check your connection.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'operation-not-allowed':
        return 'Email/password authentication is not enabled in Firebase.';

      case 'user-mismatch':
        return 'The account information does not match.';

      default:
        return 'Authentication failed. Please try again.';
    }
  }
}