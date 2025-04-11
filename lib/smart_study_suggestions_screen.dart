import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'services/ai_service.dart';
import 'theme_provider.dart';

class SmartStudySuggestionsScreen extends StatefulWidget {
  @override
  _SmartStudySuggestionsScreenState createState() =>
      _SmartStudySuggestionsScreenState();
}

class _SmartStudySuggestionsScreenState
    extends State<SmartStudySuggestionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  Map<String, dynamic> _suggestions = {};
  List<Map<String, dynamic>> _studyHistory = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadStudyHistory();
  }

  // Load user's study history from Firestore
  Future<void> _loadStudyHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // In a real app, this would fetch actual study session data
      // For this demo, we'll use a simulated dataset

      // Create simulated study history based on timestamps and performance
      final studyHistory = _generateSimulatedStudyHistory();

      setState(() {
        _studyHistory = studyHistory;
      });

      // Generate smart suggestions from study history
      await _generateSmartSuggestions();
    } catch (e) {
      print('Error loading study history: $e');
      setState(() {
        _errorMessage = 'Error loading study data: $e';
        _isLoading = false;
      });
    }
  }

  // Generate simulated study history data for demonstration
  List<Map<String, dynamic>> _generateSimulatedStudyHistory() {
    final random = Random();
    final List<Map<String, dynamic>> history = [];

    // Generate 4 weeks of simulated study sessions
    final now = DateTime.now();
    for (int i = 28; i >= 0; i--) {
      // Add 1-3 study sessions per day
      final sessionCount = random.nextInt(3) + 1;

      for (int j = 0; j < sessionCount; j++) {
        final sessionDate = now.subtract(Duration(days: i));

        // Generate random hour (between 6am and 11pm)
        final hour = 6 + random.nextInt(17);
        final minute = random.nextInt(60);

        final sessionStartTime = DateTime(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
          hour,
          minute,
        );

        // Session duration between 15-120 minutes
        final durationMinutes = 15 + random.nextInt(105);
        final sessionEndTime = sessionStartTime.add(
          Duration(minutes: durationMinutes),
        );

        // Performance score (higher in morning/evening, lower in afternoon)
        double performanceScore;
        if (hour < 11) {
          performanceScore = 0.7 + random.nextDouble() * 0.3; // Morning (high)
        } else if (hour < 15) {
          performanceScore = 0.4 + random.nextDouble() * 0.3; // Afternoon (low)
        } else if (hour < 19) {
          performanceScore =
              0.6 + random.nextDouble() * 0.3; // Evening (medium-high)
        } else {
          performanceScore = 0.5 + random.nextDouble() * 0.4; // Night (medium)
        }

        // Adjust for weekday (lower on weekends)
        if (sessionDate.weekday == DateTime.saturday ||
            sessionDate.weekday == DateTime.sunday) {
          performanceScore *= 0.85;
        }

        history.add({
          'startTime': sessionStartTime,
          'endTime': sessionEndTime,
          'durationMinutes': durationMinutes,
          'performanceScore': performanceScore,
          'correctAnswers': (performanceScore * 10).round(),
          'totalQuestions': 10,
          'topicId': random.nextInt(5),
          'dayOfWeek': _getDayOfWeekName(sessionDate.weekday),
          'timeSlot': _getTimeSlotForHour(hour),
        });
      }
    }

    return history;
  }

  // Helper function to get day name from weekday
  String _getDayOfWeekName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  // Helper function to get timeSlot from hour
  String _getTimeSlotForHour(int hour) {
    if (hour >= 6 && hour < 8) return '06:00-08:00';
    if (hour >= 8 && hour < 10) return '08:00-10:00';
    if (hour >= 10 && hour < 12) return '10:00-12:00';
    if (hour >= 12 && hour < 14) return '12:00-14:00';
    if (hour >= 14 && hour < 16) return '14:00-16:00';
    if (hour >= 16 && hour < 18) return '16:00-18:00';
    if (hour >= 18 && hour < 20) return '18:00-20:00';
    if (hour >= 20 && hour < 22) return '20:00-22:00';
    return '22:00-00:00';
  }

  // Generate smart study suggestions based on history
  Future<void> _generateSmartSuggestions() async {
    try {
      final suggestions = await AIService.generateSmartStudySuggestions(
        _studyHistory,
      );

      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error generating study suggestions: $e');
      setState(() {
        _errorMessage = 'Error generating study suggestions: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text("Smart Study Suggestions"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: "Refresh Analysis",
            onPressed: _loadStudyHistory,
          ),
        ],
      ),
      body:
          _isLoading
              ? _buildLoadingView()
              : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _buildSuggestionsView(isDarkMode),
    );
  }

  // Loading view
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            "Analyzing your study patterns...",
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            "Our AI is finding your optimal study times",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // Error view
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red),
            SizedBox(height: 16),
            Text(
              "Unable to Generate Suggestions",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text("Try Again"),
              onPressed: _loadStudyHistory,
            ),
          ],
        ),
      ),
    );
  }

  // Main suggestions view
  Widget _buildSuggestionsView(bool isDarkMode) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.teal.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        "AI Study Pattern Analysis",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Based on your ${_studyHistory.length} study sessions, our AI has identified your optimal study patterns.",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Personalized tip section
            if (_suggestions.containsKey('personalizedTip') &&
                _suggestions['personalizedTip'] != null) ...[
              _buildSectionHeader(
                "Personalized Recommendation",
                Icons.tips_and_updates,
                Colors.amber,
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _suggestions['personalizedTip'],
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildRecommendationItem(
                      "Recommended Session Length",
                      "${_suggestions['recommendedSessionLength']} minutes",
                      Icons.timer,
                      Colors.blue,
                    ),
                    SizedBox(height: 8),
                    _buildRecommendationItem(
                      "Daily Study Target",
                      "${_suggestions['recommendedTotalHours']} hours",
                      Icons.schedule,
                      Colors.green,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
            ],

            // Best times section
            if (_suggestions.containsKey('bestTimes') &&
                _suggestions['bestTimes'] is List &&
                _suggestions['bestTimes'].isNotEmpty) ...[
              _buildSectionHeader(
                "Your Best Study Times",
                Icons.star,
                Colors.orange,
              ),
              SizedBox(height: 8),
              ..._buildTimeSlotCards(
                _suggestions['bestTimes'],
                true,
                isDarkMode,
              ),
              SizedBox(height: 24),
            ],

            // Worst times section
            if (_suggestions.containsKey('worstTimes') &&
                _suggestions['worstTimes'] is List &&
                _suggestions['worstTimes'].isNotEmpty) ...[
              _buildSectionHeader(
                "Times to Avoid",
                Icons.do_not_disturb,
                Colors.red,
              ),
              SizedBox(height: 8),
              ..._buildTimeSlotCards(
                _suggestions['worstTimes'],
                false,
                isDarkMode,
              ),
              SizedBox(height: 24),
            ],

            // Weekday analysis
            if (_suggestions.containsKey('weekdayAnalysis') &&
                _suggestions['weekdayAnalysis'] is Map &&
                _suggestions['weekdayAnalysis'].isNotEmpty) ...[
              _buildSectionHeader(
                "Performance by Day of Week",
                Icons.calendar_today,
                Colors.purple,
              ),
              SizedBox(height: 16),
              Container(
                height: 250,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildWeekdayChart(
                  _suggestions['weekdayAnalysis'],
                  isDarkMode,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "The chart shows your study effectiveness on different days. Higher values indicate better performance.",
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 30),
            ],

            // Disclaimer
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDarkMode
                        ? Colors.grey.shade800.withOpacity(0.5)
                        : Colors.grey.shade200.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "About These Suggestions",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "These AI-generated recommendations are based on your study history and performance patterns. The more you use the app, the more accurate the suggestions will become. Everyone's optimal study times are different - find what works best for you!",
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build section header with icon and title
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Build time slot cards
  List<Widget> _buildTimeSlotCards(
    List<dynamic> timeslots,
    bool isGood,
    bool isDarkMode,
  ) {
    return timeslots.map<Widget>((slot) {
      final timeSlot = slot['timeSlot'] as String;
      final effectiveness = slot['effectiveness'] as double;
      final reason = slot['reason'] as String;

      return Card(
        margin: EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    timeSlot,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  _buildEffectivenessIndicator(effectiveness, isGood),
                ],
              ),
              SizedBox(height: 8),
              Text(reason, style: TextStyle(fontSize: 14)),
              SizedBox(height: 16),
              LinearProgressIndicator(
                value: effectiveness,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isGood
                      ? _getColorForEffectiveness(effectiveness)
                      : Colors.red.withOpacity(0.7),
                ),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "${(effectiveness * 100).toStringAsFixed(0)}% effective",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color:
                        isGood
                            ? _getColorForEffectiveness(effectiveness)
                            : Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  // Build a recommendation item with icon and text
  Widget _buildRecommendationItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(width: 8),
        Text("$label: ", style: TextStyle(fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // Build effectiveness indicator (good/bad)
  Widget _buildEffectivenessIndicator(double effectiveness, bool isGood) {
    final color =
        isGood ? _getColorForEffectiveness(effectiveness) : Colors.red;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGood ? Icons.thumb_up : Icons.thumb_down,
            color: color,
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            isGood ? "Recommended" : "Avoid",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Get color based on effectiveness score
  Color _getColorForEffectiveness(double effectiveness) {
    if (effectiveness >= 0.8) return Colors.green;
    if (effectiveness >= 0.6) return Colors.lightGreen;
    if (effectiveness >= 0.4) return Colors.orange;
    return Colors.red;
  }

  // Build weekday chart visualization
  Widget _buildWeekdayChart(Map<String, dynamic> dayData, bool isDarkMode) {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children:
          days.map((day) {
            final value = dayData[day] ?? 0.0;
            final barHeight = (180 * value).toDouble();
            final color = _getColorForEffectiveness(value);

            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Bar value
                Text(
                  "${(value * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                SizedBox(height: 4),
                // Actual bar
                AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  width: 25,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.7),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                // Day label
                Text(
                  day.substring(0, 3), // Mon, Tue, etc.
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }
}
