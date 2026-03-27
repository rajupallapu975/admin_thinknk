import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Web Client ID from your google-services.json (client_type 3)
  static final String webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? "1071627103248-kicf8hvemv2tk1up7j9ib9da74k5v7bl.apps.googleusercontent.com";

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: webClientId,
  );

  // Sign in with Google
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
      debugPrint('Error signing in with Google: $e');
      return null;
    }
  }

  // Check if user has completed onboarding
  Future<bool> isUserOnboarded() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    final doc = await _db.collection('shops').doc(user.uid).get();
    return doc.exists;
  }

  // Save shop details
  Future<void> saveShopDetails(Map<String, dynamic> details) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _db.collection('shops').doc(user.uid).set({
      ...details,
      'uid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
