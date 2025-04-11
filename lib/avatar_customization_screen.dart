import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';

class AvatarCustomizationScreen extends StatefulWidget {
  const AvatarCustomizationScreen({Key? key}) : super(key: key);

  @override
  _AvatarCustomizationScreenState createState() =>
      _AvatarCustomizationScreenState();
}

class _AvatarCustomizationScreenState extends State<AvatarCustomizationScreen> {
  // Avatar options
  String _background = 'circle';
  String _skinTone = 'light';
  String _eyeType = 'default';
  String _eyebrowType = 'default';
  String _mouthType = 'default';
  String _hairStyle = 'default';
  String _hairColor = 'brown';
  String _facialHair = 'blank';
  String _facialHairColor = 'brown';
  String _accessory = 'blank';
  String _clothingType = 'blazerShirt';
  String _clothingColor = 'blue01';

  // String URL for the current avatar
  String _svgUrl = '';

  // SVG content if loaded
  String? _svgContent;

  // Loading states
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Initialize with saved preferences
  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  // Load saved avatar preferences for the user
  Future<void> _loadSavedPreferences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('settings')
                .doc('avatarPreferences')
                .get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          setState(() {
            _background = data['background'] ?? 'circle';
            _skinTone = data['skinTone'] ?? 'light';
            _eyeType = data['eyeType'] ?? 'default';
            _eyebrowType = data['eyebrowType'] ?? 'default';
            _mouthType = data['mouthType'] ?? 'default';
            _hairStyle = data['hairStyle'] ?? 'default';
            _hairColor = data['hairColor'] ?? 'brown';
            _facialHair = data['facialHair'] ?? 'blank';
            _facialHairColor = data['facialHairColor'] ?? 'brown';
            _accessory = data['accessory'] ?? 'blank';
            _clothingType = data['clothingType'] ?? 'blazerShirt';
            _clothingColor = data['clothingColor'] ?? 'blue01';
          });
        }
      }

      // Generate the avatar URL
      _generateAvatarUrl();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading preferences: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Generate the URL for the DiceBear Avataaars API
  void _generateAvatarUrl() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Use the current DiceBear API v7.x URL format
    String url = 'https://api.dicebear.com/7.x/avataaars/svg?seed=$timestamp';

    // Use the current parameter names
    url += '&skinColor=$_skinTone';
    url += '&top=$_hairStyle';
    url += '&hairColor=$_hairColor';
    url += '&facialHair=$_facialHair';
    url += '&facialHairColor=$_facialHairColor';
    url += '&clothing=$_clothingType';
    url += '&clothingColor=$_clothingColor';
    url += '&eyes=$_eyeType';
    url += '&eyebrows=$_eyebrowType';
    url += '&mouth=$_mouthType';

    if (_accessory != 'blank') {
      url += '&accessories=$_accessory';
    }

    setState(() {
      _svgUrl = url;
      _loadSvgContent();
    });

    print('Generated avatar URL: $_svgUrl');
  }

  // Load the SVG content
  Future<void> _loadSvgContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _svgContent = null;
    });

    try {
      final response = await http.get(
        Uri.parse(_svgUrl),
        headers: {
          'Accept': 'image/svg+xml',
          'User-Agent': 'Mozilla/5.0 Flutter App',
        },
      );

      if (response.statusCode == 200) {
        final content = response.body;
        if (content.contains('<svg') && content.contains('</svg>')) {
          setState(() {
            _svgContent = content;
            _errorMessage = null;
          });
        } else {
          throw Exception('Invalid SVG content received');
        }
      } else {
        throw Exception('Failed to download SVG: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading SVG: $e');
      setState(() {
        _errorMessage = 'Error loading avatar';
      });

      // Try fallback URL with different API version
      try {
        final fallbackUrl =
            'https://api.dicebear.com/6.x/avataaars/svg?seed=${DateTime.now().millisecondsSinceEpoch}';
        final fallbackResponse = await http.get(
          Uri.parse(fallbackUrl),
          headers: {
            'Accept': 'image/svg+xml',
            'User-Agent': 'Mozilla/5.0 Flutter App',
          },
        );

        if (fallbackResponse.statusCode == 200) {
          final content = fallbackResponse.body;
          if (content.contains('<svg') && content.contains('</svg>')) {
            setState(() {
              _svgContent = content;
              _errorMessage = null;
            });
          }
        }
      } catch (fallbackError) {
        print('Fallback error: $fallbackError');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Save the current avatar to the user's device
  Future<void> _saveToDevice() async {
    if (_svgContent == null) {
      setState(() {
        _errorMessage = 'No valid avatar to save';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Request storage permissions
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission denied');
      }

      // Get the app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/avatar_$timestamp.svg';

      // Save the SVG file
      final file = File(path);
      await file.writeAsString(_svgContent!);

      setState(() {
        _errorMessage = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Avatar saved to ${file.path}')));
    } catch (e) {
      print('Error saving to device: $e');
      setState(() {
        _errorMessage = 'Error saving avatar to device: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Save the current avatar to the user's profile
  Future<void> _saveToProfile() async {
    if (_svgContent == null) {
      setState(() {
        _errorMessage = 'No valid avatar to save';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Save preferences to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('avatarPreferences')
          .set({
            'background': _background,
            'skinTone': _skinTone,
            'eyeType': _eyeType,
            'eyebrowType': _eyebrowType,
            'mouthType': _mouthType,
            'hairStyle': _hairStyle,
            'hairColor': _hairColor,
            'facialHair': _facialHair,
            'facialHairColor': _facialHairColor,
            'accessory': _accessory,
            'clothingType': _clothingType,
            'clothingColor': _clothingColor,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Upload SVG to Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance.ref().child(
        'avatars/${user.uid}_$timestamp.svg',
      );

      await storageRef.putString(
        _svgContent!,
        format: PutStringFormat.raw,
        metadata: SettableMetadata(contentType: 'image/svg+xml'),
      );

      // Get the download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Update user profile
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          'avatar': downloadUrl,
          'avatarUpdatedAt': FieldValue.serverTimestamp(),
        },
      );

      setState(() {
        _errorMessage = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Avatar saved to profile')));
    } catch (e) {
      print('Error saving to profile: $e');
      setState(() {
        _errorMessage = 'Error saving avatar to profile: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Build the avatar preview widget
  Widget _buildAvatarPreview() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_svgContent != null) {
      return SvgPicture.string(_svgContent!, height: 200, width: 200);
    }

    // Fallback to showing a simple CircleAvatar
    return CircleAvatar(
      radius: 100,
      backgroundColor: Colors.grey.shade300,
      child: Icon(Icons.person, size: 100, color: Colors.grey.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Your Avatar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading || _isSaving ? null : () => _saveToProfile(),
            tooltip: 'Save to Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar preview
              Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Center(child: _buildAvatarPreview()),
              ),

              // Error message
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Save buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Save to Device'),
                      onPressed:
                          _isLoading || _isSaving
                              ? null
                              : () => _saveToDevice(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Save to Profile'),
                      onPressed:
                          _isLoading || _isSaving
                              ? null
                              : () => _saveToProfile(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Style section
              const Text(
                'Style',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Background'),
              DropdownButton<String>(
                value: _background,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _background = value;
                      _generateAvatarUrl();
                    });
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'circle', child: Text('Circle')),
                  DropdownMenuItem(
                    value: 'transparent',
                    child: Text('Transparent'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Personal Attributes section
              const Text(
                'Personal Attributes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Skin Tone
              const Text('Skin Tone'),
              DropdownButton<String>(
                value: _skinTone,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _skinTone = value;
                      _generateAvatarUrl();
                    });
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'light', child: Text('Light')),
                  DropdownMenuItem(value: 'yellow', child: Text('Yellow')),
                  DropdownMenuItem(value: 'brown', child: Text('Brown')),
                  DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  DropdownMenuItem(value: 'black', child: Text('Black')),
                  DropdownMenuItem(value: 'red', child: Text('Red')),
                  DropdownMenuItem(value: 'tanned', child: Text('Tanned')),
                ],
              ),

              // Eyes
              const SizedBox(height: 8),
              const Text('Eyes'),
              DropdownButton<String>(
                value: _eyeType,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _eyeType = value;
                      _generateAvatarUrl();
                    });
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'default', child: Text('Default')),
                  DropdownMenuItem(value: 'close', child: Text('Close')),
                  DropdownMenuItem(value: 'cry', child: Text('Cry')),
                  DropdownMenuItem(value: 'dizzy', child: Text('Dizzy')),
                  DropdownMenuItem(value: 'eyeRoll', child: Text('Eye Roll')),
                  DropdownMenuItem(value: 'happy', child: Text('Happy')),
                  DropdownMenuItem(value: 'hearts', child: Text('Hearts')),
                  DropdownMenuItem(value: 'side', child: Text('Side')),
                  DropdownMenuItem(value: 'squint', child: Text('Squint')),
                  DropdownMenuItem(
                    value: 'surprised',
                    child: Text('Surprised'),
                  ),
                  DropdownMenuItem(value: 'wink', child: Text('Wink')),
                  DropdownMenuItem(
                    value: 'winkWacky',
                    child: Text('Wink Wacky'),
                  ),
                ],
              ),

              // Eyebrows
              const SizedBox(height: 8),
              const Text('Eyebrows'),
              DropdownButton<String>(
                value: _eyebrowType,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _eyebrowType = value;
                      _generateAvatarUrl();
                    });
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'default', child: Text('Default')),
                  DropdownMenuItem(value: 'angry', child: Text('Angry')),
                  DropdownMenuItem(
                    value: 'angryNatural',
                    child: Text('Angry Natural'),
                  ),
                  DropdownMenuItem(value: 'flat', child: Text('Flat')),
                  DropdownMenuItem(value: 'raised', child: Text('Raised')),
                  DropdownMenuItem(value: 'sad', child: Text('Sad')),
                  DropdownMenuItem(value: 'unibrow', child: Text('Unibrow')),
                  DropdownMenuItem(value: 'upDown', child: Text('Up Down')),
                  DropdownMenuItem(
                    value: 'upDownNatural',
                    child: Text('Up Down Natural'),
                  ),
                ],
              ),

              // Mouth
              const SizedBox(height: 8),
              const Text('Mouth'),
              DropdownButton<String>(
                value: _mouthType,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _mouthType = value;
                      _generateAvatarUrl();
                    });
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'default', child: Text('Default')),
                  DropdownMenuItem(
                    value: 'concerned',
                    child: Text('Concerned'),
                  ),
                  DropdownMenuItem(
                    value: 'disbelief',
                    child: Text('Disbelief'),
                  ),
                  DropdownMenuItem(value: 'eating', child: Text('Eating')),
                  DropdownMenuItem(value: 'grimace', child: Text('Grimace')),
                  DropdownMenuItem(value: 'sad', child: Text('Sad')),
                  DropdownMenuItem(
                    value: 'screamOpen',
                    child: Text('Scream Open'),
                  ),
                  DropdownMenuItem(value: 'serious', child: Text('Serious')),
                  DropdownMenuItem(value: 'smile', child: Text('Smile')),
                  DropdownMenuItem(value: 'tongue', child: Text('Tongue')),
                  DropdownMenuItem(value: 'twinkle', child: Text('Twinkle')),
                ],
              ),

              // Hair section
              const SizedBox(height: 16),
              const Text(
                'Hair',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              // Hair Style
              const SizedBox(height: 8),
              const Text('Hairstyle'),
              DropdownButton<String>(
                value: _hairStyle,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _hairStyle = value;
                      _generateAvatarUrl();
                    });
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'default', child: Text('Default')),
                  DropdownMenuItem(value: 'noHair', child: Text('No Hair')),
                  DropdownMenuItem(value: 'hat', child: Text('Hat')),
                  DropdownMenuItem(value: 'hijab', child: Text('Hijab')),
                  DropdownMenuItem(value: 'turban', child: Text('Turban')),
                  DropdownMenuItem(value: 'bigHair', child: Text('Big Hair')),
                  DropdownMenuItem(value: 'bob', child: Text('Bob')),
                  DropdownMenuItem(value: 'bun', child: Text('Bun')),
                  DropdownMenuItem(value: 'curly', child: Text('Curly')),
                  DropdownMenuItem(value: 'dreads', child: Text('Dreads')),
                  DropdownMenuItem(value: 'frida', child: Text('Frida')),
                  DropdownMenuItem(value: 'fro', child: Text('Fro')),
                  DropdownMenuItem(value: 'long', child: Text('Long')),
                  DropdownMenuItem(value: 'shaved', child: Text('Shaved')),
                  DropdownMenuItem(
                    value: 'straight1',
                    child: Text('Straight 1'),
                  ),
                  DropdownMenuItem(
                    value: 'straight2',
                    child: Text('Straight 2'),
                  ),
                ],
              ),

              // Hair Color
              const SizedBox(height: 8),
              const Text('Hair Color'),
              DropdownButton<String>(
                value: _hairColor,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _hairColor = value;
                      _generateAvatarUrl();
                    });
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'black', child: Text('Black')),
                  DropdownMenuItem(value: 'blonde', child: Text('Blonde')),
                  DropdownMenuItem(value: 'brown', child: Text('Brown')),
                  DropdownMenuItem(value: 'red', child: Text('Red')),
                  DropdownMenuItem(value: 'gray', child: Text('Gray')),
                ],
              ),

              // Facial Hair
              const SizedBox(height: 8),
              const Text('Facial Hair'),
              DropdownButton<String>(
                value: _facialHair,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _facialHair = value;
                      _generateAvatarUrl();
                    });
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'blank', child: Text('None')),
                  DropdownMenuItem(
                    value: 'beardLight',
                    child: Text('Beard Light'),
                  ),
                  DropdownMenuItem(
                    value: 'beardMajestic',
                    child: Text('Beard Majestic'),
                  ),
                  DropdownMenuItem(
                    value: 'beardMedium',
                    child: Text('Beard Medium'),
                  ),
                  DropdownMenuItem(
                    value: 'moustacheFancy',
                    child: Text('Moustache Fancy'),
                  ),
                  DropdownMenuItem(
                    value: 'moustacheMagnum',
                    child: Text('Moustache Magnum'),
                  ),
                ],
              ),

              // Facial Hair Color (only show if facial hair is selected)
              if (_facialHair != 'blank') ...[
                const SizedBox(height: 8),
                const Text('Facial Hair Color'),
                DropdownButton<String>(
                  value: _facialHairColor,
                  isExpanded: true,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _facialHairColor = value;
                        _generateAvatarUrl();
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'black', child: Text('Black')),
                    DropdownMenuItem(value: 'blonde', child: Text('Blonde')),
                    DropdownMenuItem(value: 'brown', child: Text('Brown')),
                    DropdownMenuItem(value: 'red', child: Text('Red')),
                    DropdownMenuItem(value: 'gray', child: Text('Gray')),
                  ],
                ),
              ],

              // Accessories
              const SizedBox(height: 16),
              const Text(
                'Accessories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Accessories'),
              DropdownButton<String>(
                value: _accessory,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _accessory = value;
                      _generateAvatarUrl();
                    });
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'blank', child: Text('None')),
                  DropdownMenuItem(value: 'eyepatch', child: Text('Eyepatch')),
                  DropdownMenuItem(value: 'kurt', child: Text('Kurt')),
                  DropdownMenuItem(
                    value: 'prescription01',
                    child: Text('Glasses 1'),
                  ),
                  DropdownMenuItem(
                    value: 'prescription02',
                    child: Text('Glasses 2'),
                  ),
                  DropdownMenuItem(
                    value: 'round',
                    child: Text('Round Glasses'),
                  ),
                  DropdownMenuItem(
                    value: 'sunglasses',
                    child: Text('Sunglasses'),
                  ),
                  DropdownMenuItem(
                    value: 'wayfarers',
                    child: Text('Wayfarers'),
                  ),
                ],
              ),

              // Clothing section
              const SizedBox(height: 16),
              const Text(
                'Clothes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              // Clothing Type
              const SizedBox(height: 8),
              const Text('Clothing Type'),
              DropdownButton<String>(
                value: _clothingType,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _clothingType = value;
                      _generateAvatarUrl();
                    });
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: 'blazerShirt',
                    child: Text('Blazer & Shirt'),
                  ),
                  DropdownMenuItem(
                    value: 'blazerSweater',
                    child: Text('Blazer & Sweater'),
                  ),
                  DropdownMenuItem(
                    value: 'collarSweater',
                    child: Text('Collar & Sweater'),
                  ),
                  DropdownMenuItem(
                    value: 'graphicShirt',
                    child: Text('Graphic Shirt'),
                  ),
                  DropdownMenuItem(value: 'hoodie', child: Text('Hoodie')),
                  DropdownMenuItem(value: 'overall', child: Text('Overall')),
                  DropdownMenuItem(
                    value: 'shirtCrewNeck',
                    child: Text('Crew Neck'),
                  ),
                  DropdownMenuItem(
                    value: 'shirtScoopNeck',
                    child: Text('Scoop Neck'),
                  ),
                  DropdownMenuItem(value: 'shirtVNeck', child: Text('V-Neck')),
                ],
              ),

              // Clothing Color
              const SizedBox(height: 8),
              const Text('Clothing Color'),
              DropdownButton<String>(
                value: _clothingColor,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _clothingColor = value;
                      _generateAvatarUrl();
                    });
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'black', child: Text('Black')),
                  DropdownMenuItem(
                    value: 'blue01',
                    child: Text('Blue (Light)'),
                  ),
                  DropdownMenuItem(value: 'blue02', child: Text('Blue (Dark)')),
                  DropdownMenuItem(value: 'blue03', child: Text('Blue (Sky)')),
                  DropdownMenuItem(
                    value: 'gray01',
                    child: Text('Gray (Light)'),
                  ),
                  DropdownMenuItem(value: 'gray02', child: Text('Gray (Dark)')),
                  DropdownMenuItem(value: 'heather', child: Text('Heather')),
                  DropdownMenuItem(
                    value: 'pastelBlue',
                    child: Text('Pastel Blue'),
                  ),
                  DropdownMenuItem(
                    value: 'pastelGreen',
                    child: Text('Pastel Green'),
                  ),
                  DropdownMenuItem(
                    value: 'pastelOrange',
                    child: Text('Pastel Orange'),
                  ),
                  DropdownMenuItem(
                    value: 'pastelRed',
                    child: Text('Pastel Red'),
                  ),
                  DropdownMenuItem(
                    value: 'pastelYellow',
                    child: Text('Pastel Yellow'),
                  ),
                  DropdownMenuItem(value: 'pink', child: Text('Pink')),
                  DropdownMenuItem(value: 'red', child: Text('Red')),
                  DropdownMenuItem(value: 'white', child: Text('White')),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
