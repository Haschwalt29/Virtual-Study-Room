import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'theme_provider.dart';

class PomodoroTimerScreen extends StatefulWidget {
  @override
  _PomodoroTimerScreenState createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> {
  // Timer states
  static const STUDY = 'study';
  static const BREAK = 'break';

  // Timer variables
  bool _isTimerRunning = false;
  String _currentState = STUDY;
  int _studyDuration = 25 * 60; // Default 25 minutes in seconds
  int _breakDuration =
      5 * 60; // Default 5 minutes in seconds (calculated from study time)
  int _currentTime = 25 * 60;
  int _completedCycles = 0;
  Timer? _timer;

  // Slider values
  double _studyMinutes = 25;

  // Firebase services
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateBreakTime() {
    // Break time is study time divided by 3 (3:1 ratio)
    _breakDuration = (_studyDuration ~/ 3).clamp(
      1 * 60,
      20 * 60,
    ); // Min 1 min, max 20 min

    // Reset current time if timer is not running
    if (!_isTimerRunning) {
      _currentTime = _currentState == STUDY ? _studyDuration : _breakDuration;
    }
  }

  void _startTimer() {
    setState(() {
      _isTimerRunning = true;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_currentTime > 0) {
          _currentTime--;
        } else {
          // Timer completed
          _timer?.cancel();

          // Switch between study and break
          if (_currentState == STUDY) {
            // Study session completed, switch to break
            _currentState = BREAK;
            _currentTime = _breakDuration;
            _showStateChangeDialog(
              "Study Session Complete!",
              "Time for a break! Take ${_formatTime(_breakDuration)} to relax.",
            );
          } else {
            // Break completed, switch to study and increment cycle count
            _currentState = STUDY;
            _currentTime = _studyDuration;
            _completedCycles++;

            // Update completed cycles in Firestore
            _updateCompletedCycles();

            _showStateChangeDialog(
              "Break Complete!",
              "Ready to start another study session of ${_formatTime(_studyDuration)}?",
            );
          }

          // Auto-start the next timer
          _startTimer();
        }
      });
    });
  }

  // Update completed pomodoro cycles in Firestore
  Future<void> _updateCompletedCycles() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Get current cycle count from Firestore
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          int currentCycles = userData['completedPomodoroCycles'] ?? 0;

          // Increment cycles count
          await _firestore.collection('users').doc(user.uid).update({
            'completedPomodoroCycles': currentCycles + 1,
          });

          print('Updated completed pomodoro cycles in Firestore');
        }
      }
    } catch (e) {
      print('Error updating completed cycles: $e');
    }
  }

  void _pauseTimer() {
    setState(() {
      _isTimerRunning = false;
      _timer?.cancel();
    });
  }

  void _resetTimer() {
    setState(() {
      _isTimerRunning = false;
      _timer?.cancel();
      _currentTime = _currentState == STUDY ? _studyDuration : _breakDuration;
    });
  }

  void _resetAll() {
    setState(() {
      _isTimerRunning = false;
      _timer?.cancel();
      _currentState = STUDY;
      _currentTime = _studyDuration;
      _completedCycles = 0;
    });
  }

  @override
  void initState() {
    super.initState();
    _calculateBreakTime();
    // Load completed cycles from Firestore
    _loadCompletedCycles();
  }

  // Load completed cycles from Firestore
  Future<void> _loadCompletedCycles() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          setState(() {
            _completedCycles = userData['completedPomodoroCycles'] ?? 0;
          });
        }
      }
    } catch (e) {
      print('Error loading completed cycles: $e');
    }
  }

  void _showStateChangeDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          ),
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // Get the primary and surface colors from the theme
    final primaryColor = Theme.of(context).primaryColor;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    // Define adaptive colors based on the current timer state and theme
    final stateColor =
        _currentState == STUDY ? Colors.orangeAccent : Colors.greenAccent;
    final stateTextColor =
        _currentState == STUDY ? Colors.deepOrange : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: Text("Pomodoro Timer"),
        backgroundColor: stateColor,
      ),
      body: Container(
        color:
            isDarkMode
                ? (_currentState == STUDY
                    ? Colors.orange.withOpacity(0.05).withAlpha(10)
                    : Colors.green.withOpacity(0.05).withAlpha(10))
                : (_currentState == STUDY
                    ? Colors.orange.withOpacity(0.05)
                    : Colors.green.withOpacity(0.05)),
        child: Column(
          children: [
            // Timer display
            Expanded(
              flex: 3,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Current state indicator
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode
                                ? (_currentState == STUDY
                                    ? Colors.orange
                                        .withOpacity(0.2)
                                        .withAlpha(40)
                                    : Colors.green
                                        .withOpacity(0.2)
                                        .withAlpha(40))
                                : (_currentState == STUDY
                                    ? Colors.orange.withOpacity(0.2)
                                    : Colors.green.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _currentState == STUDY ? "STUDY TIME" : "BREAK TIME",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: stateTextColor,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Timer display
                    Text(
                      _formatTime(_currentTime),
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        color: stateTextColor,
                      ),
                    ),

                    SizedBox(height: 24),

                    // Timer controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(
                            _isTimerRunning ? Icons.pause : Icons.play_arrow,
                          ),
                          label: Text(_isTimerRunning ? "Pause" : "Start"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: stateColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed:
                              _isTimerRunning ? _pauseTimer : _startTimer,
                        ),
                        SizedBox(width: 16),
                        ElevatedButton.icon(
                          icon: Icon(Icons.refresh),
                          label: Text("Reset"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDarkMode
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                            foregroundColor:
                                isDarkMode ? Colors.white : Colors.black87,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _resetTimer,
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Completed cycles
                    Text(
                      "Completed Cycles: $_completedCycles",
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Divider
            Divider(thickness: 1),

            // Timer settings
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Timer Settings",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Study time slider
                    Row(
                      children: [
                        Text(
                          "Study Time: ",
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                          ),
                        ),
                        Text(
                          "${_studyMinutes.toInt()} min",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _studyMinutes,
                      min: 5,
                      max: 60,
                      divisions: 11,
                      activeColor: Colors.orangeAccent,
                      label: "${_studyMinutes.toInt()} min",
                      onChanged: (value) {
                        setState(() {
                          _studyMinutes = value;
                          _studyDuration = value.toInt() * 60;
                          _calculateBreakTime();
                        });
                      },
                    ),

                    // Break time (calculated automatically)
                    Row(
                      children: [
                        Text(
                          "Break Time: ",
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                          ),
                        ),
                        Text(
                          "${(_breakDuration ~/ 60)} min",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          " (auto-calculated as 1/3 of study time)",
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color:
                                isDarkMode
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Apply settings button
                    Center(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text("Reset All"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDarkMode ? Colors.red[900] : Colors.red[100],
                          foregroundColor:
                              isDarkMode ? Colors.white : Colors.red[900],
                        ),
                        onPressed: _resetAll,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
