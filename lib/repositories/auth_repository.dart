import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/logger.dart';

abstract class IAuthRepository {
  User? get currentUser;
  Stream<User?> get authStateChanges;
  Future<User?> signInWithGoogle();
  Future<UserCredential> signInAnonymously();
  Future<void> signOut();
  Future<Map<String, dynamic>?> getUserData(String uid);
  Future<void> updateUserData(String uid, Map<String, dynamic> data);
  Future<void> deleteUserAccount(String uid);
}

class AuthRepository implements IAuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      Logger.e('Google Sign-In failed', e, null, 'AuthRepository');
      rethrow;
    }
  }

  @override
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  @override
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  @override
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }
  
  @override
  Future<void> deleteUserAccount(String uid) async {
    // Note: This is a direct Firestore deletion. 
    // In a real app, you might want to use Cloud Functions for cascading deletes.
    await _firestore.collection('users').doc(uid).delete();
  }
}
