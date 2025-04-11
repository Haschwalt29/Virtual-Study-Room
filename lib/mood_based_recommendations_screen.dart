import 'package:flutter/material.dart';
import 'services/ai_service.dart';

class MoodBasedRecommendationsScreen extends StatefulWidget {
  const MoodBasedRecommendationsScreen({super.key});

  @override
  State<MoodBasedRecommendationsScreen> createState() =>
      _MoodBasedRecommendationsScreenState();
}

class _MoodBasedRecommendationsScreenState
    extends State<MoodBasedRecommendationsScreen> {
  String _selectedMood = '';
  bool _isLoading = false;
  Map<String, dynamic> _recommendations = {};

  final List<Map<String, dynamic>> _moods = [
    {
      'name': 'Energetic',
      'icon': Icons.bolt,
      'color': Colors.orange,
      'description': 'Full of energy and ready to tackle challenging work',
    },
    {
      'name': 'Focused',
      'icon': Icons.center_focus_strong,
      'color': Colors.indigo,
      'description': 'In the zone and able to concentrate deeply',
    },
    {
      'name': 'Creative',
      'icon': Icons.lightbulb,
      'color': Colors.purple,
      'description': 'Feeling imaginative and inspired',
    },
    {
      'name': 'Tired',
      'icon': Icons.bedtime,
      'color': Colors.blueGrey,
      'description': 'Low energy and needing gentle study approaches',
    },
    {
      'name': 'Anxious',
      'icon': Icons.healing,
      'color': Colors.teal,
      'description': 'Feeling stressed or worried about performance',
    },
    {
      'name': 'Distracted',
      'icon': Icons.filter_center_focus,
      'color': Colors.amber,
      'description': 'Having trouble maintaining attention',
    },
    {
      'name': 'Motivated',
      'icon': Icons.rocket_launch,
      'color': Colors.green,
      'description': 'Driven and determined to make progress',
    }
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialRecommendations();
  }

  Future<void> _loadInitialRecommendations() async {
    // Just to show the default state
    _recommendations = await AIService.getMoodBasedRecommendations('');
    setState(() {});
  }

  Future<void> _getMoodRecommendations(String mood) async {
    setState(() {
      _selectedMood = mood;
      _isLoading = true;
    });

    try {
      final recommendations = await AIService.getMoodBasedRecommendations(mood);
      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting recommendations: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood-Based Study Recommendations'),
        backgroundColor: _selectedMood.isNotEmpty
            ? _moods
                .firstWhere(
                  (mood) => mood['name'].toLowerCase() == _selectedMood.toLowerCase(),
                  orElse: () => {'color': Theme.of(context).primaryColor},
                )['color']
            : Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Mood selection section
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How are you feeling today?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Select your current mood to get personalized study recommendations',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _moods.length,
                    itemBuilder: (context, index) {
                      final mood = _moods[index];
                      final isSelected =
                          _selectedMood.toLowerCase() == mood['name'].toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: InkWell(
                          onTap: () => _getMoodRecommendations(mood['name']),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 80,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? mood['color'].withOpacity(0.2)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? mood['color']
                                    : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  mood['icon'],
                                  color: mood['color'],
                                  size: 28,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  mood['name'],
                                  style: TextStyle(
                                    color: isSelected
                                        ? mood['color']
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Divider
          const Divider(height: 1),

          // Recommendations section
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Title and description
                  Text(
                    _recommendations['title'] ??
                        'Select a mood for personalized recommendations',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _selectedMood.isNotEmpty
                              ? Color(_recommendations['moodColor'] ??
                                  Theme.of(context).primaryColor.value)
                              : Theme.of(context).primaryColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _recommendations['description'] ?? '',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),

                  // Study approach
                  _buildSectionCard(
                    'Study Approach',
                    _recommendations['studyApproach'] ?? '',
                    Icons.school,
                    _selectedMood.isNotEmpty
                        ? Color(_recommendations['moodColor'] ??
                            Theme.of(context).primaryColor.value)
                        : Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),

                  // Recommended subjects
                  _buildListCard(
                    'Recommended Subjects',
                    _recommendations['recommendedSubjects'] ?? [],
                    Icons.book,
                    _selectedMood.isNotEmpty
                        ? Color(_recommendations['moodColor'] ??
                            Theme.of(context).primaryColor.value)
                        : Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),

                  // Recommended environment
                  _buildSectionCard(
                    'Study Environment',
                    _recommendations['recommendedEnvironment'] ?? '',
                    Icons.home_work,
                    _selectedMood.isNotEmpty
                        ? Color(_recommendations['moodColor'] ??
                            Theme.of(context).primaryColor.value)
                        : Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),

                  // Recommended techniques
                  _buildListCard(
                    'Recommended Techniques',
                    _recommendations['recommendedTechniques'] ?? [],
                    Icons.psychology,
                    _selectedMood.isNotEmpty
                        ? Color(_recommendations['moodColor'] ??
                            Theme.of(context).primaryColor.value)
                        : Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),

                  // Apply button
                  ElevatedButton(
                    onPressed: _selectedMood.isNotEmpty
                        ? () {
                            // Save these recommendations or apply them to study plan
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Recommendations saved to your study plan'),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedMood.isNotEmpty
                          ? Color(_recommendations['moodColor'] ??
                              Theme.of(context).primaryColor.value)
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Apply to My Study Plan'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
      String title, String content, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(
      String title, List<dynamic> items, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, size: 18, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.toString(),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}