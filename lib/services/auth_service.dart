import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Firebase authentication service
/// Handles user authentication and session management
class AuthService {
  static const String _databaseUrl =
      'https://smart-restaurant-pos-default-rtdb.asia-southeast1.firebasedatabase.app';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _databaseInstance = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseUrl,
  );

  DatabaseReference get _database => _databaseInstance.ref();

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  /// Get current user ID
  String? get userId => _auth.currentUser?.uid;

  /// Get current user email
  String? get userEmail => _auth.currentUser?.email;

  /// Get user role from Realtime Database
  Future<String?> getUserRole(String userId) async {
    try {
      final snapshot = await _database.child('users/$userId/role').get();
      if (snapshot.exists) {
        return snapshot.value as String;
      }
      return null;
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }

  /// Sign in with email and password
  Future<Map<String, dynamic>> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      print('🔐 Starting login for: $email');
      
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('❌ Login timeout');
          throw FirebaseAuthException(
            code: 'timeout',
            message: 'Connection timeout. Please check your internet connection.',
          );
        },
      );

      print('✅ Firebase Auth successful for: ${result.user?.email}');

      // Fetch user role with timeout
      final role = await getUserRole(result.user!.uid).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⚠️ Role fetch timeout, using default role');
          return 'waiter';
        },
      );

      print('✅ User role: $role');

      return {
        'success': true,
        'user': result.user,
        'role': role ?? 'waiter', // Default role
        'message': 'Login successful',
      };
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'error': _getAuthErrorMessage(e.code),
      };
    } catch (e) {
      print('❌ Unexpected error: $e');
      return {
        'success': false,
        'error': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }

  /// Register new user with email and password
  Future<Map<String, dynamic>> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
    String role = 'waiter',
  }) async {
    try {
      // Create user account
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update display name
      await result.user!.updateDisplayName(displayName);

      // Save user data to Realtime Database
      await _database.child('users/${result.user!.uid}').set({
        'email': email.trim(),
        'displayName': displayName,
        'role': role,
        'createdAt': ServerValue.timestamp,
        'isActive': true,
      });

      // Also create staff record
      await _database.child('staff/${result.user!.uid}').set({
        'id': result.user!.uid,
        'name': displayName,
        'email': email.trim(),
        'role': role,
        'photoUrl': '',
        'hireDate': ServerValue.timestamp,
        'performanceScore': 0,
        'totalOrdersServed': 0,
      });

      return {
        'success': true,
        'user': result.user,
        'role': role,
        'message': 'Account created successfully',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'error': _getAuthErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to create account: ${e.toString()}',
      };
    }
  }

  /// Sign out
  Future<Map<String, dynamic>> signOut() async {
    try {
      await _auth.signOut();
      return {
        'success': true,
        'message': 'Logged out successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to sign out: ${e.toString()}',
      };
    }
  }

  /// Reset password
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return {
        'success': true,
        'message': 'Password reset email sent to $email',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'error': _getAuthErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to send reset email: ${e.toString()}',
      };
    }
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'No user logged in',
        };
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName);
        await _database.child('users/${user.uid}/displayName').set(displayName);
      }

      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
        await _database.child('users/${user.uid}/photoUrl').set(photoUrl);
      }

      return {
        'success': true,
        'message': 'Profile updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to update profile: ${e.toString()}',
      };
    }
  }

  /// Get user-friendly error messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Please enable it in Firebase Console.';
      case 'timeout':
        return 'Connection timeout. Check your internet or Firebase setup.';
      case 'invalid-credential':
        return 'Invalid email or password';
      default:
        return 'Authentication failed: $code';
    }
  }
}
