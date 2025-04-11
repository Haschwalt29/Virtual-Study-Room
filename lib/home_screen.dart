import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'study_room_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'pomodoro_timer_screen.dart';
import 'login_screen.dart';
import 'theme_provider.dart';
import 'task_list_screen.dart';
import 'daily_study_goals_screen.dart';
import 'flashcards_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream for study rooms
  late Stream<QuerySnapshot> _studyRoomsStream;

  // User stats
  Map<String, dynamic> _userStats = {};
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    // Initialize the stream to get study rooms from Firestore
    _studyRoomsStream =
        _firestore
            .collection('studyRooms')
            .orderBy('createdAt', descending: true)
            .snapshots();

    // Load user stats
    _loadUserStats();
  }

  // Load user statistics from Firestore with updated metrics tracking
  Future<void> _loadUserStats() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          // Calculate hours spent in study rooms based on session logs
          await _calculateStudyRoomTime(userData, user.uid);

          // Check daily goals streak status and update if needed
          await _updateDailyGoalStreak(userData, user.uid);

          setState(() {
            _userStats = userData;
            _isLoadingStats = false;
          });
        } else {
          setState(() {
            _isLoadingStats = false;
          });
        }
      } else {
        setState(() {
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('Error loading user stats: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  // Calculate time spent in study rooms from participant records
  Future<void> _calculateStudyRoomTime(
    Map<String, dynamic> userData,
    String userId,
  ) async {
    try {
      // Query all study room participants where this user has joined
      QuerySnapshot participantQuery =
          await _firestore
              .collectionGroup('participants')
              .where('userId', isEqualTo: userId)
              .get();

      if (participantQuery.docs.isNotEmpty) {
        double totalHours = 0.0;

        // Current timestamp to calculate time for ongoing sessions
        final now = DateTime.now();

        for (var doc in participantQuery.docs) {
          final participantData = doc.data() as Map<String, dynamic>;

          // Get join timestamp
          if (participantData.containsKey('joinedAt')) {
            final joinedAt = participantData['joinedAt'] as Timestamp?;

            if (joinedAt != null) {
              DateTime joinTime = joinedAt.toDate();

              // Calculate study duration - either to 'leftAt' timestamp or to now if still active
              DateTime endTime;
              if (participantData.containsKey('leftAt') &&
                  participantData['leftAt'] != null) {
                endTime = (participantData['leftAt'] as Timestamp).toDate();
              } else {
                // Session still active, count time until now
                endTime = now;
              }

              // Calculate hours
              final durationInHours =
                  endTime.difference(joinTime).inMinutes / 60.0;
              totalHours += durationInHours;
            }
          }
        }

        // Update the user's study hours in userData map
        userData['studyHours'] = totalHours;
      }
    } catch (e) {
      print('Error calculating study room time: $e');
    }
  }

  // Check and update daily goal streak with reset if a day was missed
  Future<void> _updateDailyGoalStreak(
    Map<String, dynamic> userData,
    String userId,
  ) async {
    try {
      // Get the current streak
      int currentStreak = userData['currentStreak'] ?? 0;

      // Get the last time streak was updated
      Timestamp? lastStreakUpdate = userData['lastStreakUpdate'] as Timestamp?;

      if (lastStreakUpdate != null) {
        final lastUpdateDate = lastStreakUpdate.toDate();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(Duration(days: 1));
        final lastUpdate = DateTime(
          lastUpdateDate.year,
          lastUpdateDate.month,
          lastUpdateDate.day,
        );

        // If last update was before yesterday, reset streak
        if (lastUpdate.isBefore(yesterday)) {
          // Check if any goals were completed yesterday
          bool completedYesterday = await _checkGoalCompletionForDate(
            userId,
            yesterday,
          );

          if (!completedYesterday) {
            // Reset streak as a day was missed
            await _firestore.collection('users').doc(userId).update({
              'currentStreak': 0,
              'lastStreakUpdate': FieldValue.serverTimestamp(),
            });

            // Update local copy
            userData['currentStreak'] = 0;
          }
        }
      }
    } catch (e) {
      print('Error updating daily goal streak: $e');
    }
  }

  // Check if any goals were completed on a specific date
  Future<bool> _checkGoalCompletionForDate(String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // Query study goals completed on the specified date
      QuerySnapshot goalsQuery =
          await _firestore
              .collection('studyGoals')
              .where('userId', isEqualTo: userId)
              .where('completed', isEqualTo: true)
              .get();

      // Check if any goals were completed on the specified date
      for (var doc in goalsQuery.docs) {
        final goalData = doc.data() as Map<String, dynamic>;
        if (goalData.containsKey('completedAt')) {
          final completedAt = goalData['completedAt'] as Timestamp?;

          if (completedAt != null) {
            final completionDate = completedAt.toDate();
            if (completionDate.isAfter(startOfDay) &&
                completionDate.isBefore(endOfDay)) {
              return true; // Found at least one goal completed on this date
            }
          }
        }
      }

      return false; // No goals completed on this date
    } catch (e) {
      print('Error checking goal completion: $e');
      return false;
    }
  }

  // Build the stats dashboard with updated metrics
  Widget _buildStatsDashboard() {
    // If still loading, show a loading indicator
    if (_isLoadingStats) {
      return Container(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
          ),
        ),
      );
    }

    // Get stats from user data or use defaults
    // Sessions for amount of classes studied (flashcard decks, study materials, etc.)
    int studySessions = _userStats['studySessions'] ?? 0;
    // Hours studied from time spent in study rooms (calculated from join/leave timestamps)
    double studyHours = _userStats['studyHours'] ?? 0.0;
    // Cycles from completed pomodoro cycles
    int completedCycles = _userStats['completedPomodoroCycles'] ?? 0;
    // Streak for daily goal completion with reset when a day is missed
    int currentStreak = _userStats['currentStreak'] ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepOrange.shade700, Colors.orange.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Focus Statistics",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  Icons.timer,
                  studyHours.toStringAsFixed(1),
                  "Hours",
                  Colors.white,
                ),
                _buildStatItem(
                  Icons.repeat,
                  completedCycles.toString(),
                  "Cycles",
                  Colors.white,
                ),
                _buildStatItem(
                  Icons.local_fire_department,
                  currentStreak.toString(),
                  "Streak",
                  Colors.white,
                ),
                _buildStatItem(
                  Icons.psychology,
                  studySessions.toString(),
                  "Sessions",
                  Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build stat items
  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }

  // Generate a random room code
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = new DateTime.now().millisecondsSinceEpoch;
    final randomizer = new Random(random);
    String result = '';
    for (var i = 0; i < 6; i++) {
      result += chars[randomizer.nextInt(chars.length)];
    }
    return result;
  }

  // Method to show create new study room dialog
  void _showCreateRoomDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController topicController = TextEditingController();
    bool isPrivate = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text("Create New Study Room"),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: "Room Name",
                            hintText: "Enter a name for your study room",
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: topicController,
                          decoration: InputDecoration(
                            labelText: "Topic",
                            hintText: "Enter the main topic of discussion",
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Private Room"),
                            Switch(
                              value: isPrivate,
                              onChanged: (value) {
                                setState(() {
                                  isPrivate = value;
                                });
                              },
                              activeColor: Colors.orangeAccent,
                            ),
                          ],
                        ),
                        if (isPrivate)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              "A private room can only be joined with an invite code",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
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
                      onPressed: () async {
                        // Add the new room to Firestore
                        if (nameController.text.isNotEmpty &&
                            topicController.text.isNotEmpty) {
                          try {
                            // Generate room code for private rooms
                            final roomCode =
                                isPrivate ? _generateRoomCode() : null;

                            final docRef = await _firestore
                                .collection('studyRooms')
                                .add({
                                  'name': nameController.text,
                                  'participants':
                                      1, // Start with just the creator
                                  'topic': topicController.text,
                                  'isActive': true,
                                  'isPrivate': isPrivate,
                                  'roomCode': roomCode,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'createdBy':
                                      _auth.currentUser?.uid ?? 'anonymous',
                                  'creatorName':
                                      _auth.currentUser?.email?.split('@')[0] ??
                                      'Anonymous',
                                });

                            Navigator.pop(context);

                            // Show room code for private rooms
                            if (isPrivate && roomCode != null) {
                              _showRoomCodeDialog(roomCode, docRef.id);
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error creating room: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: Text("Create"),
                    ),
                  ],
                ),
          ),
    );
  }

  // Show dialog with the room code after creating a private room
  void _showRoomCodeDialog(String roomCode, String roomId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text("Private Room Created"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Your room has been created! Share this code with friends to invite them:",
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        roomCode,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                      SizedBox(width: 12),
                      IconButton(
                        icon: Icon(Icons.copy),
                        onPressed: () {
                          // Copy to clipboard functionality would go here
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Room code copied!')),
                          );
                        },
                        tooltip: "Copy to clipboard",
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text("Close"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                ),
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  // Navigate to the room
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudyRoomScreen(roomId: roomId),
                    ),
                  );
                },
                child: Text("Enter Room"),
              ),
            ],
          ),
    );
  }

  // Method to show join by code dialog
  void _showJoinByCodeDialog() {
    final TextEditingController codeController = TextEditingController();
    bool isLoading = false;
    String errorMessage = '';

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text("Join Private Room"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: codeController,
                        decoration: InputDecoration(
                          labelText: "Room Code",
                          hintText: "Enter the 6-digit room code",
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                      ),
                      if (errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            errorMessage,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      if (isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: CircularProgressIndicator(),
                        ),
                    ],
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
                      onPressed:
                          isLoading
                              ? null
                              : () async {
                                // Validate and join room by code
                                if (codeController.text.isEmpty) {
                                  setState(() {
                                    errorMessage = "Please enter a room code";
                                  });
                                  return;
                                }

                                setState(() {
                                  isLoading = true;
                                  errorMessage = '';
                                });

                                try {
                                  // Query for room with this code
                                  final querySnapshot =
                                      await _firestore
                                          .collection('studyRooms')
                                          .where(
                                            'roomCode',
                                            isEqualTo:
                                                codeController.text
                                                    .toUpperCase(),
                                          )
                                          .where('isActive', isEqualTo: true)
                                          .get();

                                  if (querySnapshot.docs.isEmpty) {
                                    setState(() {
                                      isLoading = false;
                                      errorMessage =
                                          "Invalid room code or room not active";
                                    });
                                    return;
                                  }

                                  // Get the room ID and navigate to it
                                  final roomId = querySnapshot.docs.first.id;
                                  Navigator.pop(context); // Close dialog

                                  // Navigate to the room
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              StudyRoomScreen(roomId: roomId),
                                    ),
                                  );
                                } catch (e) {
                                  setState(() {
                                    isLoading = false;
                                    errorMessage = "Error joining room: $e";
                                  });
                                }
                              },
                      child: Text("Join"),
                    ),
                  ],
                ),
          ),
    );
  }

  // Method to sign out
  void _signOut() async {
    try {
      await _auth.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Build the navigation drawer
  Widget _buildNavigationDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.orangeAccent),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Study Room',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tools and Resources',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  _auth.currentUser?.email ?? 'Not signed in',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: Colors.orangeAccent),
            title: Text('Dashboard'),
            selected: true,
            selectedTileColor: Colors.orange[50],
            onTap: () {
              Navigator.pop(context); // Close the drawer
            },
          ),
          ListTile(
            leading: Icon(Icons.timer, color: Colors.orangeAccent),
            title: Text('Pomodoro Timer'),
            subtitle: Text('Focus and break timer'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              // Navigate to the Pomodoro Timer screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PomodoroTimerScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.task_alt, color: Colors.orangeAccent),
            title: Text('Tasks & Progress'),
            subtitle: Text('Track and manage your tasks'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              // Navigate to the Task List screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TaskListScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.flag, color: Colors.orangeAccent),
            title: Text('Daily Study Goals'),
            subtitle: Text('Set and track study targets'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              // Navigate to the Daily Study Goals screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DailyStudyGoalsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.style, color: Colors.orangeAccent),
            title: Text('Virtual Flashcards'),
            subtitle: Text('Create and practice with flashcards'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              // Navigate to the Flashcards screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FlashcardsScreen()),
              );
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.person, color: Colors.orangeAccent),
            title: Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.settings, color: Colors.orangeAccent),
            title: Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Sign Out'),
            onTap: () {
              Navigator.pop(context);
              _signOut();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Text("Study Room Dashboard"),
        actions: [
          // Profile button
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
          // Tasks button
          IconButton(
            icon: Icon(Icons.task_alt),
            tooltip: "Tasks & Progress",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TaskListScreen()),
              );
            },
          ),
          // Goals button
          IconButton(
            icon: Icon(Icons.flag),
            tooltip: "Daily Study Goals",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DailyStudyGoalsScreen(),
                ),
              );
            },
          ),
          // Flashcards button
          IconButton(
            icon: Icon(Icons.style),
            tooltip: "Virtual Flashcards",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FlashcardsScreen()),
              );
            },
          ),
          // Settings button
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      drawer: _buildNavigationDrawer(),
      body: Column(
        children: [
          // Header section - Welcome message
          Container(
            padding: EdgeInsets.all(16.0),
            color: isDarkMode ? Theme.of(context).cardColor : Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back, ${_auth.currentUser?.email?.split('@')[0] ?? 'Student'}!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Join an active study room or create a new one",
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey[400] : Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // Dashboard with Focus Stats
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildStatsDashboard(),
          ),

          // Study rooms header with join by code option
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Active Study Rooms",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.vpn_key),
                      label: Text("Join by Code"),
                      onPressed: _showJoinByCodeDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Study rooms list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _studyRoomsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('No study rooms available. Create one!'),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final room = doc.data() as Map<String, dynamic>;
                    final roomId = doc.id;

                    return Stack(
                      children: [
                        Card(
                          margin: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.all(16),
                            title: Text(
                              room['name'] ?? 'Unnamed Room',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                Text("Topic: ${room['topic'] ?? 'No topic'}"),
                                SizedBox(height: 4),
                                Text(
                                  "Participants: ${room['participants'] ?? 0}",
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Created by: ${room['creatorName'] ?? 'Unknown'}",
                                ),
                              ],
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    room['isActive'] == true
                                        ? Colors.orangeAccent
                                        : Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed:
                                  room['isActive'] == true
                                      ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => StudyRoomScreen(
                                                  roomId: roomId,
                                                ),
                                          ),
                                        );
                                      }
                                      : null,
                              child: Text(
                                room['isActive'] == true ? "Join" : "Inactive",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        // Private tag positioned at top-right above join button
                        if (room['isPrivate'] == true)
                          Positioned(
                            top:
                                20, // Slightly lower to decrease distance to Join button
                            right: 43, // Moved slightly more to the right
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isDarkMode
                                        ? Colors.red.withOpacity(0.2)
                                        : Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color:
                                      isDarkMode
                                          ? Colors.red.withOpacity(0.5)
                                          : Colors.red[200]!,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock,
                                    size: 12,
                                    color:
                                        isDarkMode
                                            ? Colors.red[300]
                                            : Colors.red[400],
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "Private",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color:
                                          isDarkMode
                                              ? Colors.red[300]
                                              : Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: _showCreateRoomDialog,
        tooltip: 'Create New Study Room',
      ),
    );
  }
}
