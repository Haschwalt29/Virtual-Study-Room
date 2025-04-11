import 'dart:math';
import 'package:flutter/material.dart';

class AIService {
  // Get study recommendations based on current mood
  static Future<Map<String, dynamic>> getMoodBasedRecommendations(
    String mood,
  ) async {
    // Simulate API delay
    await Future.delayed(Duration(seconds: 1));

    // Default recommendations if no mood is selected
    if (mood.isEmpty) {
      return {
        'title': 'Select your mood to get personalized recommendations',
        'description':
            'We provide tailored study strategies based on how you feel',
        'studyApproach': 'Choose a mood to begin',
        'recommendedSubjects': ['General review', 'Light reading'],
        'recommendedEnvironment': 'Any comfortable space',
        'recommendedTechniques': ['Self-assessment', 'Goal setting'],
        'moodColor': Colors.blue.value,
        'moodIcon': Icons.sentiment_neutral.codePoint,
      };
    }

    // Return mood-specific recommendations
    switch (mood.toLowerCase()) {
      case 'energetic':
        return {
          'title': 'Make the Most of Your Energy!',
          'description':
              'Your high energy is perfect for tackling challenging subjects and active learning',
          'studyApproach':
              'Leverage your energy with active, engaging study methods',
          'recommendedSubjects': [
            'Math problems',
            'Science experiments',
            'Language practice',
            'Complex projects',
          ],
          'recommendedEnvironment':
              'Bright, stimulating environment with space to move around',
          'recommendedTechniques': [
            'Active problem-solving',
            'Group discussions',
            'Teaching concepts to others',
            'Creating mind maps or diagrams',
            'Experimental learning',
          ],
          'moodColor': Colors.orange.value,
          'moodIcon': Icons.bolt.codePoint,
        };

      case 'focused':
        return {
          'title': 'Deep Work Session',
          'description':
              'Your focused state is ideal for deep learning and complex topics',
          'studyApproach':
              'Maximize this focused state with deep work techniques',
          'recommendedSubjects': [
            'Research papers',
            'Technical reading',
            'Complex problems',
            'Critical analysis',
          ],
          'recommendedEnvironment':
              'Quiet, distraction-free space with minimal interruptions',
          'recommendedTechniques': [
            'Pomodoro technique (25-minute focused sessions)',
            'Single-tasking on one topic',
            'Deep reading with note-taking',
            'Problem-solving exercises',
            'Writing summaries or analyses',
          ],
          'moodColor': Colors.indigo.value,
          'moodIcon': Icons.center_focus_strong.codePoint,
        };

      case 'creative':
        return {
          'title': 'Creative Learning Flow',
          'description':
              'Your creative mood is perfect for making connections and innovative thinking',
          'studyApproach':
              'Use creative methods to approach your study material',
          'recommendedSubjects': [
            'Arts',
            'Literature',
            'Interdisciplinary topics',
            'Design projects',
            'Essay writing',
          ],
          'recommendedEnvironment':
              'Inspiring space with stimulating visuals or nature views',
          'recommendedTechniques': [
            'Mind mapping',
            'Visual note-taking',
            'Drawing connections between concepts',
            'Metaphorical thinking',
            'Creating projects or presentations',
            'Discussing ideas with others',
          ],
          'moodColor': Colors.purple.value,
          'moodIcon': Icons.lightbulb.codePoint,
        };

      case 'tired':
        return {
          'title': 'Gentle Learning Session',
          'description':
              'When tired, focus on gentle review and consolidation rather than new material',
          'studyApproach':
              'Use low-energy methods that reinforce existing knowledge',
          'recommendedSubjects': [
            'Review of familiar material',
            'Light reading',
            'Organizing notes',
          ],
          'recommendedEnvironment':
              'Comfortable, cozy space with good support for posture',
          'recommendedTechniques': [
            'Passive review of flash cards',
            'Listening to educational podcasts or videos',
            'Gentle spaced repetition',
            'Organizing study materials',
            'Setting up plans for when energy returns',
          ],
          'moodColor': Colors.blueGrey.value,
          'moodIcon': Icons.bedtime.codePoint,
        };

      case 'anxious':
        return {
          'title': 'Calm, Structured Learning',
          'description':
              'When anxious, focus on creating structure and small achievements',
          'studyApproach': 'Break down tasks into very small, manageable parts',
          'recommendedSubjects': [
            'Review of familiar material',
            'Organizing and planning',
            'Simple practice problems',
          ],
          'recommendedEnvironment':
              'Calm, organized space with minimal clutter',
          'recommendedTechniques': [
            'Creating detailed to-do lists with small tasks',
            'Breathing exercises before studying',
            'Setting 10-minute mini-sessions',
            'Rewarding yourself for small achievements',
            'Using checklists to track progress',
          ],
          'moodColor': Colors.teal.value,
          'moodIcon': Icons.healing.codePoint,
        };

      case 'distracted':
        return {
          'title': 'Reclaim Your Focus',
          'description':
              'When distracted, use techniques to gradually rebuild concentration',
          'studyApproach':
              'Structure your environment and time to minimize distractions',
          'recommendedSubjects': [
            'Single-topic focus',
            'Brief review sessions',
            'Practical exercises',
          ],
          'recommendedEnvironment':
              'Clutter-free space with distractions removed (no phone, social media blockers)',
          'recommendedTechniques': [
            'Pomodoro with shorter intervals (15 minutes)',
            'White noise or focus music',
            'Setting specific, concrete goals for each session',
            'Using website blockers',
            'Mindfulness exercises before studying',
          ],
          'moodColor': Colors.amber.value,
          'moodIcon': Icons.filter_center_focus.codePoint,
        };

      case 'motivated':
        return {
          'title': 'Capitalize on Your Motivation!',
          'description':
              'Use this motivational momentum to make significant progress',
          'studyApproach':
              'Set ambitious but achievable goals while your motivation is high',
          'recommendedSubjects': [
            'Challenging topics',
            'Projects you\'ve been postponing',
            'New material',
            'Difficult assignments',
          ],
          'recommendedEnvironment':
              'Your preferred study space, optimized for productivity',
          'recommendedTechniques': [
            'Batching similar tasks',
            'Setting up systems for future success',
            'Working ahead on upcoming assignments',
            'Creating roadmaps for complex projects',
            'Tracking progress to maintain motivation',
          ],
          'moodColor': Colors.green.value,
          'moodIcon': Icons.rocket_launch.codePoint,
        };

      default:
        return {
          'title': 'Personalized Study Session',
          'description':
              'Study recommendations tailored to your current state of mind',
          'studyApproach':
              'Adapt your approach based on how you feel right now',
          'recommendedSubjects': [
            'Balanced selection of subjects',
            'Mix of review and new material',
          ],
          'recommendedEnvironment':
              'A comfortable space that matches your current preferences',
          'recommendedTechniques': [
            'Varied study techniques',
            'Breaks when needed',
            'Setting realistic goals',
            'Tracking your progress',
            'Adjusting as your mood changes',
          ],
          'moodColor': Colors.blue.value,
          'moodIcon': Icons.sentiment_satisfied.codePoint,
        };
    }
  }

  // Simulates AI analysis of text to generate flashcards
  // In a real implementation, this would call an AI API (OpenAI, Google Gemini, etc.)
  static Future<List<Map<String, dynamic>>> generateFlashcardsFromText(
    String text, {
    int maxCards = 10,
  }) async {
    if (text.isEmpty) {
      return [];
    }

    // Simulate API delay
    await Future.delayed(Duration(seconds: 2));

    // This is a demo implementation that identifies sentences ending with
    // question marks as potential flashcard material, or creates Q&A pairs
    // from sentences with key phrases like "is defined as", "refers to", etc.
    final List<Map<String, dynamic>> flashcards = [];

    // Break text into sentences
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));

    // Simple rules to extract potential flashcards
    for (var sentence in sentences) {
      if (flashcards.length >= maxCards) break;

      sentence = sentence.trim();
      if (sentence.isEmpty) continue;

      // Case 1: Sentences ending with question marks become flashcard questions
      if (sentence.endsWith('?')) {
        // Look for the answer in the next sentence if available
        final questionIndex = sentences.indexOf(sentence);
        String answer = "Generate your own answer";

        if (questionIndex < sentences.length - 1) {
          answer = sentences[questionIndex + 1].trim();
        }

        flashcards.add({'question': sentence, 'answer': answer});
      }
      // Case 2: Definitions (contains "is defined as", "refers to", etc.)
      else if (sentence.contains(
        RegExp(r'is defined as|refers to|means|is characterized by|is a|are a'),
      )) {
        // Extract definition patterns
        final match = RegExp(
          r'(.*?)\s+(is defined as|refers to|means|is characterized by|is a|are a)\s+(.*)',
          caseSensitive: false,
        ).firstMatch(sentence);

        if (match != null) {
          final term = match.group(1)?.trim();
          final definition = match.group(3)?.trim();

          if (term != null && definition != null) {
            flashcards.add({
              'question': 'What ${match.group(2)?.toLowerCase()} $term?',
              'answer': definition,
            });
          }
        }
      }
      // Case 3: Key facts - extract important statements based on keywords
      else if (sentence.contains(
            RegExp(
              r'important|significant|key|essential|crucial|primary',
              caseSensitive: false,
            ),
          ) &&
          sentence.length > 30) {
        // Turn fact into a question
        var question = sentence.replaceAll(RegExp(r'[.,;]$'), '');

        // Find a key term to replace with a blank or question
        final keyTerms = RegExp(
          r'\b[A-Z][a-z]{2,}\b|\b\d{4}\b|\b\d+\s+percent\b',
        );
        final matches = keyTerms.allMatches(question);

        if (matches.isNotEmpty) {
          final randomMatch = matches.elementAt(
            Random().nextInt(matches.length),
          );
          final keyTerm = question.substring(
            randomMatch.start,
            randomMatch.end,
          );
          final blankQuestion = question.replaceRange(
            randomMatch.start,
            randomMatch.end,
            '_______',
          );

          flashcards.add({
            'question': 'Fill in the blank: $blankQuestion',
            'answer': keyTerm,
          });
        }
      }
    }

    // If we couldn't generate enough cards with the rules above,
    // add some generic ones to reach at least 3 cards (if text is long enough)
    if (flashcards.length < 3 && text.length > 200) {
      final paragraphs = text.split('\n\n');

      for (var paragraph in paragraphs) {
        if (flashcards.length >= maxCards) break;
        if (paragraph.trim().length < 30) continue;

        // Create a summarization card for longer paragraphs
        if (paragraph.length > 100) {
          flashcards.add({
            'question':
                'Summarize the following in your own words:\n${paragraph.substring(0, min(paragraph.length, 150))}...',
            'answer': 'Create your own summary',
          });
        }
      }
    }

    // Add flashcard styling and metadata
    final List<Color> cardColors = [
      Color(0xFF2196F3), // Blue
      Color(0xFF4CAF50), // Green
      Color(0xFFF44336), // Red
      Color(0xFF9C27B0), // Purple
      Color(0xFFFF9800), // Orange
    ];

    return flashcards.map((card) {
      // Add random color and styling
      return {
        'question': card['question'],
        // Ensure answer is very short one-liner
        'answer': _ensureConciseText(card['answer'], 40),
        'color': cardColors[Random().nextInt(cardColors.length)].value,
        'fontSize': 18.0,
        'fontFamily': 'Roboto',
        'fontWeight': 0, // Normal weight (index 0)
        'textAlign': 3, // Left-aligned (index 3) - was Center (index 0)
      };
    }).toList();
  }

  // Helper method to ensure text is extremely concise (one-liner)
  static String _ensureConciseText(String text, int maxLength) {
    // Remove any newlines to ensure answer is one line
    text = text.replaceAll('\n', ' ').trim();

    // Force shorter maximum length for true one-liners
    final int effectiveMaxLength = 40; // Very short for mobile UI

    // If already short enough, return it
    if (text.length <= effectiveMaxLength) {
      return text;
    }

    // Try to find a good breaking point (end of sentence or punctuation)
    int breakPoint = min(effectiveMaxLength, text.length);
    while (breakPoint > effectiveMaxLength * 0.6) {
      if (['.', '!', '?', ';', ',', ' '].contains(text[breakPoint - 1])) {
        // For spaces, avoid partial words by using the space as break point
        if (text[breakPoint - 1] == ' ') {
          return text.substring(0, breakPoint - 1) + '.';
        }
        return text.substring(0, breakPoint);
      }
      breakPoint--;
    }

    // If no good breaking point, just truncate with ellipsis
    return text.substring(0, effectiveMaxLength - 2) + '..';
  }

  // Simulates AI-based learning analysis to recommend study focus
  static Future<Map<String, dynamic>> analyzeStudyPerformance(
    List<Map<String, dynamic>> studyData,
  ) async {
    // Simulate processing delay
    await Future.delayed(Duration(seconds: 1));

    if (studyData.isEmpty) {
      return {
        'recommendedFocus': 'Start by creating and practicing with flashcards',
        'studyTimeRecommendation': '20-30 minutes daily',
        'confidenceScore': 0,
      };
    }

    // In a real implementation, this would analyze:
    // - Topics with lowest success rate
    // - Cards that have been marked wrong most frequently
    // - Optimal study times based on past performance
    // - Spaced repetition intervals

    int correctAnswers = 0;
    int totalAnswers = 0;

    for (var data in studyData) {
      if (data.containsKey('isCorrect')) {
        totalAnswers++;
        if (data['isCorrect'] == true) {
          correctAnswers++;
        }
      }
    }

    final double successRate =
        totalAnswers > 0 ? correctAnswers / totalAnswers : 0;

    // Generate recommendations
    String focusRecommendation;
    String timeRecommendation;

    if (successRate < 0.5) {
      focusRecommendation =
          'Review basic concepts and spend more time on fundamentals';
      timeRecommendation = '15-20 minute sessions, 3 times daily';
    } else if (successRate < 0.8) {
      focusRecommendation =
          'Continue regular practice with focus on challenging topics';
      timeRecommendation = '25-30 minute sessions, twice daily';
    } else {
      focusRecommendation =
          'Move to advanced concepts while maintaining review of current material';
      timeRecommendation = '30-45 minute sessions daily';
    }

    return {
      'recommendedFocus': focusRecommendation,
      'studyTimeRecommendation': timeRecommendation,
      'confidenceScore': successRate,
      'successRate': successRate,
    };
  }

  // Smart Study Suggestions - Analyzes past study sessions to recommend optimal study times
  static Future<Map<String, dynamic>> generateSmartStudySuggestions(
    List<Map<String, dynamic>> studyHistory, {
    bool includeWeekdayAnalysis = true,
  }) async {
    // Simulate processing delay
    await Future.delayed(Duration(seconds: 2));

    // If no study history exists, provide default recommendations
    if (studyHistory.isEmpty) {
      return {
        'bestTimes': [
          {
            'timeSlot': '08:00-10:00',
            'effectiveness': 0.85,
            'reason': 'Morning focus is typically high for most students',
          },
          {
            'timeSlot': '16:00-18:00',
            'effectiveness': 0.75,
            'reason': 'Post-school/work hours are good for review',
          },
          {
            'timeSlot': '20:00-22:00',
            'effectiveness': 0.70,
            'reason': 'Evening review helps with memory consolidation',
          },
        ],
        'worstTimes': [
          {
            'timeSlot': '12:00-13:00',
            'effectiveness': 0.45,
            'reason': 'Post-lunch energy dip',
          },
          {
            'timeSlot': '15:00-16:00',
            'effectiveness': 0.50,
            'reason': 'Afternoon fatigue period',
          },
        ],
        'weekdayAnalysis': {
          'Monday': 0.82,
          'Tuesday': 0.85,
          'Wednesday': 0.79,
          'Thursday': 0.75,
          'Friday': 0.65,
          'Saturday': 0.70,
          'Sunday': 0.78,
        },
        'personalizedTip':
            'Based on average student data, morning study sessions (8-10 AM) tend to be most productive. Try short, focused sessions of 25-30 minutes followed by 5-minute breaks.',
        'recommendedTotalHours': 2.5,
        'recommendedSessionLength': 30,
      };
    }

    // In a real implementation, this would:
    // 1. Analyze timestamps from study sessions to identify patterns
    // 2. Correlate study times with performance metrics
    // 3. Identify optimal and suboptimal time periods
    // 4. Consider weekday vs weekend patterns
    // 5. Account for user's sleep/activity patterns if available

    // Variables to track performance by time slot
    Map<String, List<double>> timeSlotPerformance = {};
    Map<String, int> timeSlotSessions = {};
    Map<String, double> dayOfWeekPerformance = {};
    Map<String, int> dayOfWeekSessions = {};

    // Example time slots to analyze
    final timeSlots = [
      '06:00-08:00',
      '08:00-10:00',
      '10:00-12:00',
      '12:00-14:00',
      '14:00-16:00',
      '16:00-18:00',
      '18:00-20:00',
      '20:00-22:00',
      '22:00-00:00',
    ];

    // Initialize tracking maps
    for (var slot in timeSlots) {
      timeSlotPerformance[slot] = [];
      timeSlotSessions[slot] = 0;
    }

    final daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    for (var day in daysOfWeek) {
      dayOfWeekPerformance[day] = 0.0;
      dayOfWeekSessions[day] = 0;
    }

    // Simulate analyzing study history
    // In a real implementation, this would analyze actual study records
    final random = Random();

    // Generate simulated data based on common patterns
    for (var i = 0; i < 28; i++) {
      // 4 weeks of data
      for (var day in daysOfWeek) {
        final dayFactor = day == 'Saturday' || day == 'Sunday' ? 0.7 : 1.0;

        // Morning study sessions (usually more effective)
        if (random.nextDouble() > 0.3) {
          final morningSlot = timeSlots[random.nextInt(3)]; // 6-12 time slots
          final morningPerformance =
              0.7 + (random.nextDouble() * 0.3) * dayFactor;
          timeSlotPerformance[morningSlot]!.add(morningPerformance);
          timeSlotSessions[morningSlot] = timeSlotSessions[morningSlot]! + 1;

          dayOfWeekPerformance[day] =
              dayOfWeekPerformance[day]! + morningPerformance;
          dayOfWeekSessions[day] = dayOfWeekSessions[day]! + 1;
        }

        // Afternoon study sessions (typically less effective)
        if (random.nextDouble() > 0.5) {
          final afternoonSlot =
              timeSlots[3 + random.nextInt(2)]; // 12-16 time slots
          final afternoonPerformance =
              0.4 + (random.nextDouble() * 0.3) * dayFactor;
          timeSlotPerformance[afternoonSlot]!.add(afternoonPerformance);
          timeSlotSessions[afternoonSlot] =
              timeSlotSessions[afternoonSlot]! + 1;

          dayOfWeekPerformance[day] =
              dayOfWeekPerformance[day]! + afternoonPerformance;
          dayOfWeekSessions[day] = dayOfWeekSessions[day]! + 1;
        }

        // Evening study sessions (moderate effectiveness)
        if (random.nextDouble() > 0.4) {
          final eveningSlot =
              timeSlots[5 + random.nextInt(4)]; // 16-00 time slots
          final eveningPerformance =
              0.5 + (random.nextDouble() * 0.4) * dayFactor;
          timeSlotPerformance[eveningSlot]!.add(eveningPerformance);
          timeSlotSessions[eveningSlot] = timeSlotSessions[eveningSlot]! + 1;

          dayOfWeekPerformance[day] =
              dayOfWeekPerformance[day]! + eveningPerformance;
          dayOfWeekSessions[day] = dayOfWeekSessions[day]! + 1;
        }
      }
    }

    // Calculate average performance for each time slot
    Map<String, double> avgTimeSlotPerformance = {};
    for (var slot in timeSlots) {
      if (timeSlotPerformance[slot]!.isNotEmpty) {
        final sum = timeSlotPerformance[slot]!.reduce((a, b) => a + b);
        avgTimeSlotPerformance[slot] = sum / timeSlotPerformance[slot]!.length;
      } else {
        avgTimeSlotPerformance[slot] = 0.0;
      }
    }

    // Calculate average performance for each day of the week
    Map<String, double> avgDayPerformance = {};
    for (var day in daysOfWeek) {
      if (dayOfWeekSessions[day]! > 0) {
        avgDayPerformance[day] =
            dayOfWeekPerformance[day]! / dayOfWeekSessions[day]!;
      } else {
        avgDayPerformance[day] = 0.0;
      }
    }

    // Sort time slots by performance to find best and worst
    List<MapEntry<String, double>> sortedTimeSlots =
        avgTimeSlotPerformance.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    // Extract best and worst time slots
    final bestTimes =
        sortedTimeSlots.take(3).map((e) {
          return {
            'timeSlot': e.key,
            'effectiveness': e.value,
            'reason': _getReasonForTimeSlot(e.key, true),
            'sessions': timeSlotSessions[e.key],
          };
        }).toList();

    final worstTimes =
        sortedTimeSlots.reversed.take(2).map((e) {
          return {
            'timeSlot': e.key,
            'effectiveness': e.value,
            'reason': _getReasonForTimeSlot(e.key, false),
            'sessions': timeSlotSessions[e.key],
          };
        }).toList();

    // Generate personalized tips based on simulated data
    String personalizedTip = '';
    if (bestTimes.isNotEmpty) {
      final bestTimeSlot = bestTimes[0]['timeSlot'] as String;
      personalizedTip =
          'Your data shows that you perform best during $bestTimeSlot. Consider scheduling your most challenging study tasks during this period. ';

      if (worstTimes.isNotEmpty) {
        final worstTimeSlot = worstTimes[0]['timeSlot'] as String;
        personalizedTip +=
            'Avoid complex study tasks during $worstTimeSlot if possible, or use this time for review of already familiar material.';
      }
    } else {
      personalizedTip =
          'Based on general study patterns, morning sessions (8-10 AM) tend to be most productive. Try short, focused sessions of 25-30 minutes followed by 5-minute breaks.';
    }

    // Calculate recommended session length and total daily hours
    int recommendedSessionLength = 30; // Default
    double recommendedTotalHours = 2.5; // Default

    // Adjust based on effectiveness patterns
    if (sortedTimeSlots.isNotEmpty && sortedTimeSlots[0].value > 0.8) {
      recommendedSessionLength = 45; // Longer sessions for high effectiveness
    } else if (sortedTimeSlots.isNotEmpty && sortedTimeSlots[0].value < 0.6) {
      recommendedSessionLength =
          20; // Shorter sessions if general effectiveness is lower
    }

    // Return the analysis results
    return {
      'bestTimes': bestTimes,
      'worstTimes': worstTimes,
      'weekdayAnalysis': avgDayPerformance,
      'personalizedTip': personalizedTip,
      'recommendedTotalHours': recommendedTotalHours,
      'recommendedSessionLength': recommendedSessionLength,
    };
  }

  // Helper method to generate explanations for time slot effectiveness
  static String _getReasonForTimeSlot(String timeSlot, bool isEffective) {
    final Map<String, String> effectiveReasons = {
      '06:00-08:00': 'Early morning focus when mind is fresh',
      '08:00-10:00': 'Peak cognitive performance after breakfast',
      '10:00-12:00': 'Strong mental clarity before lunch',
      '14:00-16:00': 'Post-lunch recovery period with renewed focus',
      '16:00-18:00': 'Good recall and synthesizing abilities',
      '18:00-20:00': 'Evening review period with good retention',
      '20:00-22:00': 'Night studying with fewer distractions',
      '22:00-00:00': 'Late night focus when environment is quiet',
    };

    final Map<String, String> ineffectiveReasons = {
      '06:00-08:00': 'Too early, cognitive functions not fully awake',
      '08:00-10:00': 'Morning distractions and task switching',
      '10:00-12:00': 'Pre-lunch energy dip and hunger distractions',
      '12:00-14:00': 'Post-lunch energy dip',
      '14:00-16:00': 'Afternoon fatigue period',
      '16:00-18:00': 'End-of-day mental fatigue',
      '18:00-20:00': 'Evening distractions and decreased focus',
      '20:00-22:00': 'Evening fatigue affecting memory formation',
      '22:00-00:00': 'Late night study reduces quality of sleep and retention',
    };

    return isEffective
        ? effectiveReasons[timeSlot] ??
            'Strong focus and retention during this period'
        : ineffectiveReasons[timeSlot] ??
            'Lower focus and higher distractions during this period';
  }
}

// Type definition for color
