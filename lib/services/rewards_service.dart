import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BadgeInfo {
  final String id;
  final String name;
  final String description;
  final String iconPath;
  final DateTime dateEarned;

  BadgeInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.dateEarned,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconPath': iconPath,
      'dateEarned': dateEarned,
    };
  }

  factory BadgeInfo.fromMap(Map<String, dynamic> map) {
    return BadgeInfo(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      iconPath: map['iconPath'],
      dateEarned: (map['dateEarned'] as Timestamp).toDate(),
    );
  }
}

class RewardsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // XP values for different activities
  static const int XP_POMODORO_CYCLE = 50;
  static const int XP_TASK_COMPLETION = 100;
  static const int XP_DAILY_GOAL = 150;
  static const int XP_STUDY_SESSION = 75;

  // XP bonuses
  static const double XP_BONUS_PER_MINUTE = 0.5; // For longer pomodoro cycles

  // Badge definitions
  static const Map<String, Map<String, dynamic>> BADGES = {
    'pomodoro_novice': {
      'name': 'Pomodoro Novice',
      'description': 'Complete 5 pomodoro cycles',
      'iconPath': 'Assets/badges/pomodoro_novice.png',
      'requirement': 5,
    },
    'pomodoro_master': {
      'name': 'Pomodoro Master',
      'description': 'Complete 25 pomodoro cycles',
      'iconPath': 'Assets/badges/pomodoro_master.png',
      'requirement': 25,
    },
    'pomodoro_expert': {
      'name': 'Pomodoro Expert',
      'description': 'Complete 100 pomodoro cycles',
      'iconPath': 'Assets/badges/pomodoro_expert.png',
      'requirement': 100,
    },
    'task_starter': {
      'name': 'Task Starter',
      'description': 'Complete 10 tasks',
      'iconPath': 'Assets/badges/task_starter.png',
      'requirement': 10,
    },
    'task_achiever': {
      'name': 'Task Achiever',
      'description': 'Complete 50 tasks',
      'iconPath': 'Assets/badges/task_achiever.png',
      'requirement': 50,
    },
    'goal_setter': {
      'name': 'Goal Setter',
      'description': 'Complete 5 daily study goals',
      'iconPath': 'Assets/badges/goal_setter.png',
      'requirement': 5,
    },
    'goal_crusher': {
      'name': 'Goal Crusher',
      'description': 'Complete 20 daily study goals',
      'iconPath': 'Assets/badges/goal_crusher.png',
      'requirement': 20,
    },
    'study_beginner': {
      'name': 'Study Beginner',
      'description': 'Accumulate 5 hours of study time',
      'iconPath': 'Assets/badges/study_beginner.png',
      'requirement': 5, // hours
    },
    'study_pro': {
      'name': 'Study Pro',
      'description': 'Accumulate 25 hours of study time',
      'iconPath': 'Assets/badges/study_pro.png',
      'requirement': 25, // hours
    },
    'study_champion': {
      'name': 'Study Champion',
      'description': 'Accumulate 100 hours of study time',
      'iconPath': 'Assets/badges/study_champion.png',
      'requirement': 100, // hours
    },
    'consistent_3': {
      'name': 'Consistency Bronze',
      'description': 'Maintain a 3-day study streak',
      'iconPath': 'Assets/badges/consistent_bronze.png',
      'requirement': 3, // days
    },
    'consistent_7': {
      'name': 'Consistency Silver',
      'description': 'Maintain a 7-day study streak',
      'iconPath': 'Assets/badges/consistent_silver.png',
      'requirement': 7, // days
    },
    'consistent_14': {
      'name': 'Consistency Gold',
      'description': 'Maintain a 14-day study streak',
      'iconPath': 'Assets/badges/consistent_gold.png',
      'requirement': 14, // days
    },
    'consistent_30': {
      'name': 'Consistency Diamond',
      'description': 'Maintain a 30-day study streak',
      'iconPath': 'Assets/badges/consistent_diamond.png',
      'requirement': 30, // days
    },
  };

  // Award XP for completing a pomodoro cycle
  Future<int> awardPomodoroXP(int durationMinutes) async {
    User? user = _auth.currentUser;
    if (user == null) return 0;

    // Calculate XP based on duration
    int xp = XP_POMODORO_CYCLE;

    // Add bonus XP for longer sessions
    xp += (durationMinutes * XP_BONUS_PER_MINUTE).round();

    await _addXP(user.uid, xp);

    // Check for pomodoro-related badges
    await _checkPomodoroMilestones(user.uid);

    return xp;
  }

  // Award XP for completing a task
  Future<int> awardTaskCompletionXP() async {
    User? user = _auth.currentUser;
    if (user == null) return 0;

    await _addXP(user.uid, XP_TASK_COMPLETION);

    // Check for task-related badges
    await _checkTaskMilestones(user.uid);

    return XP_TASK_COMPLETION;
  }

  // Award XP for completing a daily goal
  Future<int> awardDailyGoalXP() async {
    User? user = _auth.currentUser;
    if (user == null) return 0;

    await _addXP(user.uid, XP_DAILY_GOAL);

    // Check for goal-related badges
    await _checkGoalMilestones(user.uid);

    return XP_DAILY_GOAL;
  }

  // Award XP for a study session
  Future<int> awardStudySessionXP(int durationMinutes) async {
    User? user = _auth.currentUser;
    if (user == null) return 0;

    // Base XP for study session
    int xp = XP_STUDY_SESSION;

    // Add bonus XP for longer sessions
    xp += (durationMinutes * XP_BONUS_PER_MINUTE).round();

    await _addXP(user.uid, xp);

    // Check for study time-related badges
    await _checkStudyTimeMilestones(user.uid);

    return xp;
  }

  // Add XP to user's account
  Future<void> _addXP(String userId, int xpAmount) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        int currentXP = userData['xp'] ?? 0;

        await _firestore.collection('users').doc(userId).update({
          'xp': currentXP + xpAmount,
        });
      } else {
        // Initialize if user document doesn't have xp field
        await _firestore.collection('users').doc(userId).update({
          'xp': xpAmount,
        });
      }
    } catch (e) {
      print('Error adding XP: $e');
    }
  }

  // Award a badge to the user
  Future<void> awardBadge(String userId, String badgeId) async {
    try {
      if (!BADGES.containsKey(badgeId)) return;

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        List<dynamic> badgesList = userData['badges'] ?? [];

        // Check if user already has this badge
        bool hasBadge = badgesList.any(
          (badge) => badge is Map<String, dynamic> && badge['id'] == badgeId,
        );

        if (!hasBadge) {
          BadgeInfo newBadge = BadgeInfo(
            id: badgeId,
            name: BADGES[badgeId]!['name'],
            description: BADGES[badgeId]!['description'],
            iconPath: BADGES[badgeId]!['iconPath'],
            dateEarned: DateTime.now(),
          );

          badgesList.add(newBadge.toMap());

          await _firestore.collection('users').doc(userId).update({
            'badges': badgesList,
          });
        }
      } else {
        // Initialize if user document doesn't have badges field
        BadgeInfo newBadge = BadgeInfo(
          id: badgeId,
          name: BADGES[badgeId]!['name'],
          description: BADGES[badgeId]!['description'],
          iconPath: BADGES[badgeId]!['iconPath'],
          dateEarned: DateTime.now(),
        );

        await _firestore.collection('users').doc(userId).update({
          'badges': [newBadge.toMap()],
        });
      }
    } catch (e) {
      print('Error awarding badge: $e');
    }
  }

  // Check and award pomodoro milestone badges
  Future<void> _checkPomodoroMilestones(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        int completedCycles = userData['completedPomodoroCycles'] ?? 0;

        if (completedCycles >= 5) {
          await awardBadge(userId, 'pomodoro_novice');
        }

        if (completedCycles >= 25) {
          await awardBadge(userId, 'pomodoro_master');
        }

        if (completedCycles >= 100) {
          await awardBadge(userId, 'pomodoro_expert');
        }
      }
    } catch (e) {
      print('Error checking pomodoro milestones: $e');
    }
  }

  // Check and award task milestone badges
  Future<void> _checkTaskMilestones(String userId) async {
    try {
      // Count completed tasks for this user
      QuerySnapshot tasksSnapshot =
          await _firestore
              .collection('tasks')
              .where('userId', isEqualTo: userId)
              .where('isCompleted', isEqualTo: true)
              .get();

      int completedTasks = tasksSnapshot.docs.length;

      if (completedTasks >= 10) {
        await awardBadge(userId, 'task_starter');
      }

      if (completedTasks >= 50) {
        await awardBadge(userId, 'task_achiever');
      }
    } catch (e) {
      print('Error checking task milestones: $e');
    }
  }

  // Check and award goal milestone badges
  Future<void> _checkGoalMilestones(String userId) async {
    try {
      // Count completed goals for this user
      QuerySnapshot goalsSnapshot =
          await _firestore
              .collection('studyGoals')
              .where('userId', isEqualTo: userId)
              .where('completed', isEqualTo: true)
              .get();

      int completedGoals = goalsSnapshot.docs.length;

      if (completedGoals >= 5) {
        await awardBadge(userId, 'goal_setter');
      }

      if (completedGoals >= 20) {
        await awardBadge(userId, 'goal_crusher');
      }
    } catch (e) {
      print('Error checking goal milestones: $e');
    }
  }

  // Check and award study time milestone badges
  Future<void> _checkStudyTimeMilestones(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        double studyHours = userData['studyHours'] ?? 0.0;

        if (studyHours >= 5) {
          await awardBadge(userId, 'study_beginner');
        }

        if (studyHours >= 25) {
          await awardBadge(userId, 'study_pro');
        }

        if (studyHours >= 100) {
          await awardBadge(userId, 'study_champion');
        }
      }
    } catch (e) {
      print('Error checking study time milestones: $e');
    }
  }

  // Check and award consistency badges based on streak
  Future<void> checkConsistencyBadges(String userId, int currentStreak) async {
    try {
      if (currentStreak >= 3) {
        await awardBadge(userId, 'consistent_3');
      }

      if (currentStreak >= 7) {
        await awardBadge(userId, 'consistent_7');
      }

      if (currentStreak >= 14) {
        await awardBadge(userId, 'consistent_14');
      }

      if (currentStreak >= 30) {
        await awardBadge(userId, 'consistent_30');
      }
    } catch (e) {
      print('Error checking consistency badges: $e');
    }
  }

  // Get user's XP and level
  Future<Map<String, dynamic>> getUserXPAndLevel(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        int xp = userData['xp'] ?? 0;

        // Calculate level based on XP
        // Using a simple formula: level = sqrt(xp / 100)
        int level = math.sqrt(xp / 100).floor();

        // Calculate progress to next level
        int nextLevelXP = (level + 1) * (level + 1) * 100;
        int currentLevelXP = level * level * 100;
        double progress =
            (xp - currentLevelXP) / (nextLevelXP - currentLevelXP);

        return {
          'xp': xp,
          'level': level,
          'progress': progress,
          'nextLevelXP': nextLevelXP,
        };
      }

      return {'xp': 0, 'level': 0, 'progress': 0.0, 'nextLevelXP': 100};
    } catch (e) {
      print('Error getting user XP and level: $e');
      return {'xp': 0, 'level': 0, 'progress': 0.0, 'nextLevelXP': 100};
    }
  }

  // Get user's badges
  Future<List<BadgeInfo>> getUserBadges(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        List<dynamic> badgesList = userData['badges'] ?? [];

        return badgesList.map((badge) => BadgeInfo.fromMap(badge)).toList();
      }

      return [];
    } catch (e) {
      print('Error getting user badges: $e');
      return [];
    }
  }

  // Show an XP gained notification
  void showXPNotification(BuildContext context, int xpGained) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 12),
            Text('You earned $xpGained XP!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Show a badge earned notification
  void showBadgeNotification(BuildContext context, String badgeName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber),
            SizedBox(width: 12),
            Text('Badge earned: $badgeName!'),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
