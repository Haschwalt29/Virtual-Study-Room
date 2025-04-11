import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'theme_provider.dart';

class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controller for new task input
  final TextEditingController _taskController = TextEditingController();

  // Tasks list and loading state
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;

  // Task stats
  int _totalTasks = 0;
  int _completedTasks = 0;

  // Stream subscription
  StreamSubscription<QuerySnapshot>? _tasksSubscription;

  @override
  void initState() {
    super.initState();
    // Load tasks without requiring a composite index
    _loadTasks();
  }

  // Load tasks without requiring composite index
  void _loadTasks() {
    try {
      // Cancel any existing subscription
      _tasksSubscription?.cancel();

      // Simple query that doesn't require composite index
      final tasksQuery = _firestore
          .collection('tasks')
          .where('userId', isEqualTo: _auth.currentUser?.uid);

      // Subscribe to query
      _tasksSubscription = tasksQuery.snapshots().listen(
        (snapshot) {
          if (mounted) {
            // Sort the tasks in memory instead of in the query
            final taskDocs = snapshot.docs;
            final List<Map<String, dynamic>> tasks = [];

            for (var doc in taskDocs) {
              final data = doc.data() as Map<String, dynamic>;
              tasks.add({'id': doc.id, ...data});
            }

            // Sort manually by createdAt
            tasks.sort((a, b) {
              final aTime = a['createdAt'] as Timestamp?;
              final bTime = b['createdAt'] as Timestamp?;

              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1; // Null timestamps at the end
              if (bTime == null) return -1;

              // Sort descending (newest first)
              return bTime.compareTo(aTime);
            });

            setState(() {
              _tasks = tasks;
              _totalTasks = tasks.length;
              _completedTasks =
                  tasks.where((task) => task['isCompleted'] == true).length;
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          print('Error loading tasks: $error');
          setState(() {
            _isLoading = false;
          });

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading tasks. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    } catch (e) {
      print('Error setting up tasks listener: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Calculate progress percentage
  double get _progressPercentage {
    if (_totalTasks == 0) return 0.0;
    return _completedTasks / _totalTasks;
  }

  // Add a new task
  Future<void> _addTask() async {
    if (_taskController.text.trim().isEmpty) return;

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        setState(() {
          _isLoading = true;
        });

        await _firestore.collection('tasks').add({
          'name': _taskController.text.trim(),
          'isCompleted': false,
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        _taskController.clear();

        // Tasks will update automatically via listener
      }
    } catch (e) {
      print('Error adding task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding task: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Toggle task completion status
  Future<void> _toggleTaskStatus(String taskId, bool currentStatus) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'isCompleted': !currentStatus,
      });

      // Tasks will update automatically via listener
    } catch (e) {
      print('Error updating task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Delete a task
  Future<void> _deleteTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();
      // Tasks will update automatically via listener
    } catch (e) {
      print('Error deleting task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Build the progress section
  Widget _buildProgressSection() {
    return Container(
      padding: EdgeInsets.all(16.0),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Task Progress",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "${(_progressPercentage * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progressPercentage,
              minHeight: 12,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Completed: $_completedTasks",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                "Total: $_totalTasks",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build the task list
  Widget _buildTaskList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment, size: 72, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No tasks yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Add your first task by tapping the + button below',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        final taskId = task['id'];
        final isCompleted = task['isCompleted'] ?? false;

        return Card(
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            leading: Checkbox(
              value: isCompleted,
              activeColor: Colors.orangeAccent,
              onChanged: (value) => _toggleTaskStatus(taskId, isCompleted),
            ),
            title: Text(
              task['name'] ?? 'Untitled Task',
              style: TextStyle(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey : null,
              ),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red[300]),
              onPressed: () => _deleteTask(taskId),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Tasks & Progress"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: "Refresh stats",
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildProgressSection(),
          ),

          // Task list header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  "My Tasks",
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
                    "$_totalTasks",
                    style: TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Task list
          Expanded(child: _buildTaskList()),

          // Task input
          Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color:
                  themeProvider.isDarkMode
                      ? Theme.of(context).cardColor
                      : Colors.grey[100],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(
                      hintText: 'Add a new task...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor:
                          themeProvider.isDarkMode
                              ? Colors.grey[800]
                              : Colors.white,
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepOrange.shade700,
                        Colors.orange.shade500,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add, color: Colors.white),
                    onPressed: _addTask,
                    tooltip: "Add task",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
