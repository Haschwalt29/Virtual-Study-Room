import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';
import 'theme_provider.dart';
import 'flashcard_quiz_screen.dart';

class FlashcardsScreen extends StatefulWidget {
  @override
  _FlashcardsScreenState createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Animation controllers and animations for card flips
  final Map<String, AnimationController> _flipControllers = {};
  final Map<String, Animation<double>> _flipAnimations = {};
  final Set<String> _flippedCards = {};

  // Flashcards list and loading state
  List<Map<String, dynamic>> _flashcards = [];
  bool _isLoading = true;

  // Stream subscription
  StreamSubscription<QuerySnapshot>? _flashcardsSubscription;

  // Selected flashcard for editing
  Map<String, dynamic>? _selectedFlashcard;

  // Controllers for flashcard input
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();

  // Customization options
  Color _selectedColor = Colors.blue;
  double _selectedFontSize = 18.0;
  String _selectedFontFamily = 'Roboto';
  FontWeight _selectedFontWeight = FontWeight.normal;
  TextAlign _selectedTextAlign = TextAlign.center;

  // Available customization options
  final List<Color> _availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.indigo,
    Colors.deepOrange,
  ];

  final List<String> _availableFonts = [
    'Roboto',
    'Lato',
    'OpenSans',
    'Montserrat',
    'Quicksand',
    'Raleway',
  ];

  final List<FontWeight> _availableFontWeights = [
    FontWeight.normal,
    FontWeight.bold,
    FontWeight.w200,
    FontWeight.w500,
    FontWeight.w800,
  ];

  final List<TextAlign> _availableAlignments = [
    TextAlign.center,
    TextAlign.left,
    TextAlign.right,
  ];

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  // Load flashcards from Firestore
  void _loadFlashcards() {
    try {
      setState(() {
        _isLoading = true;
      });

      // Cancel any existing subscription
      _flashcardsSubscription?.cancel();

      // Simplified query that doesn't require a complex index
      final flashcardsQuery = _firestore
          .collection('flashcards')
          .where('userId', isEqualTo: _auth.currentUser?.uid);

      // Subscribe to query
      _flashcardsSubscription = flashcardsQuery.snapshots().listen(
        (snapshot) {
          if (mounted) {
            final flashcardDocs = snapshot.docs;
            final List<Map<String, dynamic>> flashcards = [];

            for (var doc in flashcardDocs) {
              final data = doc.data() as Map<String, dynamic>;
              flashcards.add({'id': doc.id, ...data});
            }

            // Sort locally instead of in the query to avoid index requirement
            flashcards.sort((a, b) {
              // Handle null timestamps by putting them at the end
              final aTimestamp = a['createdAt'] as Timestamp?;
              final bTimestamp = b['createdAt'] as Timestamp?;

              if (aTimestamp == null) return 1;
              if (bTimestamp == null) return -1;

              // Sort descending (newest first)
              return bTimestamp.compareTo(aTimestamp);
            });

            setState(() {
              _flashcards = flashcards;
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          print('Error loading flashcards: $error');

          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading flashcards: ${error.toString()}'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: _loadFlashcards,
                ),
              ),
            );
          }
        },
      );
    } catch (e) {
      print('Error setting up flashcards listener: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Add a new flashcard
  Future<void> _addFlashcard() async {
    if (_questionController.text.trim().isEmpty ||
        _answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter both a question and an answer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        setState(() {
          _isLoading = true;
        });

        // Create a loading indicator overlay
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.purple,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        _selectedFlashcard != null
                            ? "Updating flashcard..."
                            : "Creating flashcard...",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );

        // Create flashcard map
        final Map<String, dynamic> flashcardData = {
          'question': _questionController.text.trim(),
          'answer': _answerController.text.trim(),
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          // Customization options
          'color': _selectedColor.value,
          'fontSize': _selectedFontSize,
          'fontFamily': _selectedFontFamily,
          'fontWeight': _selectedFontWeight.index,
          'textAlign': _selectedTextAlign.index,
        };

        // If editing, update existing flashcard
        if (_selectedFlashcard != null &&
            _selectedFlashcard!.containsKey('id')) {
          await _firestore
              .collection('flashcards')
              .doc(_selectedFlashcard!['id'])
              .update(flashcardData);

          // Add to local state immediately for a responsive UI
          int index = _flashcards.indexWhere(
            (card) => card['id'] == _selectedFlashcard!['id'],
          );
          if (index != -1 && mounted) {
            setState(() {
              _flashcards[index] = {
                'id': _selectedFlashcard!['id'],
                ...flashcardData,
                // Add a temporary timestamp until Firestore updates
                'createdAt':
                    _selectedFlashcard!['createdAt'] ?? Timestamp.now(),
              };
            });
          }
        } else {
          // Add new flashcard to Firestore
          DocumentReference docRef = await _firestore
              .collection('flashcards')
              .add(flashcardData);

          // Add to local state immediately for a responsive UI
          if (mounted) {
            setState(() {
              _flashcards.insert(0, {
                'id': docRef.id,
                ...flashcardData,
                // Add a temporary timestamp until Firestore updates
                'createdAt': Timestamp.now(),
              });
            });
          }
        }

        // Clear form
        _questionController.clear();
        _answerController.clear();

        // Update state and dismiss loading dialog
        if (mounted) {
          setState(() {
            _selectedFlashcard = null;
            _isLoading = false;
          });

          // Pop loading dialog
          Navigator.of(context, rootNavigator: true).pop();

          // Close creation dialog
          Navigator.of(context).pop();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _selectedFlashcard != null
                    ? 'Flashcard updated successfully!'
                    : 'Flashcard created successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error adding/updating flashcard: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding flashcard: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Delete a flashcard
  Future<void> _deleteFlashcard(String flashcardId) async {
    try {
      // Show confirmation dialog
      bool confirmDelete =
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text("Confirm Delete"),
                  content: Text(
                    "Are you sure you want to delete this flashcard? This action cannot be undone.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text("Delete"),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!confirmDelete) return;

      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      // Store the index and card before deletion for potential undo
      int cardIndex = _flashcards.indexWhere(
        (card) => card['id'] == flashcardId,
      );
      Map<String, dynamic>? deletedCard;

      if (cardIndex != -1) {
        deletedCard = Map<String, dynamic>.from(_flashcards[cardIndex]);

        // Update local state immediately before Firestore operation
        setState(() {
          _flashcards.removeAt(cardIndex);
        });
      }

      // Delete from Firestore
      await _firestore.collection('flashcards').doc(flashcardId).delete();

      setState(() {
        _isLoading = false;
      });

      // Show success message with undo option
      if (deletedCard != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Flashcard deleted'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                try {
                  // Remove ID before adding back to Firestore
                  String deletedId = deletedCard!['id'] as String;
                  deletedCard!.remove('id');

                  // Restore the document with its original ID
                  await _firestore
                      .collection('flashcards')
                      .doc(deletedId)
                      .set(deletedCard!);

                  // No need to update state here as the stream will handle it
                } catch (e) {
                  print('Error restoring flashcard: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error restoring flashcard: ${e.toString()}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Error deleting flashcard: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting flashcard: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

      // Refresh the list to ensure UI is in sync with database
      _loadFlashcards();
    }
  }

  // Edit a flashcard
  void _editFlashcard(Map<String, dynamic> flashcard) {
    setState(() {
      _selectedFlashcard = flashcard;
      _questionController.text = flashcard['question'] ?? '';
      _answerController.text = flashcard['answer'] ?? '';

      // Set customization options from the flashcard data
      _selectedColor = Color(flashcard['color'] ?? Colors.blue.value);
      _selectedFontSize = flashcard['fontSize'] ?? 18.0;
      _selectedFontFamily = flashcard['fontFamily'] ?? 'Roboto';

      // Handle font weight and text align indices
      int fontWeightIndex = flashcard['fontWeight'] ?? 0;
      if (fontWeightIndex >= 0 &&
          fontWeightIndex < _availableFontWeights.length) {
        _selectedFontWeight = _availableFontWeights[fontWeightIndex];
      } else {
        _selectedFontWeight = FontWeight.normal;
      }

      int textAlignIndex = flashcard['textAlign'] ?? 0;
      if (textAlignIndex >= 0 && textAlignIndex < _availableAlignments.length) {
        _selectedTextAlign = _availableAlignments[textAlignIndex];
      } else {
        _selectedTextAlign = TextAlign.center;
      }
    });

    _showAddFlashcardDialog();
  }

  // Format flashcard for display
  TextStyle _getFlashcardTextStyle(Map<String, dynamic> flashcard) {
    Color cardColor;
    double fontSize;
    String fontFamily;
    FontWeight fontWeight;

    try {
      cardColor = Color(flashcard['color'] ?? Colors.blue.value);
      fontSize = flashcard['fontSize'] ?? 18.0;
      fontFamily = flashcard['fontFamily'] ?? 'Roboto';

      int fontWeightIndex = flashcard['fontWeight'] ?? 0;
      if (fontWeightIndex >= 0 &&
          fontWeightIndex < _availableFontWeights.length) {
        fontWeight = _availableFontWeights[fontWeightIndex];
      } else {
        fontWeight = FontWeight.normal;
      }
    } catch (e) {
      // Fallback if any parsing error occurs
      cardColor = Colors.blue;
      fontSize = 18.0;
      fontFamily = 'Roboto';
      fontWeight = FontWeight.normal;
    }

    return TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontWeight: fontWeight,
    );
  }

  TextAlign _getFlashcardTextAlign(Map<String, dynamic> flashcard) {
    try {
      int textAlignIndex = flashcard['textAlign'] ?? 0;
      if (textAlignIndex >= 0 && textAlignIndex < _availableAlignments.length) {
        return _availableAlignments[textAlignIndex];
      }
    } catch (e) {
      // Fallback
    }
    return TextAlign.center;
  }

  // Show dialog to add or edit a flashcard
  void _showAddFlashcardDialog() {
    // For new flashcards, reset customization options
    if (_selectedFlashcard == null) {
      _questionController.clear();
      _answerController.clear();
      _selectedColor = Colors.blue;
      _selectedFontSize = 18.0;
      _selectedFontFamily = 'Roboto';
      _selectedFontWeight = FontWeight.normal;
      _selectedTextAlign = TextAlign.center;
    }

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(
                    _selectedFlashcard != null
                        ? "Edit Flashcard"
                        : "Create New Flashcard",
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _questionController,
                          decoration: InputDecoration(
                            labelText: "Question/Front Side",
                            hintText: "Enter the question or front side text",
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _answerController,
                          decoration: InputDecoration(
                            labelText: "Answer/Back Side",
                            hintText: "Enter the answer or back side text",
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        SizedBox(height: 24),
                        Text(
                          "Customization Options",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 16),

                        // Card color selection
                        Text("Card Color"),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              _availableColors.map((color) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedColor = color;
                                    });
                                  },
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            _selectedColor == color
                                                ? Colors.white
                                                : Colors.transparent,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        if (_selectedColor == color)
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                        SizedBox(height: 16),

                        // Font size selection
                        Text("Font Size"),
                        Slider(
                          value: _selectedFontSize,
                          min: 14,
                          max: 28,
                          divisions: 7,
                          label: _selectedFontSize.round().toString(),
                          onChanged: (value) {
                            setState(() {
                              _selectedFontSize = value;
                            });
                          },
                        ),

                        // Font family selection
                        Text("Font Style"),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              _availableFonts.map((font) {
                                return ChoiceChip(
                                  label: Text(
                                    font,
                                    style: TextStyle(fontFamily: font),
                                  ),
                                  selected: _selectedFontFamily == font,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedFontFamily = font;
                                      });
                                    }
                                  },
                                );
                              }).toList(),
                        ),
                        SizedBox(height: 16),

                        // Font weight selection
                        Text("Font Weight"),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text("Normal"),
                              selected:
                                  _selectedFontWeight == FontWeight.normal,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedFontWeight = FontWeight.normal;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: Text("Bold"),
                              selected: _selectedFontWeight == FontWeight.bold,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedFontWeight = FontWeight.bold;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: Text("Light"),
                              selected: _selectedFontWeight == FontWeight.w200,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedFontWeight = FontWeight.w200;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: Text("Medium"),
                              selected: _selectedFontWeight == FontWeight.w500,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedFontWeight = FontWeight.w500;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: Text("Black"),
                              selected: _selectedFontWeight == FontWeight.w800,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedFontWeight = FontWeight.w800;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Text alignment selection
                        Text("Text Alignment"),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text("Left"),
                              selected: _selectedTextAlign == TextAlign.left,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedTextAlign = TextAlign.left;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: Text("Center"),
                              selected: _selectedTextAlign == TextAlign.center,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedTextAlign = TextAlign.center;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: Text("Right"),
                              selected: _selectedTextAlign == TextAlign.right,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedTextAlign = TextAlign.right;
                                  });
                                }
                              },
                            ),
                          ],
                        ),

                        // Preview section
                        SizedBox(height: 24),
                        Text(
                          "Preview",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _questionController.text.isEmpty
                                    ? "Sample Question Text"
                                    : _questionController.text,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: _selectedFontSize,
                                  fontFamily: _selectedFontFamily,
                                  fontWeight: _selectedFontWeight,
                                ),
                                textAlign: _selectedTextAlign,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Clear selected flashcard
                        setState(() {
                          _selectedFlashcard = null;
                        });
                      },
                      child: Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      onPressed: _addFlashcard,
                      child: Text(
                        _selectedFlashcard != null ? "Update" : "Create",
                      ),
                    ),
                  ],
                ),
          ),
    ).then((_) {
      // Clear controllers and selected flashcard when dialog is closed
      if (!mounted) return;
      setState(() {
        if (_selectedFlashcard != null) {
          _selectedFlashcard = null;
          _questionController.clear();
          _answerController.clear();
        }
      });
    });
  }

  // Start quiz mode with all flashcards
  void _startQuizMode() {
    if (_flashcards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please create flashcards before starting a quiz'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlashcardQuizScreen(flashcards: _flashcards),
      ),
    );
  }

  // Build the flashcards list
  Widget _buildFlashcardsList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_flashcards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_alt_outlined, size: 72, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No flashcards yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first flashcard by tapping the + button below',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _flashcards.length,
      itemBuilder: (context, index) {
        final flashcard = _flashcards[index];
        final flashcardId = flashcard['id'];
        final Color cardColor = Color(flashcard['color'] ?? Colors.blue.value);

        // Initialize animation controller for this card
        _initCardAnimation(flashcardId);

        return GestureDetector(
          onTap: () => _toggleCardFlip(flashcardId),
          child: AnimatedBuilder(
            animation: _flipAnimations[flashcardId]!,
            builder: (context, child) {
              final isFlipped = _flippedCards.contains(flashcardId);

              // Calculate flip rotation transform
              final transform =
                  Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Perspective
                    ..rotateY(pi * _flipAnimations[flashcardId]!.value);

              // When card is more than halfway flipped, show the back
              if (_flipAnimations[flashcardId]!.value >= 0.5 && isFlipped) {
                // For the back side, we need to apply a counter-rotation to fix the mirrored text
                return Transform(
                  // First apply the basic flip to show the back of the card
                  transform:
                      Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(pi),
                  alignment: Alignment.center,
                  // Then counter-rotate the actual content to make text readable
                  child: Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildCardBack(flashcard, cardColor),
                  ),
                );
              }

              // Use transform for the flip animation
              return Transform(
                transform: transform,
                alignment: Alignment.center,
                child: _buildCardFront(flashcard, cardColor, flashcardId),
              );
            },
          ),
        );
      },
    );
  }

  // Initialize animation controller for a card
  void _initCardAnimation(String flashcardId) {
    // Skip if already initialized
    if (_flipControllers.containsKey(flashcardId)) return;

    // Create animation controller
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );

    // Create animation
    final animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    // Store controller and animation
    _flipControllers[flashcardId] = controller;
    _flipAnimations[flashcardId] = animation;
  }

  // Toggle card flip animation
  void _toggleCardFlip(String flashcardId) {
    // Initialize animation if needed
    if (!_flipControllers.containsKey(flashcardId)) {
      _initCardAnimation(flashcardId);
    }

    setState(() {
      // Toggle flipped state
      if (_flippedCards.contains(flashcardId)) {
        _flippedCards.remove(flashcardId);
        _flipControllers[flashcardId]!.reverse();
      } else {
        _flippedCards.add(flashcardId);
        _flipControllers[flashcardId]!.forward();
      }
    });
  }

  // Build front side of flashcard
  Widget _buildCardFront(
    Map<String, dynamic> flashcard,
    Color cardColor,
    String flashcardId,
  ) {
    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          // Flashcard content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  flashcard['question'] ?? 'Untitled',
                  style: _getFlashcardTextStyle(flashcard),
                  textAlign: _getFlashcardTextAlign(flashcard),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Text(
                  "Tap to flip",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Action buttons
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              children: [
                // Edit button
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.white70, size: 20),
                  tooltip: "Edit",
                  onPressed: () => _editFlashcard(flashcard),
                ),
                // Delete button
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.white70, size: 20),
                  tooltip: "Delete",
                  onPressed: () => _deleteFlashcard(flashcardId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build back side of flashcard
  Widget _buildCardBack(Map<String, dynamic> flashcard, Color cardColor) {
    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          // Answer content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Answer",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  flashcard['answer'] ?? "",
                  style: _getFlashcardTextStyle(flashcard),
                  textAlign: _getFlashcardTextAlign(flashcard),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12),
                Text(
                  "Tap to flip back",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _flashcardsSubscription?.cancel();
    _questionController.dispose();
    _answerController.dispose();

    // Dispose animation controllers
    for (final controller in _flipControllers.values) {
      controller.dispose();
    }
    _flipControllers.clear();
    _flipAnimations.clear();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Virtual Flashcards"),
        actions: [
          // Quiz mode button
          TextButton.icon(
            icon: Icon(Icons.quiz, color: Colors.white),
            label: Text("Quiz Mode", style: TextStyle(color: Colors.white)),
            onPressed: _startQuizMode,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header section
          Container(
            padding: EdgeInsets.all(16.0),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade700, Colors.indigo.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Virtual Flashcards",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Create beautiful flashcards to help you remember key concepts",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.add, size: 18),
                        label: Text("New Flashcard"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.purple.shade700,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _showAddFlashcardDialog,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.quiz, size: 18),
                        label: Text("Quiz Mode"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.indigo.shade700,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _startQuizMode,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Flashcards count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              children: [
                Text(
                  "My Flashcards",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        themeProvider.isDarkMode
                            ? Colors.purple.withOpacity(0.2)
                            : Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${_flashcards.length}",
                    style: TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Flashcards grid
          Expanded(child: _buildFlashcardsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purple,
        onPressed: _showAddFlashcardDialog,
        child: Icon(Icons.add),
        tooltip: 'Create New Flashcard',
      ),
    );
  }
}
