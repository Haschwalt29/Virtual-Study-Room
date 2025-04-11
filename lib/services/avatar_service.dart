import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AvatarService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // SVG download and fetch with improved error handling and validation
  static Future<String> fetchSvgString(String svgUrl) async {
    try {
      print('Fetching SVG from URL: $svgUrl');

      // Fetch SVG content with proper headers
      final response = await http.get(
        Uri.parse(svgUrl),
        headers: {
          'Accept': 'image/svg+xml',
          'User-Agent': 'Mozilla/5.0 Flutter App',
        },
      );

      if (response.statusCode != 200) {
        print('Failed to download SVG: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to download SVG: ${response.statusCode}');
      }

      final svgContent = response.body;

      // Basic SVG validation
      if (!svgContent.contains('<svg') || !svgContent.contains('</svg>')) {
        print(
          'Invalid SVG content received: ${svgContent.substring(0, min(100, svgContent.length))}...',
        );

        // Try a fallback with minimal parameters
        print('Trying fallback URL with minimal parameters');
        final fallbackUrl =
            'https://api.dicebear.com/7.x/avataaars/svg?seed=${DateTime.now().millisecondsSinceEpoch}';

        final fallbackResponse = await http.get(
          Uri.parse(fallbackUrl),
          headers: {
            'Accept': 'image/svg+xml',
            'User-Agent': 'Mozilla/5.0 Flutter App',
          },
        );

        if (fallbackResponse.statusCode != 200) {
          throw Exception(
            'Fallback SVG also failed: ${fallbackResponse.statusCode}',
          );
        }

        return fallbackResponse.body;
      }

      return svgContent;
    } catch (e) {
      print('Error downloading avatar: $e');
      rethrow;
    }
  }

  // Helper function to limit string length for debugging
  static int min(int a, int b) => a < b ? a : b;

  // Generate DiceBear Avataaars API URL with the given options - updated with correct parameter names
  static String generateAvatarUrl({
    required String background,
    required String skinTone,
    required String eyeType,
    required String eyebrowType,
    required String mouthType,
    required String hairStyle,
    required String hairColor,
    required String facialHair,
    required String facialHairColor,
    required String accessory,
    required String clothingType,
    required String clothingColor,
  }) {
    // Create random seed to prevent caching issues
    final seed = DateTime.now().millisecondsSinceEpoch.toString();

    // Start with base URL
    String url = 'https://api.dicebear.com/7.x/avataaars/svg?seed=$seed';

    // Add parameters one by one, ensuring proper formatting
    url +=
        '&backgroundColor=${background == 'transparent' ? 'transparent' : 'lightgray'}';
    url += '&skinColor=$skinTone';
    url += '&eyes=$eyeType';
    url += '&eyebrows=$eyebrowType';
    url += '&mouth=$mouthType';
    url += '&top=$hairStyle';
    url += '&hairColor=$hairColor';

    // Only add facial hair if not blank
    if (facialHair != 'blank' && facialHair.isNotEmpty) {
      url += '&facialHair=$facialHair';
      url += '&facialHairColor=$facialHairColor';
    }

    // Only add accessories if not blank
    if (accessory != 'blank' && accessory.isNotEmpty) {
      url += '&accessories=$accessory';
    }

    // IMPORTANT: The parameter is 'clothingType' not 'clothing'
    url += '&clothingType=$clothingType';
    url += '&clothingColor=$clothingColor';

    print('Generated avatar URL: $url'); // Debug output

    return url;
  }

  // Get saved avatar preferences for the current user
  static Future<Map<String, dynamic>> getSavedAvatarPreferences() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      DocumentSnapshot userDoc =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('settings')
              .doc('avatarPreferences')
              .get();

      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      } else {
        // Return default preferences if none are saved
        return {
          'background': 'circle',
          'skinTone': 'light',
          'eyeType': 'default',
          'eyebrowType': 'default',
          'mouthType': 'default',
          'hairStyle': 'default',
          'hairColor': 'brown',
          'facialHair': 'blank',
          'facialHairColor': 'brown',
          'accessory': 'blank',
          'clothingType': 'blazerShirt',
          'clothingColor': 'blue01',
        };
      }
    } catch (e) {
      print('Error getting avatar preferences: $e');
      rethrow;
    }
  }

  // Save avatar preferences to Firestore
  static Future<void> saveAvatarPreferences(
    Map<String, dynamic> preferences,
  ) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('avatarPreferences')
          .set({...preferences, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error saving avatar preferences: $e');
      rethrow;
    }
  }

  // Save avatar image to device - direct save as SVG with improved permission handling
  static Future<String> saveAvatarToDevice(String svgUrl) async {
    try {
      print('Attempting to save avatar from URL: $svgUrl');

      // Try different permission approaches
      bool hasPermission = false;

      // First check if we already have permission
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) {
        print('Already have storage permission');
        hasPermission = true;
      } else {
        print('Requesting storage permission...');
        // Request storage permission
        final storageResult = await Permission.storage.request();
        hasPermission = storageResult.isGranted;

        // If still not granted, try manage external storage on newer Android versions
        if (!hasPermission) {
          print('Storage permission denied, trying manage external storage...');
          final manageResult = await Permission.manageExternalStorage.request();
          hasPermission = manageResult.isGranted;
        }
      }

      if (hasPermission) {
        print('Storage permission granted');

        // Fetch SVG content as string
        final svgString = await fetchSvgString(svgUrl);
        print('SVG content fetched successfully, length: ${svgString.length}');

        // Try different directories if one fails
        Directory? directory;

        try {
          // First try app documents directory (always accessible)
          directory = await getApplicationDocumentsDirectory();
          print('Using app documents directory: ${directory.path}');
        } catch (e) {
          print('Failed to get app documents directory: $e');

          try {
            // Then try external storage directory
            directory = await getExternalStorageDirectory();
            print('Using external storage directory: ${directory?.path}');
          } catch (e) {
            print('Failed to get external storage directory: $e');

            // Last resort, try temporary directory
            directory = await getTemporaryDirectory();
            print('Using temporary directory: ${directory.path}');
          }
        }

        if (directory == null) {
          throw Exception('Could not find any writable directory');
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = '${directory.path}/avatar_$timestamp.svg';
        print('Saving to path: $path');

        // Save SVG file
        final file = File(path);
        await file.writeAsString(svgString);
        print('File saved successfully to: $path');

        return path;
      } else {
        print('All storage permission approaches failed');
        throw Exception('Storage permission denied');
      }
    } catch (e) {
      print('Error saving avatar to device: $e');
      rethrow;
    }
  }

  // Save avatar to Firebase Storage and update user profile
  static Future<String> saveAvatarToFirebase(String svgUrl) async {
    try {
      print('Attempting to save avatar to Firebase from URL: $svgUrl');

      User? user = _auth.currentUser;
      if (user == null) {
        print('No user logged in');
        throw Exception('User not logged in');
      }

      // Fetch SVG content as string
      print('Fetching SVG content');
      final svgString = await fetchSvgString(svgUrl);
      print('SVG content fetched, length: ${svgString.length}');

      // Upload SVG content directly to Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = _storage.ref().child(
        'avatars/${user.uid}_$timestamp.svg',
      );
      print('Uploading to Firebase Storage');

      final uploadTask = storageRef.putString(
        svgString,
        format: PutStringFormat.raw,
        metadata: SettableMetadata(contentType: 'image/svg+xml'),
      );
      print('Upload started');
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update user profile with avatar URL
      await _firestore.collection('users').doc(user.uid).update({
        'avatar': downloadUrl,
        'avatarUpdatedAt': FieldValue.serverTimestamp(),
      });

      return downloadUrl;
    } catch (e) {
      print('Error saving avatar to Firebase: $e');
      rethrow;
    }
  }

  // Helper method to build an avatar widget from various sources
  static Widget buildAvatar({
    required String? avatarUrl,
    required String? selectedAsset,
    double radius = 60.0,
    Color defaultBackgroundColor = Colors.white,
    Color defaultIconColor = Colors.black54,
  }) {
    if (avatarUrl != null && avatarUrl.startsWith('http')) {
      // If we have a URL avatar (from Firebase Storage or DiceBear)
      return CircleAvatar(
        radius: radius,
        backgroundColor: defaultBackgroundColor,
        // Use errorBuilder to handle image loading failures
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback if the image fails to load
              return Icon(
                Icons.person,
                size: radius * 1.3,
                color: defaultIconColor,
              );
            },
          ),
        ),
      );
    } else if (selectedAsset != null && selectedAsset.isNotEmpty) {
      // If we have a local asset avatar
      return CircleAvatar(
        radius: radius,
        backgroundImage: AssetImage(selectedAsset),
      );
    } else {
      // Default avatar (just an icon)
      return CircleAvatar(
        radius: radius,
        backgroundColor: defaultBackgroundColor,
        child: Icon(Icons.person, size: radius * 1.3, color: defaultIconColor),
      );
    }
  }

  // Get a list of available avatar option maps for customization
  static Map<String, Map<String, String>> getAvatarOptionMaps() {
    return {
      'backgroundOptions': {'transparent': 'Transparent', 'circle': 'Circle'},
      'skinToneOptions': {
        'light': 'Light',
        'yellow': 'Yellow',
        'brown': 'Brown',
        'dark': 'Dark',
        'black': 'Black',
        'red': 'Red',
        'tanned': 'Tanned',
      },
      'eyeTypeOptions': {
        'default': 'Default',
        'close': 'Close',
        'cry': 'Cry',
        'dizzy': 'Dizzy',
        'eyeRoll': 'Eye Roll',
        'happy': 'Happy',
        'hearts': 'Hearts',
        'side': 'Side',
        'squint': 'Squint',
        'surprised': 'Surprised',
        'wink': 'Wink',
        'winkWacky': 'Wink Wacky',
      },
      'eyebrowTypeOptions': {
        'default': 'Default',
        'angry': 'Angry',
        'angryNatural': 'Angry Natural',
        'flat': 'Flat',
        'flatNatural': 'Flat Natural',
        'frownNatural': 'Frown Natural',
        'raised': 'Raised',
        'raisedExcited': 'Raised Excited',
        'raisedExcitedNatural': 'Raised Excited Natural',
        'sadConcerned': 'Sad Concerned',
        'sadConcernedNatural': 'Sad Concerned Natural',
        'unibrowNatural': 'Unibrow Natural',
        'upDown': 'Up Down',
        'upDownNatural': 'Up Down Natural',
      },
      'mouthTypeOptions': {
        'default': 'Default',
        'concerned': 'Concerned',
        'disbelief': 'Disbelief',
        'eating': 'Eating',
        'grimace': 'Grimace',
        'sad': 'Sad',
        'screamOpen': 'Scream Open',
        'serious': 'Serious',
        'smile': 'Smile',
        'tongue': 'Tongue',
        'twinkle': 'Twinkle',
        'vomit': 'Vomit',
      },
      'hairStyleOptions': {
        'default': 'Default',
        'blank': 'No Hair',
        'bob': 'Bob',
        'bun': 'Bun',
        'curly': 'Curly',
        'curvy': 'Curvy',
        'dreads': 'Dreads',
        'frida': 'Frida',
        'fro': 'Fro',
        'froBand': 'Fro with Band',
        'long': 'Long',
        'longButt': 'Long Butt',
        'miaWallace': 'Mia Wallace',
        'notFound': 'Not Found (404)',
        'shavedSides': 'Shaved Sides',
        'straight01': 'Straight 1',
        'straight02': 'Straight 2',
        'straightAndStrand': 'Straight and Strand',
        'shortCurly': 'Short Curly',
        'shortFlat': 'Short Flat',
        'shortRound': 'Short Round',
        'shortWaved': 'Short Waved',
        'sides': 'Sides',
        'theCaesar': 'The Caesar',
        'theCaesarAndSidePart': 'Caesar and Side Part',
        'winterHat': 'Winter Hat',
      },
      'hairColorOptions': {
        'auburn': 'Auburn',
        'black': 'Black',
        'blonde': 'Blonde',
        'blondeGolden': 'Blonde Golden',
        'brown': 'Brown',
        'brownDark': 'Brown Dark',
        'pastelPink': 'Pastel Pink',
        'platinum': 'Platinum',
        'red': 'Red',
        'silverGray': 'Silver Gray',
      },
      'facialHairOptions': {
        'blank': 'None',
        'beardLight': 'Beard Light',
        'beardMajestic': 'Beard Majestic',
        'beardMedium': 'Beard Medium',
        'moustacheFancy': 'Moustache Fancy',
        'moustacheMagnum': 'Moustache Magnum',
      },
      'facialHairColorOptions': {
        'auburn': 'Auburn',
        'black': 'Black',
        'blonde': 'Blonde',
        'blondeGolden': 'Blonde Golden',
        'brown': 'Brown',
        'brownDark': 'Brown Dark',
        'platinum': 'Platinum',
        'red': 'Red',
      },
      'accessoryOptions': {
        'blank': 'None',
        'eyepatch': 'Eyepatch',
        'kurt': 'Kurt',
        'prescription01': 'Prescription Glasses 1',
        'prescription02': 'Prescription Glasses 2',
        'round': 'Round Glasses',
        'sunglasses': 'Sunglasses',
        'wayfarers': 'Wayfarers',
      },
      'clothingTypeOptions': {
        'blazerShirt': 'Blazer with Shirt',
        'blazerSweater': 'Blazer with Sweater',
        'collarSweater': 'Collar with Sweater',
        'graphicShirt': 'Graphic Shirt',
        'hoodie': 'Hoodie',
        'overall': 'Overall',
        'shirtCrewNeck': 'Crew Neck Shirt',
        'shirtScoopNeck': 'Scoop Neck Shirt',
        'shirtVNeck': 'V-Neck Shirt',
      },
      'clothingColorOptions': {
        'black': 'Black',
        'blue01': 'Blue (Light)',
        'blue02': 'Blue (Dark)',
        'blue03': 'Blue (Sky)',
        'gray01': 'Gray (Light)',
        'gray02': 'Gray (Dark)',
        'heather': 'Heather',
        'pastelBlue': 'Pastel Blue',
        'pastelGreen': 'Pastel Green',
        'pastelOrange': 'Pastel Orange',
        'pastelRed': 'Pastel Red',
        'pastelYellow': 'Pastel Yellow',
        'pink': 'Pink',
        'red': 'Red',
        'white': 'White',
      },
    };
  }
}
