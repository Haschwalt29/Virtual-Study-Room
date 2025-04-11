import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/whiteboard_service.dart';
import '../theme_provider.dart';

/// Custom painter to render whiteboard strokes on the canvas
class WhiteboardPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? currentStroke;

  WhiteboardPainter({
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all committed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw the current stroke being drawn
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  /// Draw a single stroke on the canvas
  void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    // Draw each segment of the stroke
    for (int i = 0; i < stroke.points.length - 1; i++) {
      final point = stroke.points[i];
      final nextPoint = stroke.points[i + 1];
      
      final paint = Paint()
        ..color = point.isEraser ? Colors.white : point.color
        ..strokeWidth = point.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      
      // Draw line between points
      canvas.drawLine(
        Offset(point.x, point.y),
        Offset(nextPoint.x, nextPoint.y),
        paint,
      );
      
      // Draw a small circle at each point for smoother appearance
      canvas.drawCircle(
        Offset(point.x, point.y),
        point.width / 2,
        paint,
      );
    }
    
    // Draw the last point
    if (stroke.points.isNotEmpty) {
      final lastPoint = stroke.points.last;
      final paint = Paint()
        ..color = lastPoint.isEraser ? Colors.white : lastPoint.color
        ..strokeWidth = lastPoint.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      canvas.drawCircle(
        Offset(lastPoint.x, lastPoint.y),
        lastPoint.width / 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WhiteboardPainter oldDelegate) {
    // Repaint if strokes have changed or current stroke is different
    return oldDelegate.strokes != strokes || 
           oldDelegate.currentStroke != currentStroke;
  }
}

/// Widget for collaborative whiteboard functionality
class WhiteboardWidget extends StatefulWidget {
  final String roomId;

  const WhiteboardWidget({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  @override
  _WhiteboardWidgetState createState() => _WhiteboardWidgetState();
}

class _WhiteboardWidgetState extends State<WhiteboardWidget> {
  late WhiteboardService _whiteboardService;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Available colors for the color palette
  final List<Color> _colors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
  ];
  
  // Available stroke widths
  final List<double> _strokeWidths = [1.0, 3.0, 5.0, 8.0];
  
  // Current selected values
  Color _selectedColor = Colors.black;
  double _selectedWidth = 3.0;
  bool _isEraserSelected = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  /// Initialize the whiteboard service
  void _initializeService() {
    try {
      _whiteboardService = WhiteboardService(roomId: widget.roomId);
      
      // Set default drawing settings
      _whiteboardService.setColor(_selectedColor);
      _whiteboardService.setStrokeWidth(_selectedWidth);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error initializing whiteboard: $e';
      });
      print('Error initializing whiteboard: $e');
    }
  }

  @override
  void dispose() {
    _whiteboardService.dispose();
    super.dispose();
  }

  /// Handle selecting a color from the palette
  void _selectColor(Color color) {
    setState(() {
      _selectedColor = color;
      _isEraserSelected = false;
    });
    _whiteboardService.setColor(color);
  }

  /// Handle selecting a stroke width
  void _selectStrokeWidth(double width) {
    setState(() {
      _selectedWidth = width;
    });
    _whiteboardService.setStrokeWidth(width);
  }

  /// Handle selecting the eraser tool
  void _selectEraser() {
    setState(() {
      _isEraserSelected = true;
    });
    _whiteboardService.enableEraser();
  }

  /// Handle clearing the whiteboard
  void _clearWhiteboard() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Whiteboard'),
        content: Text('Are you sure you want to clear the entire whiteboard? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _whiteboardService.clearWhiteboard();
              Navigator.pop(context);
            },
            child: Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
        // Header with info about the whiteboard
        Container(
          padding: EdgeInsets.all(12),
          width: double.infinity,
          color: themeProvider.isDarkMode
              ? Colors.blueGrey.shade800
              : Colors.blue.shade50,
          child: Row(
            children: [
              Icon(
                Icons.gesture,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Collaborative Whiteboard - Draw together in real-time',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Whiteboard tools
        Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: themeProvider.isDarkMode
              ? Colors.grey.shade900
              : Colors.grey.shade200,
          child: Row(
            children: [
              // Color palette
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final color in _colors)
                        InkWell(
                          onTap: () => _selectColor(color),
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == color && !_isEraserSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey,
                                width: _selectedColor == color && !_isEraserSelected ? 3 : 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: 16),

              // Stroke width selector
              DropdownButton<double>(
                value: _selectedWidth,
                icon: Icon(Icons.arrow_drop_down),
                underline: Container(
                  height: 2,
                  color: Theme.of(context).primaryColor,
                ),
                onChanged: (double? newValue) {
                  if (newValue != null) {
                    _selectStrokeWidth(newValue);
                  }
                },
                items: _strokeWidths.map<DropdownMenuItem<double>>((width) {
                  return DropdownMenuItem<double>(
                    value: width,
                    child: Text('${width.toInt()} px'),
                  );
                }).toList(),
              ),

              SizedBox(width: 16),

              // Eraser button
              IconButton(
                icon: Icon(
                  Icons.auto_fix_high,
                  color: _isEraserSelected
                      ? Theme.of(context).primaryColor
                      : themeProvider.isDarkMode
                          ? Colors.white70
                          : Colors.black54,
                ),
                tooltip: 'Eraser',
                onPressed: _selectEraser,
              ),

              // Clear button
              IconButton(
                icon: Icon(Icons.delete_outline),
                tooltip: 'Clear Whiteboard',
                onPressed: _clearWhiteboard,
              ),
            ],
          ),
        ),

        // Main whiteboard area
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.white, // Whiteboard is always white
            child: StreamBuilder<List<Stroke>>(
              stream: _whiteboardService.strokesStream,
              initialData: _whiteboardService.strokes,
              builder: (context, snapshot) {
                final strokes = snapshot.data ?? [];
                
                return GestureDetector(
                  onPanStart: (details) {
                    final localPosition = details.localPosition;
                    _whiteboardService.startStroke(localPosition);
                  },
                  onPanUpdate: (details) {
                    final localPosition = details.localPosition;
                    _whiteboardService.addPointToStroke(localPosition);
                  },
                  onPanEnd: (details) {
                    _whiteboardService.endStroke();
                  },
                  child: CustomPaint(
                    painter: WhiteboardPainter(
                      strokes: strokes,
                      currentStroke: _whiteboardService.currentStroke,
                    ),
                    child: Container(), // Empty container for gesture detection
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}