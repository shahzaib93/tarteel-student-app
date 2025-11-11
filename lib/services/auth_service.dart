import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  User? get currentUser => _currentUser;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) async {
      _currentUser = user;

      if (user != null) {
        await _loadUserData(user.uid);
      } else {
        _userData = null;
      }

      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        _userData = doc.data();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Load user data from Firestore
      final doc = await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!doc.exists) {
        await signOut();
        return 'User not found in database';
      }

      final userData = doc.data()!;

      // Check if user is a student
      if (userData['role'] != 'student') {
        await signOut();
        return 'Student access required';
      }

      _userData = userData;
      notifyListeners();

      return null; // Success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No account found with this email';
      } else if (e.code == 'wrong-password') {
        return 'Invalid password';
      } else if (e.code == 'invalid-email') {
        return 'Invalid email format';
      } else if (e.code == 'invalid-credential') {
        return 'Invalid email or password';
      }
      return e.message ?? 'Login failed';
    } catch (e) {
      return 'An error occurred: $e';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    _userData = null;
    notifyListeners();
  }

  String get userName => _userData?['username'] ?? 'Student';
  String get userEmail => _currentUser?.email ?? '';
}
