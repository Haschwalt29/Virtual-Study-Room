import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isInitialized = false;

  ThemeProvider() {
    _loadThemePreference();
  }

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  bool get isInitialized => _isInitialized;

  // Define light theme
  static ThemeData lightTheme = ThemeData(
    primarySwatch: Colors.orange,
    primaryColor: Colors.orangeAccent,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.orangeAccent,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orangeAccent,
        foregroundColor: Colors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.orangeAccent,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return Colors.orangeAccent;
        }
        return null;
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return Colors.orangeAccent.withOpacity(0.5);
        }
        return null;
      }),
    ),
    colorScheme: ColorScheme.light(
      primary: Colors.orangeAccent,
      secondary: Colors.deepOrange,
    ),
  );

  // Define dark theme
  static ThemeData darkTheme = ThemeData(
    primarySwatch: Colors.orange,
    primaryColor: Colors.deepOrange,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.grey[900],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[850],
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.orangeAccent,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return Colors.deepOrange;
        }
        return null;
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return Colors.deepOrange.withOpacity(0.5);
        }
        return null;
      }),
    ),
    cardTheme: CardTheme(
      color: Colors.grey[800],
    ),
    dialogTheme: DialogTheme(
      backgroundColor: Colors.grey[800],
    ),
    colorScheme: ColorScheme.dark(
      primary: Colors.deepOrange,
      secondary: Colors.orangeAccent,
      surface: Colors.grey[800]!,
      background: Colors.grey[900]!,
    ),
  );

  // Load theme preference from Firebase
  Future<void> _loadThemePreference() async {
    try {
      User? user = _auth.currentUser;
      
      if (user != null) {
        DocumentSnapshot settingsDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('preferences')
            .get();
        
        if (settingsDoc.exists) {
          Map<String, dynamic> settings = settingsDoc.data() as Map<String, dynamic>;
          _isDarkMode = settings['darkMode'] ?? false;
        }
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error loading theme preference: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Set dark mode
  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    
    try {
      User? user = _auth.currentUser;
      
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('preferences')
            .update({
              'darkMode': value,
            });
      }
    } catch (e) {
      print('Error updating theme preference: $e');
    }
  }

  // Toggle theme
  void toggleTheme() {
    setDarkMode(!_isDarkMode);
  }
}