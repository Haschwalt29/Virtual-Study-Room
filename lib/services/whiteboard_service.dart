import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

/// Model class to represent a single stroke point on the whiteboard
class StrokePoint {
  final double x;
  final double y;
  final Color color;
  final double width;
  final String userId;
  final int timestamp;
  final bool isEraser;

  StrokePoint({
    required this.x,
    required this.y,
    required this.color,
    required this.width,
    required this.userId,
    required this.timestamp,
    this.isEraser = false,
  });

  /// Convert StrokePoint to a Map for storing in Firebase
  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'color': color.value,
      'width': width,
      'userId': userId,
      'timestamp': timestamp,
      'isEraser': isEraser,
    };
  }

  /// Create a StrokePoint from a Map retrieved from Firebase
  factory StrokePoint.fromMap(Map<String, dynamic> map) {
    return StrokePoint(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      color: Color(map['color'] as int),
      width: (map['width'] as num).toDouble(),
      userId: map['userId'] as String,
      timestamp: map['timestamp'] as int,
      isEraser: map['isEraser'] as bool? ?? false,
    );
  }
}

/// Model class to represent a complete stroke (series of connected points)
class Stroke {
  final String id;
  final List<StrokePoint> points;
  final String userId;
  final int startTime;

  Stroke({
    required this.id,
    required this.points,
    required this.userId,
    required this.startTime,
  });

  /// Convert Stroke to a Map for storing in Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'points': points.map((point) => point.toMap()).toList(),
      'userId': userId,
      'startTime': startTime,
    };
  }

  /// Create a Stroke from a Map retrieved from Firebase
  factory Stroke.fromMap(String key, Map<String, dynamic> map) {
    final pointsList = (map['points'] as List<dynamic>?)?.map((point) {
      return StrokePoint.fromMap(Map<String, dynamic>.from(point as Map));
    }).toList() ?? [];

    return Stroke(
      id: key,
      points: pointsList,
      userId: map['userId'] as String? ?? 'unknown',
      startTime: map['startTime'] as int? ?? 0,
    );
  }
}

/// Service for handling collaborative whiteboard using Firebase Realtime Database
class WhiteboardService {
  final FirebaseDatabase _database;
  final FirebaseAuth _auth;
  final String roomId;

  /// List of all strokes currently on the whiteboard
  List<Stroke> strokes = [];

  /// The current stroke being drawn (not yet committed to Firebase)
  Stroke? currentStroke;

  /// Stream controller to broadcast stroke updates to listeners
  final StreamController<List<Stroke>> _strokesController = StreamController<List<Stroke>>.broadcast();

  /// Stream of strokes for listeners to subscribe to
  Stream<List<Stroke>> get strokesStream => _strokesController.stream;

  /// Current drawing settings
  Color currentColor = Colors.black;
  double currentWidth = 3.0;
  bool isEraser = false;

  /// Database reference for the strokes
  late DatabaseReference _strokesRef;

  /// Subscription to Firebase events
  StreamSubscription? _strokesSubscription;

  /// Create a new WhiteboardService instance
  ///
  /// Requires a [roomId] to identify which room's whiteboard to sync
  WhiteboardService({
    required this.roomId,
    FirebaseDatabase? database,
    FirebaseAuth? auth,
  }) : 
    _database = database ?? FirebaseDatabase.instance,
    _auth = auth ?? FirebaseAuth.instance {
    
    // Initialize database reference
    _strokesRef = _database.ref().child('whiteboards').child(roomId).child('strokes');
    
    // Load existing strokes and listen for changes
    _initWhiteboard();
  }

  /// Initialize the whiteboard by loading existing strokes and setting up listeners
  void _initWhiteboard() {
    // Listen for changes to the strokes
    _strokesSubscription = _strokesRef.onValue.listen((event) {
      if (event.snapshot.value == null) return;

      try {
        final Map<dynamic, dynamic> strokesData = event.snapshot.value as Map;
        final List<Stroke> loadedStrokes = [];

        strokesData.forEach((key, value) {
          if (value is Map) {
            try {
              final strokeMap = Map<String, dynamic>.from(value as Map);
              loadedStrokes.add(Stroke.fromMap(key.toString(), strokeMap));
            } catch (e) {
              print('Error parsing stroke $key: $e');
            }
          }
        });

        // Sort strokes by start time to ensure correct drawing order
        loadedStrokes.sort((a, b) => a.startTime.compareTo(b.startTime));

        // Update strokes list and notify listeners
        strokes = loadedStrokes;
        _strokesController.add(strokes);
      } catch (e) {
        print('Error loading strokes: $e');
      }
    }, onError: (error) {
      print('Error listening to strokes: $error');
    });
  }

  /// Start a new stroke at the given position
  void startStroke(Offset position) {
    final userId = _auth.currentUser?.uid ?? 'anonymous';
    final now = DateTime.now().millisecondsSinceEpoch;
    final strokeId = 'stroke_${userId}_$now';

    final point = StrokePoint(
      x: position.dx,
      y: position.dy,
      color: isEraser ? Colors.white : currentColor,
      width: isEraser ? currentWidth * 3 : currentWidth, // Make eraser wider
      userId: userId,
      timestamp: now,
      isEraser: isEraser,
    );

    currentStroke = Stroke(
      id: strokeId,
      points: [point],
      userId: userId,
      startTime: now,
    );
  }

  /// Add a point to the current stroke
  void addPointToStroke(Offset position) {
    if (currentStroke == null) return;

    final userId = _auth.currentUser?.uid ?? 'anonymous';
    final now = DateTime.now().millisecondsSinceEpoch;

    final point = StrokePoint(
      x: position.dx,
      y: position.dy,
      color: isEraser ? Colors.white : currentColor,
      width: isEraser ? currentWidth * 3 : currentWidth, // Make eraser wider
      userId: userId,
      timestamp: now,
      isEraser: isEraser,
    );

    currentStroke!.points.add(point);
    
    // We don't update Firebase yet - we'll do that when the stroke is complete
    // But we do notify local listeners for immediate feedback
    _strokesController.add([...strokes, currentStroke!]);
  }

  /// End the current stroke and save it to Firebase
  Future<void> endStroke() async {
    if (currentStroke == null || currentStroke!.points.isEmpty) return;

    try {
      // Add the stroke to the local list
      strokes.add(currentStroke!);
      
      // Save the stroke to Firebase
      await _strokesRef.child(currentStroke!.id).set(currentStroke!.toMap());
      
      // Reset the current stroke
      currentStroke = null;
    } catch (e) {
      print('Error saving stroke: $e');
    }
  }

  /// Clear the whiteboard (remove all strokes)
  Future<void> clearWhiteboard() async {
    try {
      // Clear local strokes
      strokes.clear();
      currentStroke = null;
      
      // Notify listeners
      _strokesController.add(strokes);
      
      // Clear strokes in Firebase
      await _strokesRef.remove();
    } catch (e) {
      print('Error clearing whiteboard: $e');
    }
  }

  /// Set the current drawing color
  void setColor(Color color) {
    currentColor = color;
    isEraser = false;
  }

  /// Set the current stroke width
  void setStrokeWidth(double width) {
    currentWidth = width;
  }

  /// Enable eraser mode
  void enableEraser() {
    isEraser = true;
  }

  /// Dispose resources
  void dispose() {
    _strokesSubscription?.cancel();
    _strokesController.close();
  }
}