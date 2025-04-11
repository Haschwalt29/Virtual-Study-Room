import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'services/rewards_service.dart';

class LeaderboardScreen extends StatefulWidget {
  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class UserRankData {
  final String userId;
  final String name;
  final String? avatar;
  final int level;
  final int xp;
  final int badgeCount;
  final int rank;

  UserRankData({
    required this.userId,
    required this.name,
    this.avatar,
    required this.level,
    required this.xp,
    required this.badgeCount,
    required this.rank,
  });
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RewardsService _rewardsService = RewardsService();

  List<UserRankData> _leaderboardData = [];
  bool _isLoading = true;
  String? _currentUserId;
  int _currentUserRank = 0;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadLeaderboardData();
  }

  Future<void> _loadLeaderboardData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get all users
      QuerySnapshot userSnapshot = await _firestore.collection('users').get();
      List<UserRankData> users = [];

      // Process each user's data
      int index = 0;
      for (var doc in userSnapshot.docs) {
        Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
        String userId = doc.id;

        // Get user's XP and level data
        int xp = userData['xp'] ?? 0;

        // Get user's badges
        List<dynamic> badges = userData['badges'] ?? [];
        int badgeCount = badges.length;

        // Calculate level (same formula as in rewards_service.dart)
        int level = 0;
        if (xp > 0) {
          level = math.sqrt(xp / 100).floor();
        }

        users.add(
          UserRankData(
            userId: userId,
            name: userData['name'] ?? 'Anonymous User',
            avatar: userData['avatar'],
            level: level,
            xp: xp,
            badgeCount: badgeCount,
            rank: 0, // Will be set after sorting
          ),
        );
      }

      // Sort by level (primary) and badge count (secondary)
      users.sort((a, b) {
        // First sort by level in descending order
        int levelCompare = b.level.compareTo(a.level);
        if (levelCompare != 0) return levelCompare;

        // If levels are the same, sort by badges in descending order
        int badgeCompare = b.badgeCount.compareTo(a.badgeCount);
        if (badgeCompare != 0) return badgeCompare;

        // If badges are the same, sort by XP in descending order
        return b.xp.compareTo(a.xp);
      });

      // Assign ranks
      for (int i = 0; i < users.length; i++) {
        UserRankData user = users[i];

        // Create a new user with assigned rank (i+1)
        users[i] = UserRankData(
          userId: user.userId,
          name: user.name,
          avatar: user.avatar,
          level: user.level,
          xp: user.xp,
          badgeCount: user.badgeCount,
          rank: i + 1,
        );

        // Check if this is the current user and save their rank
        if (user.userId == _currentUserId) {
          _currentUserRank = i + 1;
        }
      }

      setState(() {
        _leaderboardData = users;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading leaderboard data: $e');
      setState(() {
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
        title: Text("Leaderboard"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadLeaderboardData,
            tooltip: "Refresh leaderboard",
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Header with trophy and description
                  Container(
                    padding: EdgeInsets.all(16.0),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade700, Colors.orange.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
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
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.emoji_events,
                              size: 40,
                              color: Colors.white,
                            ),
                            SizedBox(width: 12),
                            Text(
                              "Study Champions",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Compete with other students based on your level and badges",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Current user's rank
                        if (_currentUserId != null && _currentUserRank > 0)
                          Container(
                            margin: EdgeInsets.only(top: 16),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "Your Rank: #$_currentUserRank",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Top 3 Users with special styling
                  if (_leaderboardData.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // 2nd Place
                          if (_leaderboardData.length > 1)
                            _buildTopUserWidget(
                              _leaderboardData[1],
                              2,
                              Colors.grey.shade400,
                              size: 70,
                              isDarkMode: isDarkMode,
                            ),

                          // 1st Place
                          if (_leaderboardData.isNotEmpty)
                            _buildTopUserWidget(
                              _leaderboardData[0],
                              1,
                              Colors.amber,
                              size: 90,
                              isDarkMode: isDarkMode,
                            ),

                          // 3rd Place
                          if (_leaderboardData.length > 2)
                            _buildTopUserWidget(
                              _leaderboardData[2],
                              3,
                              Colors.brown.shade300,
                              size: 70,
                              isDarkMode: isDarkMode,
                            ),
                        ],
                      ),
                    ),

                  // Rest of users list
                  Expanded(
                    child:
                        _leaderboardData.isEmpty
                            ? Center(child: Text("No users found"))
                            : ListView.builder(
                              itemCount:
                                  _leaderboardData.length > 3
                                      ? _leaderboardData.length - 3
                                      : 0,
                              itemBuilder: (context, index) {
                                final userData = _leaderboardData[index + 3];
                                final bool isCurrentUser =
                                    userData.userId == _currentUserId;

                                return Card(
                                  margin: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  elevation: isCurrentUser ? 4 : 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side:
                                        isCurrentUser
                                            ? BorderSide(
                                              color: Colors.orangeAccent,
                                              width: 2,
                                            )
                                            : BorderSide.none,
                                  ),
                                  color:
                                      isCurrentUser
                                          ? (isDarkMode
                                              ? Colors.orange.withOpacity(0.2)
                                              : Colors.orange.withOpacity(0.05))
                                          : null,
                                  child: ListTile(
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 30,
                                          alignment: Alignment.center,
                                          child: Text(
                                            "${userData.rank}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        _buildUserAvatar(userData.avatar, 32),
                                      ],
                                    ),
                                    title: Text(
                                      userData.name,
                                      style: TextStyle(
                                        fontWeight:
                                            isCurrentUser
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: Text("Level ${userData.level}"),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.emoji_events,
                                          color: Colors.amber,
                                          size: 20,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          "${userData.badgeCount}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }

  Widget _buildTopUserWidget(
    UserRankData userData,
    int place,
    Color medalColor, {
    required double size,
    required bool isDarkMode,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown for 1st place
        if (place == 1)
          Icon(Icons.king_bed_outlined, color: Colors.amber, size: 24),

        // Number badge with medal color
        Stack(
          alignment: Alignment.center,
          children: [
            // Medal circle
            Container(
              padding: EdgeInsets.all(place == 1 ? 4 : 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: medalColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: _buildUserAvatar(userData.avatar, size),
            ),

            // Rank position
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      place == 1
                          ? Colors.amber
                          : (place == 2
                              ? Colors.grey.shade300
                              : Colors.brown.shade300),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  "$place",
                  style: TextStyle(
                    color: place == 1 ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 8),

        // User name
        Text(
          userData.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: place == 1 ? 16 : 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        // Level and badges
        Text(
          "Level ${userData.level}",
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, size: 14, color: Colors.amber),
            SizedBox(width: 2),
            Text(
              "${userData.badgeCount}",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserAvatar(String? avatarPath, double size) {
    if (avatarPath != null && avatarPath.startsWith('http')) {
      // Network image
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(avatarPath),
        backgroundColor: Colors.grey[200],
      );
    } else if (avatarPath != null && avatarPath.isNotEmpty) {
      // Asset image
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: AssetImage(avatarPath),
        backgroundColor: Colors.grey[200],
      );
    } else {
      // Default icon
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey[200],
        child: Icon(Icons.person, size: size / 2, color: Colors.grey[700]),
      );
    }
  }
}
