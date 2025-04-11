import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'theme_provider.dart';
import 'services/rewards_service.dart';

class DailyStudyGoalsScreen extends StatefulWidget {
  @override
  _DailyStudyGoalsScreenState createState() => _DailyStudyGoalsScreenState();
}

class _DailyStudyGoalsScreenState extends State<DailyStudyGoalsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Rewards service
  final RewardsService _rewardsService = RewardsService();

  // Controllers for new goal input
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  // Selected date range
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(Duration(days: 7));

  // Date formatting utility function
  String _formatDate(DateTime date) {
    final List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  // Selected time for reminder
  TimeOfDay _reminderTime = TimeOfDay(hour: 9, minute: 0);

  // Selected days for studying
  List<bool> _selectedDays = List.filled(7, true); // Default all days selected

  // Enable reminders
  bool _reminderEnabled = true;

  // Goals list and loading state
  List<Map<String, dynamic>> _goals = [];
  bool _isLoading = true;

  // Stream subscription
  StreamSubscription<QuerySnapshot>? _goalsSubscription;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  // Load study goals
  void _loadGoals() {
    try {
      // Cancel any existing subscription
      _goalsSubscription?.cancel();

      // Query that gets current user's study goals
      final goalsQuery = _firestore
          .collection('studyGoals')
          .where('userId', isEqualTo: _auth.currentUser?.uid);

      // Subscribe to query
      _goalsSubscription = goalsQuery.snapshots().listen(
        (snapshot) {
          if (mounted) {
            final goalDocs = snapshot.docs;
            final List<Map<String, dynamic>> goals = [];

            for (var doc in goalDocs) {
              final data = doc.data() as Map<String, dynamic>;
              goals.add({'id': doc.id, ...data});
            }

            // Sort by start date
            goals.sort((a, b) {
              final aDate = a['startDate'] as Timestamp?;
              final bDate = b['startDate'] as Timestamp?;

              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return 1;
              if (bDate == null) return -1;

              return aDate.compareTo(bDate);
            });

            setState(() {
              _goals = goals;
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          print('Error loading goals: $error');
          setState(() {
            _isLoading = false;
          });

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading study goals. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    } catch (e) {
      print('Error setting up goals listener: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Add a new goal
  Future<void> _addGoal() async {
    if (_goalController.text.trim().isEmpty ||
        _durationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter both a goal description and target study duration',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate duration input is a positive number
    int? duration = int.tryParse(_durationController.text.trim());
    if (duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid positive number for duration'),
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

        // Create days array for selected days
        List<String> selectedDays = [];
        List<String> dayNames = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];
        for (int i = 0; i < _selectedDays.length; i++) {
          if (_selectedDays[i]) {
            selectedDays.add(dayNames[i]);
          }
        }

        // Format reminder time
        String reminderTimeStr =
            '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}';

        await _firestore.collection('studyGoals').add({
          'description': _goalController.text.trim(),
          'duration': duration,
          'userId': user.uid,
          'startDate': Timestamp.fromDate(_startDate),
          'endDate': Timestamp.fromDate(_endDate),
          'selectedDays': selectedDays,
          'reminderEnabled': _reminderEnabled,
          'reminderTime': reminderTimeStr,
          'createdAt': FieldValue.serverTimestamp(),
          'completed': false,
        });

        _goalController.clear();
        _durationController.clear();

        // Schedule notification if reminder is enabled
        if (_reminderEnabled) {
          _scheduleReminder(
            _goalController.text.trim(),
            reminderTimeStr,
            selectedDays,
          );
        }

        // Goals will update automatically via listener
        setState(() {
          _isLoading = false;
        });

        // Hide goal form
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error adding goal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding goal: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Schedule a reminder notification
  void _scheduleReminder(String goalTitle, String time, List<String> days) {
    // Placeholder for notification scheduling
    // This would integrate with flutter_local_notifications or similar
    print('Scheduled reminder for: $goalTitle at $time on ${days.join(', ')}');

    // For actual implementation, this is where we would schedule local notifications
    // using a package like flutter_local_notifications
  }

  // Delete a goal
  Future<void> _deleteGoal(String goalId) async {
    try {
      await _firestore.collection('studyGoals').doc(goalId).delete();
      // Cancel any scheduled notifications for this goal
      // This would be implemented when a notification package is added
    } catch (e) {
      print('Error deleting goal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting goal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mark goal as completed/incomplete and update streak if needed
  Future<void> _toggleGoalCompletion(String goalId, bool currentStatus) async {
    try {
      final newStatus = !currentStatus;
      final userId = _auth.currentUser?.uid;

      if (userId == null) return;

      // Update the goal status
      await _firestore.collection('studyGoals').doc(goalId).update({
        'completed': newStatus,
        // Add completedAt timestamp when marking complete (for streak calculation)
        if (newStatus) 'completedAt': FieldValue.serverTimestamp(),
      });

      // If marking as complete, update streak and award XP
      if (newStatus) {
        await _updateStreak(userId);

        // Award XP for completing a daily goal
        int xpGained = await _rewardsService.awardDailyGoalXP();

        // Show XP notification
        _rewardsService.showXPNotification(context, xpGained);
      }
    } catch (e) {
      print('Error updating goal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating goal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Update the user's streak when a goal is completed
  Future<void> _updateStreak(String userId) async {
    try {
      // Get user document
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;

      // Get current streak and last update timestamp
      int currentStreak = userData['currentStreak'] ?? 0;
      Timestamp? lastStreakUpdate = userData['lastStreakUpdate'] as Timestamp?;

      // Get today's date at midnight for comparison
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int newStreak = 1; // Default to 1 for first time or reset
      bool streakIncreased = false;

      // If this is the first time updating streak or last update was before today
      if (lastStreakUpdate == null) {
        // First time ever completing a goal
        newStreak = 1;
        streakIncreased = true;
      } else {
        final lastUpdateDate = lastStreakUpdate.toDate();
        final lastUpdateDay = DateTime(
          lastUpdateDate.year,
          lastUpdateDate.month,
          lastUpdateDate.day,
        );

        if (lastUpdateDay.isBefore(today)) {
          // Check if the last update was yesterday (continuing streak)
          final yesterday = today.subtract(Duration(days: 1));
          final lastUpdateWasYesterday = lastUpdateDay.isAtSameMomentAs(
            yesterday,
          );

          if (lastUpdateWasYesterday) {
            // Continuing streak from yesterday
            newStreak = currentStreak + 1;
            streakIncreased = true;
          } else {
            // Last update was before yesterday, reset streak
            newStreak = 1; // Reset to 1 for today
            streakIncreased = false;
          }
        } else if (lastUpdateDay.isAtSameMomentAs(today)) {
          // Already updated streak today, don't increment again
          newStreak = currentStreak;
          streakIncreased = false;
        }
      }

      // Update the streak in Firestore
      await _firestore.collection('users').doc(userId).update({
        'currentStreak': newStreak,
        'lastStreakUpdate': FieldValue.serverTimestamp(),
      });

      // Check for consistency badges if streak increased
      if (streakIncreased) {
        await _rewardsService.checkConsistencyBadges(userId, newStreak);
      }

      // Show streak update notification
      _showStreakNotification();
    } catch (e) {
      print('Error updating streak: $e');
    }
  }

  // Show notification when streak is updated
  void _showStreakNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.local_fire_department, color: Colors.yellow),
            SizedBox(width: 12),
            Text('Goal completed! Your streak has been updated.'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Show dialog to add a new goal
  void _showAddGoalDialog() {
    // Reset input fields
    _goalController.clear();
    _durationController.clear();
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(Duration(days: 7));
    _reminderTime = TimeOfDay(hour: 9, minute: 0);
    _selectedDays = List.filled(7, true);
    _reminderEnabled = true;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text("Add New Study Goal"),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _goalController,
                          decoration: InputDecoration(
                            labelText: "Goal Description",
                            hintText: "What do you want to study?",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _durationController,
                          decoration: InputDecoration(
                            labelText: "Daily Target (minutes)",
                            hintText: "How many minutes per day?",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Date Range",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.calendar_today),
                                label: Text(_formatDate(_startDate)),
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _startDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(
                                      Duration(days: 365),
                                    ),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _startDate = date;
                                      // Ensure end date is not before start date
                                      if (_endDate.isBefore(_startDate)) {
                                        _endDate = _startDate.add(
                                          Duration(days: 1),
                                        );
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.calendar_today),
                                label: Text(_formatDate(_endDate)),
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _endDate,
                                    firstDate: _startDate,
                                    lastDate: DateTime.now().add(
                                      Duration(days: 365),
                                    ),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _endDate = date;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Study Days",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 6.0,
                          children: [
                            _buildDayChip(0, "M", setState),
                            _buildDayChip(1, "T", setState),
                            _buildDayChip(2, "W", setState),
                            _buildDayChip(3, "T", setState),
                            _buildDayChip(4, "F", setState),
                            _buildDayChip(5, "S", setState),
                            _buildDayChip(6, "S", setState),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Enable Reminders",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Switch(
                              value: _reminderEnabled,
                              activeColor: Colors.orangeAccent,
                              onChanged: (value) {
                                setState(() {
                                  _reminderEnabled = value;
                                });
                              },
                            ),
                          ],
                        ),
                        if (_reminderEnabled) ...[
                          SizedBox(height: 8),
                          Text(
                            "Reminder Time",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: Icon(Icons.access_time),
                            label: Text(_reminderTime.format(context)),
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _reminderTime,
                              );
                              if (time != null) {
                                setState(() {
                                  _reminderTime = time;
                                });
                              }
                            },
                          ),
                          SizedBox(height: 8),
                          Text(
                            "You'll receive a notification at this time on your selected study days.",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                      ),
                      onPressed: _addGoal,
                      child: Text("Add Goal"),
                    ),
                  ],
                ),
          ),
    );
  }

  // Build a selectable day chip
  Widget _buildDayChip(int index, String label, StateSetter setState) {
    return FilterChip(
      label: Text(label),
      selected: _selectedDays[index],
      selectedColor: Colors.orange[100],
      checkmarkColor: Colors.deepOrange,
      onSelected: (selected) {
        setState(() {
          _selectedDays[index] = selected;
        });
      },
    );
  }

  // Build the goals list
  Widget _buildGoalsList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_goals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 72, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No study goals yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Add your first study goal by tapping the + button below',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _goals.length,
      itemBuilder: (context, index) {
        final goal = _goals[index];
        final goalId = goal['id'];
        final isCompleted = goal['completed'] ?? false;

        // Format dates and time
        final startDate =
            (goal['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final endDate =
            (goal['endDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final dateRange = "${_formatDate(startDate)} - ${_formatDate(endDate)}";

        // Get selected days
        final selectedDays =
            (goal['selectedDays'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final daysString =
            selectedDays.isNotEmpty
                ? selectedDays.map((d) => d.substring(0, 3)).join(', ')
                : 'No days selected';

        return Card(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.all(16),
                leading: Checkbox(
                  value: isCompleted,
                  activeColor: Colors.orangeAccent,
                  onChanged:
                      (value) => _toggleGoalCompletion(goalId, isCompleted),
                ),
                title: Text(
                  goal['description'] ?? 'Untitled Goal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? Colors.grey : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.timer, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('${goal['duration'] ?? 0} minutes daily'),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey,
                        ),
                        SizedBox(width: 4),
                        Text(dateRange),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.repeat, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Expanded(child: Text(daysString)),
                      ],
                    ),
                    if (goal['reminderEnabled'] == true) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.notifications,
                            size: 16,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Reminder at ${goal['reminderTime'] ?? '09:00'}',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[300]),
                  onPressed: () => _deleteGoal(goalId),
                ),
              ),
              // Progress indicator
              if (!isCompleted) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: LinearProgressIndicator(
                    value: _calculateProgress(startDate, endDate),
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.orangeAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Calculate progress percentage based on date range
  double _calculateProgress(DateTime start, DateTime end) {
    final now = DateTime.now();

    // If it hasn't started yet
    if (now.isBefore(start)) return 0.0;

    // If it's already ended
    if (now.isAfter(end)) return 1.0;

    // Calculate progress
    final totalDays = end.difference(start).inDays;
    if (totalDays <= 0) return 1.0;

    final daysElapsed = now.difference(start).inDays;
    return daysElapsed / totalDays;
  }

  @override
  void dispose() {
    _goalsSubscription?.cancel();
    _goalController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Daily Study Goals"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadGoals,
            tooltip: "Refresh goals",
          ),
        ],
      ),
      body: Column(
        children: [
          // Header section with motivation
          Container(
            padding: EdgeInsets.all(16.0),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepOrange.shade700, Colors.orange.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Set Your Study Goals",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Track your daily study goals and get reminders to stay on track.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.add, size: 18),
                    label: Text("New Goal"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orange.shade800,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onPressed: _showAddGoalDialog,
                  ),
                ),
              ],
            ),
          ),

          // Study goals list header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              children: [
                Text(
                  "My Study Goals",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        themeProvider.isDarkMode
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${_goals.length}",
                    style: TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Goals list
          Expanded(child: _buildGoalsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGoalDialog,
        child: Icon(Icons.add),
        tooltip: 'Add New Study Goal',
      ),
    );
  }
}
