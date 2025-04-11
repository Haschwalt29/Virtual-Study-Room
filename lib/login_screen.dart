import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import 'home_screen.dart';
import 'register_screen.dart';
import 'firebase_options.dart';
import 'theme_provider.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  void _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use a try-catch block for each step to better identify where failures occur

      // Step 1: Initialize GoogleSignIn with no configuration
      final GoogleSignIn googleSignIn = GoogleSignIn();

      print('Step 1: GoogleSignIn initialized');

      // Step 2: Attempt to sign in
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await googleSignIn.signIn();
        print('Step 2: Sign in attempt completed');
      } catch (e) {
        print('Error during signIn(): $e');
        throw Exception('Failed to start Google Sign In: $e');
      }

      // Step 3: Check if user canceled
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sign in was canceled';
        });
        print('Step 3: User canceled sign in');
        return;
      }

      print('Step 3: User signed in: ${googleUser.email}');

      // Step 4: Get authentication tokens
      GoogleSignInAuthentication? googleAuth;
      try {
        googleAuth = await googleUser.authentication;
        print('Step 4: Got authentication tokens');
      } catch (e) {
        print('Error getting authentication: $e');
        throw Exception('Failed to authenticate with Google: $e');
      }

      // Step 5: Verify we have an ID token
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null) {
        print('Step 5: No ID token received');
        throw Exception('Google Sign In failed: No ID token received');
      }

      print('Step 5: ID token verified');

      // Step 6: Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      print('Step 6: Firebase credential created');
      // Step 7: Sign in to Firebase
      UserCredential userCredential;
      try {
        userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        print('Step 7: Signed in to Firebase');
      } catch (e) {
        print('Error signing in to Firebase: $e');
        throw Exception('Failed to sign in to Firebase: $e');
      }

      // Step 8: Get user and update Firestore
      final user = userCredential.user;
      if (user != null) {
        try {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();

          if (!userDoc.exists) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
                  'email': user.email,
                  'displayName': user.displayName,
                  'photoURL': user.photoURL,
                  'createdAt': FieldValue.serverTimestamp(),
                  'lastLogin': FieldValue.serverTimestamp(),
                });
            print('Step 8: Created new user document in Firestore');
          } else {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'lastLogin': FieldValue.serverTimestamp()});
            print('Step 8: Updated existing user document in Firestore');
          }
        } catch (e) {
          print('Error updating Firestore: $e');
          // Don't throw here, we still want to navigate to home screen
        }
      }
      // Step 9: Navigate to home screen
      print('Step 9: Navigating to home screen');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } catch (e) {
      // Final error handler
      print('Google Sign-In failed with error: $e');
      setState(() {
        _errorMessage = 'Google Sign-In failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Container(
            width: 400,
            padding: EdgeInsets.all(25.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Student Login",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Enter your details to sign in",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400] : Colors.black54,
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Username",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                SizedBox(height: 15),
                if (_errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 15),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child:
                      _isLoading
                          ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.secondary,
                            ),
                          )
                          : Text("Sign In", style: TextStyle(fontSize: 16)),
                ),
                SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: _loadGoogleIcon(),
                    label: Text("Sign in with Google"),
                    onPressed: _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDarkMode ? Colors.grey[800] : Colors.white,
                      foregroundColor: isDarkMode ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 15),
                TextButton(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RegisterScreen(),
                        ),
                      ),
                  child: Text(
                    "Don't have an account? Request Now",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadGoogleIcon() {
    try {
      return Image.asset('Assets/google.png', height: 24);
    } catch (e) {
      return Icon(Icons.error, color: Colors.red);
    }
  }
}
