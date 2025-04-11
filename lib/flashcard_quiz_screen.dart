import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'theme_provider.dart';

class FlashcardQuizScreen extends StatefulWidget {
  final List<Map<String, dynamic>> flashcards;

  const FlashcardQuizScreen({Key? key, required this.flashcards})
    : super(key: key);

  @override
  _FlashcardQuizScreenState createState() => _FlashcardQuizScreenState();
}

class _FlashcardQuizScreenState extends State<FlashcardQuizScreen>
    with SingleTickerProviderStateMixin {
  // Quiz state
  int _currentIndex = 0;
  bool _isShowingAnswer = false;
  List<Map<String, dynamic>> _quizFlashcards = [];
  List<bool> _correctAnswers = [];
  int _correctCount = 0;
  bool _quizCompleted = false;
  int _remainingCards = 0;

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _flipAnimation;
  bool _isFlipping = false;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animationController.addListener(() {
      if (_animationController.value > 0.5 && !_isShowingAnswer) {
        setState(() {
          _isShowingAnswer = true;
        });
      } else if (_animationController.value < 0.5 && _isShowingAnswer) {
        setState(() {
          _isShowingAnswer = false;
        });
      }
    });

    // Setup quiz
    _setupQuiz();
  }

  void _setupQuiz() {
    try {
      // Create a copy of flashcards and validate data
      final validFlashcards =
          widget.flashcards.where((card) {
            // Ensure each flashcard has question and answer fields
            return card.containsKey('question') &&
                card.containsKey('answer') &&
                card['question'] != null &&
                card['answer'] != null;
          }).toList();

      setState(() {
        _quizFlashcards = List.from(validFlashcards);
        // Only shuffle if there are flashcards
        if (_quizFlashcards.isNotEmpty) {
          _quizFlashcards.shuffle(Random());
        }
        _correctAnswers = List.filled(_quizFlashcards.length, false);
        _currentIndex = 0;
        _isShowingAnswer = false;
        _correctCount = 0;
        _quizCompleted = false;
        _remainingCards = _quizFlashcards.length;
      });
    } catch (e) {
      print('Error setting up quiz: $e');
      setState(() {
        _quizFlashcards = [];
        _quizCompleted = true;
      });

      // Show error message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error setting up quiz: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      });
    }
  }

  void _flipCard() {
    if (_isFlipping) return;

    setState(() {
      _isFlipping = true;
    });

    if (_animationController.value == 0) {
      _animationController.forward().then((_) {
        setState(() {
          _isFlipping = false;
        });
      });
    } else {
      _animationController.reverse().then((_) {
        setState(() {
          _isFlipping = false;
        });
      });
    }
  }

  void _markAnswer(bool correct) {
    if (_currentIndex >= 0 && _currentIndex < _correctAnswers.length) {
      // Show visual feedback
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            correct ? 'Great job!' : 'Keep studying, you\'ll get it next time!',
          ),
          backgroundColor: correct ? Colors.green : Colors.orange,
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _correctAnswers[_currentIndex] = correct;
        if (correct) {
          _correctCount++;
        }
      });

      // Wait for animation before moving to next card
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          _nextCard();
        }
      });
    }
  }

  void _nextCard() {
    // Reset card flip
    if (_animationController.value > 0) {
      _animationController.reverse();
    }

    // Move to next card or end quiz
    setState(() {
      if (_currentIndex < _quizFlashcards.length - 1) {
        _currentIndex++;
        _isShowingAnswer = false;
        _remainingCards = _quizFlashcards.length - _currentIndex;
      } else {
        _quizCompleted = true;
      }
    });
  }

  void _resetQuiz() {
    _setupQuiz();
    setState(() {
      _quizCompleted = false;
      if (_animationController.value > 0) {
        _animationController.reverse();
      }
    });
  }

  // Get color based on flashcard data
  Color _getCardColor(Map<String, dynamic> flashcard) {
    try {
      return Color(flashcard['color'] ?? Colors.blue.value);
    } catch (e) {
      return Colors.blue;
    }
  }

  // Get text style from flashcard data
  TextStyle _getCardTextStyle(Map<String, dynamic> flashcard) {
    double fontSize;
    String fontFamily;
    FontWeight fontWeight;

    try {
      fontSize = flashcard['fontSize'] ?? 18.0;
      fontFamily = flashcard['fontFamily'] ?? 'Roboto';

      List<FontWeight> weights = [
        FontWeight.normal,
        FontWeight.bold,
        FontWeight.w200,
        FontWeight.w500,
        FontWeight.w800,
      ];

      int fontWeightIndex = flashcard['fontWeight'] ?? 0;
      if (fontWeightIndex >= 0 && fontWeightIndex < weights.length) {
        fontWeight = weights[fontWeightIndex];
      } else {
        fontWeight = FontWeight.normal;
      }
    } catch (e) {
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

  // Get text alignment from flashcard data
  TextAlign _getCardTextAlign(Map<String, dynamic> flashcard) {
    try {
      List<TextAlign> alignments = [
        TextAlign.center,
        TextAlign.left,
        TextAlign.right,
      ];

      int textAlignIndex = flashcard['textAlign'] ?? 0;
      if (textAlignIndex >= 0 && textAlignIndex < alignments.length) {
        return alignments[textAlignIndex];
      }
    } catch (e) {
      // Fallback
    }
    return TextAlign.center;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Check if we have flashcards and if we're at a valid index
    if (_quizFlashcards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("Quiz Mode")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 72, color: Colors.orange),
              SizedBox(height: 16),
              Text("No flashcards available", style: TextStyle(fontSize: 18)),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Return to Flashcards"),
              ),
            ],
          ),
        ),
      );
    }

    // Show completion screen
    if (_quizCompleted) {
      final percentage = (_correctCount / _quizFlashcards.length) * 100;
      return Scaffold(
        appBar: AppBar(title: Text("Quiz Results")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                percentage >= 70 ? Icons.emoji_events : Icons.school,
                size: 80,
                color: percentage >= 70 ? Colors.amber : Colors.blueGrey,
              ),
              SizedBox(height: 24),
              Text(
                "Quiz Completed!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "You answered $_correctCount out of ${_quizFlashcards.length} correctly",
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 16),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      themeProvider.isDarkMode
                          ? Colors.grey[800]
                          : Colors.grey[200],
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: _correctCount / _quizFlashcards.length,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percentage >= 70
                                ? Colors.green
                                : percentage >= 50
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ),
                      ),
                      Text(
                        "${percentage.toStringAsFixed(0)}%",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.replay),
                    label: Text("Try Again"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _resetQuiz,
                  ),
                  SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: Icon(Icons.arrow_back),
                    label: Text("Return"),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Quiz in progress
    final currentFlashcard = _quizFlashcards[_currentIndex];
    final cardColor = _getCardColor(currentFlashcard);
    final textStyle = _getCardTextStyle(currentFlashcard);
    final textAlign = _getCardTextAlign(currentFlashcard);

    return Scaffold(
      appBar: AppBar(
        title: Text("Quiz Mode"),
        actions: [
          // Shuffle button
          IconButton(
            icon: Icon(Icons.shuffle),
            tooltip: "Shuffle Cards",
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text("Shuffle Cards"),
                      content: Text(
                        "Would you like to shuffle the remaining cards?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);

                            // Shuffle remaining cards
                            if (_currentIndex < _quizFlashcards.length - 1) {
                              setState(() {
                                final completedCards = _quizFlashcards.sublist(
                                  0,
                                  _currentIndex + 1,
                                );
                                final remainingCards = _quizFlashcards.sublist(
                                  _currentIndex + 1,
                                );
                                remainingCards.shuffle(Random());
                                _quizFlashcards = [
                                  ...completedCards,
                                  ...remainingCards,
                                ];
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Remaining cards shuffled"),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          child: Text("Shuffle"),
                        ),
                      ],
                    ),
              );
            },
          ),

          // Card counter
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                "Card ${_currentIndex + 1}/${_quizFlashcards.length}",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_currentIndex) / _quizFlashcards.length,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
            minHeight: 8,
          ),

          // Quiz stats
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(
                  icon: Icons.check_circle,
                  value: _correctCount.toString(),
                  label: "Correct",
                  color: Colors.green,
                ),
                _buildStatCard(
                  icon: Icons.pending,
                  value: _remainingCards.toString(),
                  label: "Remaining",
                  color: Colors.orange,
                ),
                _buildStatCard(
                  icon: Icons.question_mark,
                  value: (_currentIndex - _correctCount).toString(),
                  label: "Missed",
                  color: Colors.red,
                ),
              ],
            ),
          ),

          // Flashcard display
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: GestureDetector(
                onTap: _flipCard,
                child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final isAltSide = _flipAnimation.value >= 0.5;
                    final transform =
                        Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(pi * _flipAnimation.value);

                    return Transform(
                      transform: transform,
                      alignment: Alignment.center,
                      child:
                          isAltSide
                              ? Transform(
                                transform: Matrix4.identity()..rotateY(pi),
                                alignment: Alignment.center,
                                child: _buildAnswerCard(
                                  currentFlashcard,
                                  cardColor,
                                  textStyle,
                                  textAlign,
                                ),
                              )
                              : _buildQuestionCard(
                                currentFlashcard,
                                cardColor,
                                textStyle,
                                textAlign,
                              ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Instructions
          if (!_isShowingAnswer)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Tap the card to see the answer",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Did you know the answer?",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

          // Action buttons
          if (_isShowingAnswer)
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.close),
                    label: Text("I Didn't Know"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => _markAnswer(false),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.check),
                    label: Text("I Knew It!"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => _markAnswer(true),
                  ),
                ],
              ),
            )
          else
            SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    Map<String, dynamic> flashcard,
    Color cardColor,
    TextStyle textStyle,
    TextAlign textAlign,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.lightbulb_outline, color: Colors.white, size: 32),
          ),
          SizedBox(height: 24),
          Text(
            "Question",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            flashcard['question'] ?? "No question provided",
            style: textStyle,
            textAlign: textAlign,
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(
    Map<String, dynamic> flashcard,
    Color cardColor,
    TextStyle textStyle,
    TextAlign textAlign,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor.withAlpha(220),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.school, color: Colors.white, size: 32),
          ),
          SizedBox(height: 24),
          Text(
            "Answer",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            flashcard['answer'] ?? "No answer provided",
            style: textStyle,
            textAlign: textAlign,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();

    // Clean up any possible SnackBars
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });

    super.dispose();
  }
}
