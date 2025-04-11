import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Service for handling collaborative note editing using Firebase Firestore.
/// 
/// This service manages real-time syncing of notes between multiple users
/// in a study room using Firestore as the backend.
class SharedNotesService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final String roomId;
  
  /// Debounce timer to prevent excessive Firestore writes
  Timer? _debounceTimer;
  
  /// To track the last update source to prevent update loops
  String? _lastUpdateId;
  
  /// Controller for the text field
  late TextEditingController notesController;
  
  /// Stream subscription for Firestore updates
  StreamSubscription<DocumentSnapshot>? _notesSubscription;
  
  /// Create a new SharedNotesService instance
  ///
  /// Requires a [roomId] to identify which room's notes to sync
  SharedNotesService({
    required this.roomId,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : 
    _firestore = firestore ?? FirebaseFirestore.instance,
    _auth = auth ?? FirebaseAuth.instance {
    // Initialize the text controller
    notesController = TextEditingController();
    
    // Set up document reference path
    // Listen for changes to the notes document
    _initNotes();
  }
  
  /// Initialize notes by setting up listeners and loading initial data
  void _initNotes() async {
    try {
      // First, check if the note document exists
      final docRef = _getNotesDocRef();
      final doc = await docRef.get();
      
      // Create the document if it doesn't exist
      if (!doc.exists) {
        await docRef.set({
          'content': '',
          'lastUpdated': FieldValue.serverTimestamp(),
          'lastUpdatedBy': _auth.currentUser?.uid ?? 'anonymous',
        });
      } 
      // Otherwise, load the existing content
      else {
        final data = doc.data() as Map<String, dynamic>;
        final content = data['content'] as String? ?? '';
        notesController.text = content;
      }
      
      // Set up listener for remote changes
      _listenToNotes();
      
      // Set up listener for local changes
      _listenToController();
      
    } catch (e) {
      print('Error initializing notes: $e');
    }
  }
  
  /// Returns the Firestore document reference for the notes document
  DocumentReference _getNotesDocRef() {
    return _firestore
        .collection('studyRooms')
        .doc(roomId)
        .collection('roomData')
        .doc('notes');
  }
  
  /// Listen to note changes from Firestore and update the controller
  void _listenToNotes() {
    final docRef = _getNotesDocRef();
    
    _notesSubscription = docRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) return;
      
      final data = snapshot.data() as Map<String, dynamic>;
      final content = data['content'] as String? ?? '';
      final updatedBy = data['lastUpdatedBy'] as String? ?? '';
      
      // Generate a unique identifier for this update
      final updateId = '${DateTime.now().millisecondsSinceEpoch}-$updatedBy';
      
      // If this update was triggered by our own write, ignore it
      if (updateId == _lastUpdateId) return;
      
      // If this is from another user, update the controller without triggering our listener
      if (updatedBy != _auth.currentUser?.uid) {
        // Temporarily remove our listener to prevent loops
        notesController.removeListener(_onLocalTextChanged);
        
        // Update the controller
        notesController.value = TextEditingValue(
          text: content,
          selection: TextSelection.collapsed(offset: content.length),
        );
        
        // Re-add our listener
        notesController.addListener(_onLocalTextChanged);
      }
    }, onError: (error) {
      print('Error listening to notes: $error');
    });
  }
  
  /// Listen to local text changes and update Firestore after debouncing
  void _listenToController() {
    notesController.addListener(_onLocalTextChanged);
  }
  
  /// Handle local text changes
  void _onLocalTextChanged() {
    // Cancel previous timer if it exists
    _debounceTimer?.cancel();
    
    // Set a new timer to debounce updates
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      _updateNotesInFirestore(notesController.text);
    });
  }
  
  /// Update the notes in Firestore
  Future<void> _updateNotesInFirestore(String content) async {
    try {
      // Generate a unique identifier for this update
      final currentUserId = _auth.currentUser?.uid ?? 'anonymous';
      _lastUpdateId = '${DateTime.now().millisecondsSinceEpoch}-$currentUserId';
      
      // Update the document
      await _getNotesDocRef().set({
        'content': content,
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastUpdatedBy': currentUserId,
      });
    } catch (e) {
      print('Error updating notes: $e');
    }
  }
  
  /// Dispose resources
  void dispose() {
    _debounceTimer?.cancel();
    _notesSubscription?.cancel();
    notesController.dispose();
  }
}