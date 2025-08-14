import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_data.dart';
import '../models/run_data.dart';

class FirebaseService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  UserData? _userData;
  bool _isLoading = false;

  // Getters
  User? get user => _user;
  UserData? get userData => _userData;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  FirebaseService() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _userData = UserData.fromFirebaseUser(user);
      } else {
        _userData = null;
      }
      notifyListeners();
    });
  }

  // Set loading state and notify listeners
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Sign in with email and password
  Future<String?> signInWithEmailAndPassword(String email, String password) async {
    try {
      _setLoading(true);

      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = result.user;
      if (_user != null) {
        _userData = UserData.fromFirebaseUser(_user!);
        // Store/update user data in Firestore
        await _createOrUpdateUserDocument(_userData!);
      }

      _setLoading(false);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      switch (e.code) {
        case 'user-not-found':
          return 'No user found for that email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'user-disabled':
          return 'User account has been disabled.';
        default:
          return 'An error occurred: ${e.message}';
      }
    } catch (e) {
      _setLoading(false);
      return 'An unexpected error occurred.';
    }
  }

  // Create account with email and password
  Future<String?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      _setLoading(true);

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = result.user;
      if (_user != null) {
        _userData = UserData.fromFirebaseUser(_user!);
        // Create user document in Firestore
        await _createOrUpdateUserDocument(_userData!);
      }

      _setLoading(false);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      switch (e.code) {
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'email-already-in-use':
          return 'The account already exists for that email.';
        case 'invalid-email':
          return 'Invalid email address.';
        default:
          return 'An error occurred: ${e.message}';
      }
    } catch (e) {
      _setLoading(false);
      return 'An unexpected error occurred.';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _userData = null;
    notifyListeners();
  }

  // Create or update user document in Firestore
  Future<void> _createOrUpdateUserDocument(UserData userData) async {
    await _firestore.collection('users').doc(userData.uid).set(
      userData.toMap(),
      SetOptions(merge: true),
    );
  }

  // Save run data to Firestore
  Future<void> saveRunData(RunData runData) async {
    if (_user == null) throw Exception('User not authenticated');

    await _firestore.collection('runs').add(runData.toMap());
  }

  // Get user's run history
  Future<List<RunData>> getUserRunHistory() async {
    if (_user == null) throw Exception('User not authenticated');

    QuerySnapshot snapshot = await _firestore
        .collection('runs')
        .where('userId', isEqualTo: _user!.uid)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => RunData.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  // Get leaderboard data (sorted by distance)
  Future<List<Map<String, dynamic>>> getLeaderboardByDistance() async {
    QuerySnapshot snapshot = await _firestore
        .collection('runs')
        .orderBy('distance', descending: true)
        .limit(50)
        .get();

    List<Map<String, dynamic>> leaderboard = [];

    for (var doc in snapshot.docs) {
      RunData runData = RunData.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      // Get user data for this run
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(runData.userId)
          .get();

      UserData userData = UserData.fromMap(userDoc.data() as Map<String, dynamic>);

      leaderboard.add({
        'runData': runData,
        'userData': userData,
      });
    }

    return leaderboard;
  }

  // Get leaderboard data (sorted by speed)
  Future<List<Map<String, dynamic>>> getLeaderboardBySpeed() async {
    QuerySnapshot snapshot = await _firestore
        .collection('runs')
        .orderBy('averageSpeed', descending: true)
        .limit(50)
        .get();

    List<Map<String, dynamic>> leaderboard = [];

    for (var doc in snapshot.docs) {
      RunData runData = RunData.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      // Get user data for this run
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(runData.userId)
          .get();

      UserData userData = UserData.fromMap(userDoc.data() as Map<String, dynamic>);

      leaderboard.add({
        'runData': runData,
        'userData': userData,
      });
    }

    return leaderboard;
  }
}