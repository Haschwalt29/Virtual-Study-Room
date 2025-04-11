import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'services/ai_service.dart';
import 'theme_provider.dart';

class AIFlashcardGeneratorScreen extends StatefulWidget {
  @override
  _AIFlashcardGeneratorScreenState createState() =>
      _AIFlashcardGeneratorScreenState();
}

class _AIFlashcardGeneratorScreenState
    extends State<AIFlashcardGeneratorScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _textController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generated flashcards
  List<Map<String, dynamic>> _generatedFlashcards = [];
  Set<int> _selectedFlashcards = {};

  // State flags
  bool _isGenerating = false;
  bool _hasGenerated = false;
  bool _isSaving = false;

  // Feedback messages
  String _feedbackMessage = '';

  // Max input limit
  final int _maxInputLength = 5000;

  // Example prompts
  final List<String> _examplePrompts = [
    'The water cycle is the continuous movement of water within the Earth and atmosphere. It includes processes like evaporation, condensation, precipitation, and collection. Evaporation occurs when the sun heats up water in rivers or lakes and turns it into vapor. Condensation happens when water vapor in the air gets cold and changes back into liquid, forming clouds. Precipitation occurs when water falls from clouds as rain, snow, sleet, or hail. Collection refers to when water that falls from the clouds as rain, snow, etc., collects in oceans, rivers, lakes, or seeps into the ground.',
    'The three branches of the U.S. government are Legislative, Executive, and Judicial. The Legislative branch makes laws and consists of Congress (the Senate and House of Representatives). The Executive branch carries out laws and is headed by the President. The Judicial branch evaluates laws and consists of the Supreme Court and other federal courts. What is the system of checks and balances? The system of checks and balances prevents any one branch from becoming too powerful by giving each branch the ability to limit powers of the others.',
    'Photosynthesis is the process by which green plants and some other organisms use sunlight to synthesize foods with carbon dioxide and water. Photosynthesis in plants generally involves the green pigment chlorophyll and generates oxygen as a byproduct. The chemical equation for photosynthesis is: 6CO₂ + 6H₂O + light energy → C₆H₁₂O₆ + 6O₂. Plants absorb light primarily using the pigment chlorophyll, which gives plants their green color and is crucial for photosynthesis to occur.',
  ];

  // Input error text
  String? get _inputErrorText {
    final text = _textController.text;
    if (text.isEmpty) {
      return null;
    }
    if (text.length > _maxInputLength) {
      return 'Text exceeds maximum length of $_maxInputLength characters';
    }
    return null;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // Load example text
  void _loadExampleText(int index) {
    if (index >= 0 && index < _examplePrompts.length) {
      setState(() {
        _textController.text = _examplePrompts[index];
      });
    }
  }

  // Clear input text
  void _clearText() {
    setState(() {
      _textController.clear();
      _feedbackMessage = '';
    });
  }

  // Generate flashcards from text input
  Future<void> _generateFlashcards() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _feedbackMessage = 'Please enter some text to generate flashcards';
      });
      return;
    }

    if (text.length > _maxInputLength) {
      setState(() {
        _feedbackMessage =
            'Text too long. Please reduce to $_maxInputLength characters or less';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _feedbackMessage = '';
    });

    try {
      // Use the AI service to generate flashcards
      final flashcards = await AIService.generateFlashcardsFromText(text);

      setState(() {
        _generatedFlashcards = flashcards;
        _selectedFlashcards = Set<int>.from(
          List<int>.generate(flashcards.length, (index) => index),
        ); // Select all by default
        _isGenerating = false;
        _hasGenerated = true;
      });

      if (flashcards.isEmpty) {
        setState(() {
          _feedbackMessage =
              'Could not generate flashcards. Try using more detailed text with clear facts or definitions.';
        });
      }
    } catch (e) {
      print('Error generating flashcards: $e');
      setState(() {
        _isGenerating = false;
        _feedbackMessage = 'Error generating flashcards: $e';
      });
    }
  }

  // Toggle selection of a flashcard
  void _toggleFlashcardSelection(int index) {
    setState(() {
      if (_selectedFlashcards.contains(index)) {
        _selectedFlashcards.remove(index);
      } else {
        _selectedFlashcards.add(index);
      }
    });
  }

  // Select or deselect all flashcards
  void _toggleSelectAll() {
    setState(() {
      if (_selectedFlashcards.length == _generatedFlashcards.length) {
        // If all are selected, deselect all
        _selectedFlashcards.clear();
      } else {
        // Otherwise select all
        _selectedFlashcards = Set<int>.from(
          List<int>.generate(_generatedFlashcards.length, (index) => index),
        );
      }
    });
  }

  // Save selected flashcards to Firestore
  Future<void> _saveSelectedFlashcards() async {
    if (_selectedFlashcards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one flashcard to save'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        final batch = _firestore.batch();

        // For each selected flashcard
        for (int index in _selectedFlashcards) {
          if (index >= 0 && index < _generatedFlashcards.length) {
            final flashcard = _generatedFlashcards[index];
            // Create a new document reference
            final docRef = _firestore.collection('flashcards').doc();
            // Add to batch
            batch.set(docRef, {
              'question': flashcard['question'],
              'answer': flashcard['answer'],
              'userId': user.uid,
              'createdAt': FieldValue.serverTimestamp(),
              'color': flashcard['color'],
              'fontSize': flashcard['fontSize'],
              'fontFamily': flashcard['fontFamily'],
              'fontWeight': flashcard['fontWeight'],
              'textAlign': flashcard['textAlign'],
              'createdByAI': true,
            });
          }
        }

        // Commit the batch
        await batch.commit();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully saved ${_selectedFlashcards.length} flashcards'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear selections
        setState(() {
          _selectedFlashcards.clear();
        });
      }
    } catch (e) {
      print('Error saving flashcards: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving flashcards: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Edit a flashcard
  void _editFlashcard(int index) {
    if (index < 0 || index >= _generatedFlashcards.length) return;

    final flashcard = _generatedFlashcards[index];
    final TextEditingController questionController =
        TextEditingController(text: flashcard['question']);
    final TextEditingController answerController =
        TextEditingController(text: flashcard['answer']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Flashcard'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                decoration: InputDecoration(
                  labelText: 'Question',
                  hintText: 'Enter the question',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              TextField(
                controller: answerController,
                decoration: InputDecoration(
                  labelText: 'Answer',
                  hintText: 'Enter the answer',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
            ),
            onPressed: () {
              // Update the flashcard
              setState(() {
                _generatedFlashcards[index] = {
                  ..._generatedFlashcards[index],
                  'question': questionController.text,
                  'answer': answerController.text,
                };
              });
              Navigator.pop(context);
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  // Delete a flashcard
  void _deleteFlashcard(int index) {
    if (index < 0 || index >= _generatedFlashcards.length) return;

    setState(() {
      _selectedFlashcards.remove(index);
      _generatedFlashcards.removeAt(index);
      
      // Update selected indices if necessary
      final newSelected = Set<int>();
      for (var selectedIndex in _selectedFlashcards) {
        if (selectedIndex > index) {
          newSelected.add(selectedIndex - 1);
        } else {
          newSelected.add(selectedIndex);
        }
      }
      _selectedFlashcards = newSelected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("AI Flashcard Generator"),
        actions: [
          if (_hasGenerated && _generatedFlashcards.isNotEmpty)
            IconButton(
              icon: Icon(Icons.save),
              tooltip: "Save Selected Flashcards",
              onPressed: _isSaving ? null : _saveSelectedFlashcards,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Container(
                padding: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology, color: Colors.purple),
                        SizedBox(width: 8),
                        Text(
                          "AI-Powered Flashcard Creator",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Paste your study notes, textbook excerpts, or any educational content below. Our AI will analyze the text and create flashcards automatically.",
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Example buttons
              Text(
                "Quick Examples:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.water_drop),
                      label: Text("Water Cycle"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      onPressed: () => _loadExampleText(0),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: Icon(Icons.account_balance),
                      label: Text("Government"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                      ),
                      onPressed: () => _loadExampleText(1),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: Icon(Icons.eco),
                      label: Text("Photosynthesis"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () => _loadExampleText(2),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Text input area
              TextField(
                controller: _textController,
                decoration: InputDecoration(
                  labelText: "Enter Study Text",
                  hintText:
                      "Paste your notes, textbook content, or any educational material here...",
                  errorText: _inputErrorText,
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: _clearText,
                    tooltip: "Clear text",
                  ),
                  helperText:
                      "Maximum ${_maxInputLength} characters (${_textController.text.length}/${_maxInputLength})",
                ),
                maxLines: 10,
                onChanged: (text) {
                  // Force a rebuild to update character count
                  setState(() {});
                },
              ),
              SizedBox(height: 16),

              // Generate button
              Center(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.auto_awesome),
                  label: Text("Generate Flashcards"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding:
                        EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                  onPressed:
                      _isGenerating ? null : _generateFlashcards,
                ),
              ),

              // Loading indicator or feedback message
              if (_isGenerating)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "Analyzing text and generating flashcards...",
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_feedbackMessage.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _feedbackMessage,
                            style: TextStyle(color: Colors.orange[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Generated flashcards
              if (_hasGenerated && _generatedFlashcards.isNotEmpty) ...[
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Generated Flashcards",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${_generatedFlashcards.length}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Select all checkbox
                    Row(
                      children: [
                        Text("Select All"),
                        Checkbox(
                          value: _selectedFlashcards.length ==
                              _generatedFlashcards.length,
                          onChanged: (bool? value) {
                            _toggleSelectAll();
                          },
                          activeColor: Colors.purple,
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  "Review and customize these flashcards before saving them to your collection.",
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                SizedBox(height: 16),
                
                // Flashcards list
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _generatedFlashcards.length,
                  itemBuilder: (context, index) {
                    final flashcard = _generatedFlashcards[index];
                    final isSelected = _selectedFlashcards.contains(index);
                    final cardColor = Color(flashcard['color']);
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 16),
                      elevation: isSelected ? 4 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.purple
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _toggleFlashcardSelection(index),
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          children: [
                            // Card header with color bar
                            Container(
                              height: 24,
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                ),
                              ),
                            ),
                            
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Selection checkbox
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (bool? value) {
                                          _toggleFlashcardSelection(index);
                                        },
                                        activeColor: Colors.purple,
                                      ),
                                      Text(
                                        "Select for saving",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      Spacer(),
                                      // Edit button
                                      IconButton(
                                        icon: Icon(Icons.edit,
                                            color: Colors.blue),
                                        onPressed: () => _editFlashcard(index),
                                        tooltip: "Edit",
                                        iconSize: 20,
                                      ),
                                      // Delete button
                                      IconButton(
                                        icon: Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _deleteFlashcard(index),
                                        tooltip: "Delete",
                                        iconSize: 20,
                                      ),
                                    ],
                                  ),
                                  Divider(),
                                  SizedBox(height: 8),
                                  
                                  // Question
                                  Text(
                                    "Question:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    flashcard['question'] ?? "No question",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  
                                  // Answer
                                  Text(
                                    "Answer:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    flashcard['answer'] ?? "No answer",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                // Save button
                if (_generatedFlashcards.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.save),
                        label: Text(
                          "Save ${_selectedFlashcards.length} Selected Flashcards",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _selectedFlashcards.isEmpty || _isSaving
                            ? null
                            : _saveSelectedFlashcards,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}