import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/shared_notes_service.dart';
import '../theme_provider.dart';

/// Widget for displaying and interacting with collaborative shared notes
class SharedNotesWidget extends StatefulWidget {
  final String roomId;

  const SharedNotesWidget({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  @override
  _SharedNotesWidgetState createState() => _SharedNotesWidgetState();
}

class _SharedNotesWidgetState extends State<SharedNotesWidget> {
  late SharedNotesService _notesService;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  /// Initialize the shared notes service
  void _initializeService() {
    try {
      _notesService = SharedNotesService(roomId: widget.roomId);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error initializing shared notes: $e';
      });
      print('Error initializing shared notes: $e');
    }
  }

  @override
  void dispose() {
    _notesService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _initializeService();
              },
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with info about collaborative editing
        Container(
          padding: EdgeInsets.all(12),
          width: double.infinity,
          color: themeProvider.isDarkMode
              ? Colors.blueGrey.shade800
              : Colors.blue.shade50,
          child: Row(
            children: [
              Icon(
                Icons.groups,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Collaborative Notes - All changes are synchronized in real-time',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Main notes area
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _notesService.notesController,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Start typing your shared notes here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: themeProvider.isDarkMode 
                        ? Colors.grey.shade700 
                        : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: themeProvider.isDarkMode 
                    ? Colors.grey.shade900 
                    : Colors.grey.shade50,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
        ),

        // Footer with editing tips
        Container(
          padding: EdgeInsets.all(8),
          width: double.infinity,
          color: themeProvider.isDarkMode
              ? Colors.grey.shade900
              : Colors.grey.shade200,
          child: Center(
            child: Text(
              'Changes are saved automatically after you stop typing',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}