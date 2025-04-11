import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'avatar_customization_screen.dart';
import 'services/rewards_service.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User data
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  // Rewards data
  int _userXP = 0;
  int _userLevel = 0;
  double _levelProgress = 0.0;
  int _nextLevelXP = 100;
  List<BadgeInfo> _userBadges = [];

  // Rewards service
  final RewardsService _rewardsService = RewardsService();

  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _universityController;
  late TextEditingController _yearController;
  List<String> _subjects = [];
  TextEditingController _newSubjectController = TextEditingController();

  // Avatar options
  final List<String> _avatarOptions = [
    'Assets/avatar_1.png',
    'Assets/avatar_2.png',
    'Assets/avatar_3.png',
    'Assets/avatar_4.png',
    'Assets/avatar_5.png',
  ];
  String _selectedAvatar = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _universityController = TextEditingController();
    _yearController = TextEditingController();
    _loadUserData();
    _loadUserRewards();
  }

  // Load user XP, level and badges
  Future<void> _loadUserRewards() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Get XP and level info
        Map<String, dynamic> xpData = await _rewardsService.getUserXPAndLevel(
          user.uid,
        );

        // Get badges
        List<BadgeInfo> badges = await _rewardsService.getUserBadges(user.uid);

        setState(() {
          _userXP = xpData['xp'];
          _userLevel = xpData['level'];
          _levelProgress = xpData['progress'];
          _nextLevelXP = xpData['nextLevelXP'];
          _userBadges = badges;
        });
      }
    } catch (e) {
      print('Error loading user rewards: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _universityController.dispose();
    _yearController.dispose();
    _newSubjectController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      // Get current user
      User? user = _auth.currentUser;

      if (user != null) {
        // Get user profile from Firestore
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>;
            _nameController.text = _userData['name'] ?? user.displayName ?? '';
            _bioController.text = _userData['bio'] ?? '';
            _universityController.text = _userData['university'] ?? '';
            _yearController.text = _userData['year'] ?? '';
            _subjects = List<String>.from(_userData['subjects'] ?? []);
            _selectedAvatar = _userData['avatar'] ?? '';
            _isLoading = false;
          });
        } else {
          // Create default user profile if it doesn't exist
          Map<String, dynamic> defaultUserData = {
            'name': user.displayName ?? 'User',
            'email': user.email ?? '',
            'bio': '',
            'university': '',
            'year': '',
            'subjects': [],
            'studySessions': 0,
            'studyHours': 0.0,
            'roomsCreated': 0,
            'roomsJoined': 0,
            'avatar': '',
          };

          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(defaultUserData);

          setState(() {
            _userData = defaultUserData;
            _nameController.text = _userData['name'] ?? '';
            _bioController.text = _userData['bio'] ?? '';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleEdit() async {
    if (_isEditing) {
      // Save the changes
      setState(() {
        _isLoading = true;
      });

      try {
        User? user = _auth.currentUser;

        if (user != null) {
          // Update display name in Firebase Auth
          await user.updateDisplayName(_nameController.text);

          // Update profile in Firestore
          await _firestore.collection('users').doc(user.uid).update({
            'name': _nameController.text,
            'bio': _bioController.text,
            'university': _universityController.text,
            'year': _yearController.text,
            'subjects': _subjects,
            'avatar': _selectedAvatar,
          });

          // Update local data
          setState(() {
            _userData['name'] = _nameController.text;
            _userData['bio'] = _bioController.text;
            _userData['university'] = _universityController.text;
            _userData['year'] = _yearController.text;
            _userData['subjects'] = _subjects;
            _userData['avatar'] = _selectedAvatar;
            _isLoading = false;
            _isEditing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile updated successfully')),
          );
        }
      } catch (e) {
        print('Error updating profile: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile')));
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      // Enter edit mode
      setState(() {
        _isEditing = true;
      });
    }
  }

  // Function to track a completed study session
  Future<void> trackStudySession(int durationMinutes) async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        // Convert minutes to hours
        double hours = durationMinutes / 60.0;

        // Update study statistics
        int currentSessions = _userData['studySessions'] ?? 0;
        double currentHours = _userData['studyHours'] ?? 0.0;

        await _firestore.collection('users').doc(user.uid).update({
          'studySessions': currentSessions + 1,
          'studyHours': currentHours + hours,
        });

        // Update local data
        setState(() {
          _userData['studySessions'] = currentSessions + 1;
          _userData['studyHours'] = currentHours + hours;
        });
      }
    } catch (e) {
      print('Error tracking study session: $e');
    }
  }

  // Function to track when user creates a study room
  Future<void> trackRoomCreated() async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        int currentRoomsCreated = _userData['roomsCreated'] ?? 0;

        await _firestore.collection('users').doc(user.uid).update({
          'roomsCreated': currentRoomsCreated + 1,
        });

        setState(() {
          _userData['roomsCreated'] = currentRoomsCreated + 1;
        });
      }
    } catch (e) {
      print('Error tracking room created: $e');
    }
  }

  // Function to track when user joins a study room
  Future<void> trackRoomJoined() async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        int currentRoomsJoined = _userData['roomsJoined'] ?? 0;

        await _firestore.collection('users').doc(user.uid).update({
          'roomsJoined': currentRoomsJoined + 1,
        });

        setState(() {
          _userData['roomsJoined'] = currentRoomsJoined + 1;
        });
      }
    } catch (e) {
      print('Error tracking room joined: $e');
    }
  }

  void _showAvatarOptions() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Choose Avatar'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick options
                Container(
                  width: double.maxFinite,
                  height: 200,
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount:
                        _avatarOptions.length + 1, // +1 for default icon option
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Default icon option
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedAvatar = '';
                            });
                            Navigator.pop(context);
                          },
                          child: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.white,
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white70
                                      : Colors.grey[700],
                            ),
                          ),
                        );
                      } else {
                        // Avatar options
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedAvatar = _avatarOptions[index - 1];
                            });
                            Navigator.pop(context);
                          },
                          child: CircleAvatar(
                            backgroundImage: AssetImage(
                              _avatarOptions[index - 1],
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),

                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 8),

                // Custom avatar option
                Text(
                  'Want more customization options?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: Icon(Icons.face),
                  label: Text('Create Custom Avatar'),
                  onPressed: () {
                    Navigator.pop(context); // Close the dialog
                    _navigateToAvatarCustomization();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _navigateToAvatarCustomization() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AvatarCustomizationScreen()),
    ).then((_) {
      // Refresh profile after returning from Avatar customization
      _loadUserData();
    });
  }

  void _addSubject() {
    if (_newSubjectController.text.trim().isNotEmpty) {
      setState(() {
        _subjects.add(_newSubjectController.text.trim());
        _newSubjectController.clear();
      });
    }
  }

  void _removeSubject(int index) {
    setState(() {
      _subjects.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Profile")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _toggleEdit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile picture with customization
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: _isEditing ? _showAvatarOptions : null,
                  child: Container(
                    width: 120, // Same size as CircleAvatar with radius 60
                    height: 120, // Same size as CircleAvatar with radius 60
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).cardColor,
                    ),
                    child: Center(
                      child:
                          _userData['avatar'] != null &&
                                  _userData['avatar'].toString().startsWith(
                                    'http',
                                  )
                              ? CircleAvatar(
                                radius: 60,
                                backgroundImage: NetworkImage(
                                  _userData['avatar'],
                                ),
                              )
                              : _selectedAvatar.isNotEmpty
                              ? CircleAvatar(
                                radius: 60,
                                backgroundImage: AssetImage(_selectedAvatar),
                              )
                              : CircleAvatar(
                                radius: 60,
                                backgroundColor:
                                    isDarkMode
                                        ? Colors.grey[800]
                                        : Colors.white,
                                child: Icon(
                                  Icons.person,
                                  size: 80,
                                  color:
                                      isDarkMode
                                          ? Colors.white70
                                          : Colors.grey[700],
                                ),
                              ),
                    ),
                  ),
                ),
                if (_isEditing)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.edit, color: Colors.white),
                      onPressed: _showAvatarOptions,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),

            // Name
            _isEditing
                ? TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Name",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )
                : Text(
                  _userData['name'] ?? 'User',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
            SizedBox(height: 8),

            // Email
            Text(
              _userData['email'] ?? '',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.black54,
              ),
            ),
            SizedBox(height: 24),

            // Bio section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bio",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  SizedBox(height: 8),
                  _isEditing
                      ? TextField(
                        controller: _bioController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      )
                      : Text(
                        _userData['bio'] ?? 'No bio added yet.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Academic info section (editable)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Academic Information",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  SizedBox(height: 16),
                  _isEditing
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _universityController,
                            decoration: InputDecoration(
                              labelText: "University",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: _yearController,
                            decoration: InputDecoration(
                              labelText: "Year",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      )
                      : Column(
                        children: [
                          _buildInfoRow(
                            "University",
                            _userData['university'] ?? 'Not specified',
                            isDarkMode,
                          ),
                          _buildInfoRow(
                            "Year",
                            _userData['year'] ?? 'Not specified',
                            isDarkMode,
                          ),
                        ],
                      ),
                  SizedBox(height: 12),
                  Text(
                    "Subjects",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  SizedBox(height: 8),
                  _isEditing
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Current subjects with delete option
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(_subjects.length, (index) {
                              return Chip(
                                label: Text(_subjects[index]),
                                backgroundColor:
                                    isDarkMode
                                        ? Colors.grey[700]
                                        : Colors.grey[200],
                                labelStyle: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                                deleteIcon: Icon(Icons.close, size: 18),
                                onDeleted: () => _removeSubject(index),
                              );
                            }),
                          ),
                          SizedBox(height: 12),
                          // Add new subject
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _newSubjectController,
                                  decoration: InputDecoration(
                                    labelText: "Add Subject",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 0,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.add_circle,
                                  color: Colors.orangeAccent,
                                ),
                                onPressed: _addSubject,
                              ),
                            ],
                          ),
                        ],
                      )
                      : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            (_subjects.isEmpty
                                ? [
                                  Chip(
                                    label: Text('No subjects added'),
                                    backgroundColor:
                                        isDarkMode
                                            ? Colors.grey[700]
                                            : Colors.grey[200],
                                    labelStyle: TextStyle(
                                      color:
                                          isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                    ),
                                  ),
                                ]
                                : _subjects.map<Widget>((subject) {
                                  return Chip(
                                    label: Text(subject.toString()),
                                    backgroundColor:
                                        isDarkMode
                                            ? Colors.grey[700]
                                            : Colors.grey[200],
                                    labelStyle: TextStyle(
                                      color:
                                          isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                    ),
                                  );
                                }).toList()),
                      ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Study statistics section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Study Statistics",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInfoRow(
                    "Total Study Sessions",
                    _userData['studySessions']?.toString() ?? '0',
                    isDarkMode,
                  ),
                  _buildInfoRow(
                    "Study Hours",
                    _userData['studyHours'] != null
                        ? _userData['studyHours'].toStringAsFixed(1)
                        : '0.0',
                    isDarkMode,
                  ),
                  _buildInfoRow(
                    "Rooms Created",
                    _userData['roomsCreated']?.toString() ?? '0',
                    isDarkMode,
                  ),
                  _buildInfoRow(
                    "Rooms Joined",
                    _userData['roomsJoined']?.toString() ?? '0',
                    isDarkMode,
                  ),
                  _buildInfoRow(
                    "Current Streak",
                    _userData['currentStreak']?.toString() ?? '0',
                    isDarkMode,
                  ),
                  _buildInfoRow(
                    "Completed Pomodoro Cycles",
                    _userData['completedPomodoroCycles']?.toString() ?? '0',
                    isDarkMode,
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // XP and Level section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "XP & Level",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepOrange.shade700,
                              Colors.orange.shade500,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          "Level $_userLevel",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // XP progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$_userXP XP",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          Text(
                            "$_nextLevelXP XP for next level",
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _levelProgress,
                          minHeight: 10,
                          backgroundColor:
                              isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.orangeAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Badges section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Badges & Achievements",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  SizedBox(height: 16),

                  _userBadges.isEmpty
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.emoji_events_outlined,
                                size: 48,
                                color:
                                    isDarkMode
                                        ? Colors.grey[600]
                                        : Colors.grey[400],
                              ),
                              SizedBox(height: 12),
                              Text(
                                "Complete tasks, goals, and pomodoro cycles to earn badges!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      : GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _userBadges.length,
                        itemBuilder: (context, index) {
                          final badge = _userBadges[index];
                          return _buildBadgeItem(badge, isDarkMode);
                        },
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeItem(BadgeInfo badge, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _showBadgeDetails(badge),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 3,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    badge.iconPath,
                    errorBuilder:
                        (context, error, stackTrace) => Icon(
                          Icons.emoji_events,
                          size: 32,
                          color: Colors.amber,
                        ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showBadgeDetails(BadgeInfo badge) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(badge.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 100,
                  width: 100,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    badge.iconPath,
                    errorBuilder:
                        (context, error, stackTrace) => Icon(
                          Icons.emoji_events,
                          size: 48,
                          color: Colors.amber,
                        ),
                  ),
                ),
                SizedBox(height: 16),
                Text(badge.description, textAlign: TextAlign.center),
                SizedBox(height: 8),
                Text(
                  "Earned on: ${_formatBadgeDate(badge.dateEarned)}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Close"),
              ),
            ],
          ),
    );
  }

  String _formatBadgeDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  Widget _buildInfoRow(String label, String value, bool isDarkMode) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.grey[400] : Colors.black54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }
}
