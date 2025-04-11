import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/shared_notes_widget.dart';
import 'widgets/whiteboard_widget.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'pomodoro_timer_screen.dart';
import 'theme_provider.dart';

// HMS SDK interactor class without late initialization errors
class HMSSDKInteractor {
  // Nullable variables instead of late
  HMSSDK? _hmsSDK;
  HMSUpdateListenerImpl? _updateListener;
  bool _isInitialized = false;

  // State accessor
  bool get isInitialized =>
      _isInitialized && _hmsSDK != null && _updateListener != null;

  // Initialize with better error handling
  Future<bool> initialize() async {
    try {
      // Create new instances to avoid partial initialization state
      final sdk = HMSSDK();

      // Build the SDK (required before any operations)
      await sdk.build();

      // Create the update listener only after SDK is fully built
      final listener = HMSUpdateListenerImpl();

      // Only assign to instance variables after successful initialization
      _hmsSDK = sdk;
      _updateListener = listener;
      _isInitialized = true;

      print("HMS SDK initialized successfully");
      return true;
    } catch (e) {
      print("Error initializing HMS SDK: $e");
      _hmsSDK = null;
      _updateListener = null;
      _isInitialized = false;
      return false;
    }
  }

  // Join with better error handling
  Future<bool> join({
    required String authToken,
    required String username,
    required Function(HMSRoom) onJoin,
    required Function(HMSPeer, HMSPeerUpdate) onPeerUpdate,
    required Function(HMSTrack, HMSTrackUpdate, HMSPeer) onTrackUpdate,
    required Function(HMSException) onError,
  }) async {
    // Verify initialization status
    if (!isInitialized || _hmsSDK == null || _updateListener == null) {
      print("HMS SDK not properly initialized. Cannot join.");
      return false;
    }

    try {
      // Set callbacks in the listener (null-safe)
      _updateListener!.onJoinCallback = onJoin;
      _updateListener!.onPeerUpdateCallback = onPeerUpdate;
      _updateListener!.onTrackUpdateCallback = onTrackUpdate;
      _updateListener!.onErrorCallback = onError;

      // Create config and add listener
      HMSConfig config = HMSConfig(authToken: authToken, userName: username);

      // Add listener with proper null checks
      _hmsSDK!.addUpdateListener(listener: _updateListener!);

      // Join the room
      await _hmsSDK!.join(config: config);
      return true;
    } catch (e) {
      print("Error joining HMS room: $e");
      return false;
    }
  }

  Future<void> leave() async {
    if (!isInitialized || _hmsSDK == null) return;
    await _hmsSDK!.leave();
  }

  Future<void> switchAudio({required bool isOn}) async {
    if (!isInitialized || _hmsSDK == null) return;
    await _hmsSDK!.switchAudio(isOn: isOn);
  }

  Future<void> switchVideo({required bool isOn}) async {
    if (!isInitialized || _hmsSDK == null) return;
    await _hmsSDK!.switchVideo(isOn: isOn);
  }

  Future<void> startScreenShare() async {
    if (!isInitialized || _hmsSDK == null) return;
    try {
      await _hmsSDK!.startScreenShare();
    } catch (e) {
      print('Error starting screen share: $e');
    }
  }

  Future<void> stopScreenShare() async {
    if (!isInitialized || _hmsSDK == null) return;
    try {
      _hmsSDK!.stopScreenShare(hmsActionResultListener: null);
    } catch (e) {
      print('Error stopping screen share: $e');
    }
  }

  void destroy() {
    if (_hmsSDK != null && _updateListener != null && isInitialized) {
      try {
        _hmsSDK!.removeUpdateListener(listener: _updateListener!);
        _hmsSDK!.destroy();
      } catch (e) {
        print("Error destroying HMS SDK: $e");
      }

      // Reset state
      _hmsSDK = null;
      _updateListener = null;
      _isInitialized = false;
    }
  }

  Future<List<HMSPeer>> getAllPeers() async {
    if (!isInitialized || _hmsSDK == null) return [];
    try {
      final peers = await _hmsSDK!.getPeers();
      return peers ?? [];
    } catch (e) {
      print('Error getting peers: $e');
      return [];
    }
  }

  Future<HMSPeer?> getLocalPeer() async {
    if (!isInitialized || _hmsSDK == null) return null;
    try {
      final localPeer = await _hmsSDK!.getLocalPeer();
      return localPeer;
    } catch (e) {
      print('Error getting local peer: $e');
      return null;
    }
  }

  // Mute all remote participants for Silent Study Mode
  Future<void> muteAllRemoteParticipants() async {
    if (!isInitialized || _hmsSDK == null) return;
    try {
      final allPeers = await getAllPeers();
      final localPeer = await getLocalPeer();

      for (final peer in allPeers) {
        // Skip the local peer
        if (peer.isLocal ||
            (localPeer != null && peer.peerId == localPeer.peerId))
          continue;

        // Mute this remote peer if they have an audio track
        if (peer.audioTrack != null) {
          await _hmsSDK!.changeTrackState(
            forRemoteTrack: peer.audioTrack!,
            mute: true,
          );
        }
      }
    } catch (e) {
      print('Error muting all remote participants: $e');
    }
  }
}

// Implementation of the HMS update listener
class HMSUpdateListenerImpl extends HMSUpdateListener {
  Function(HMSRoom)? onJoinCallback;
  Function(HMSPeer, HMSPeerUpdate)? onPeerUpdateCallback;
  Function(HMSTrack, HMSTrackUpdate, HMSPeer)? onTrackUpdateCallback;
  Function(HMSException)? onErrorCallback;
  Function(HMSRoom, HMSRoomUpdate)? onRoomUpdateCallback;
  Function(HMSMessage)? onMessageCallback;
  Function()? onReconnectedCallback;
  Function()? onReconnectingCallback;
  Function(HMSRoleChangeRequest)? onRoleChangeRequestCallback;
  Function(HMSPeerRemovedFromPeer)? onRemovedFromRoomCallback;

  @override
  void onJoin({required HMSRoom room}) {
    if (onJoinCallback != null) {
      onJoinCallback!(room);
    }
  }

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    if (onPeerUpdateCallback != null) {
      onPeerUpdateCallback!(peer, update);
    }
  }

  @override
  void onTrackUpdate({
    required HMSTrack track,
    required HMSTrackUpdate trackUpdate,
    required HMSPeer peer,
  }) {
    if (onTrackUpdateCallback != null) {
      onTrackUpdateCallback!(track, trackUpdate, peer);
    }
  }

  @override
  void onError({required HMSException error}) {
    if (onErrorCallback != null) {
      onErrorCallback!(error);
    }
  }

  @override
  void onRoomUpdate({required HMSRoom room, required HMSRoomUpdate update}) {
    if (onRoomUpdateCallback != null) {
      onRoomUpdateCallback!(room, update);
    }
  }

  @override
  void onMessage({required HMSMessage message}) {
    if (onMessageCallback != null) {
      onMessageCallback!(message);
    }
  }

  @override
  void onReconnected() {
    if (onReconnectedCallback != null) {
      onReconnectedCallback!();
    }
  }

  @override
  void onReconnecting() {
    if (onReconnectingCallback != null) {
      onReconnectingCallback!();
    }
  }

  @override
  void onRoleChangeRequest({required HMSRoleChangeRequest roleChangeRequest}) {
    if (onRoleChangeRequestCallback != null) {
      onRoleChangeRequestCallback!(roleChangeRequest);
    }
  }

  @override
  void onRemovedFromRoom({
    required HMSPeerRemovedFromPeer hmsPeerRemovedFromPeer,
  }) {
    if (onRemovedFromRoomCallback != null) {
      onRemovedFromRoomCallback!(hmsPeerRemovedFromPeer);
    }
  }

  // Implement missing required methods
  @override
  void onAudioDeviceChanged({
    HMSAudioDevice? currentAudioDevice,
    List<HMSAudioDevice>? availableAudioDevice,
  }) {
    // Handle audio device changes
    if (currentAudioDevice != null) {
      print('Audio device changed: $currentAudioDevice');
    }
  }

  @override
  void onChangeTrackStateRequest({
    required HMSTrackChangeRequest hmsTrackChangeRequest,
  }) {
    // Handle track state change requests
    print('Track state change requested: ${hmsTrackChangeRequest.toString()}');
  }

  @override
  void onHMSError({required HMSException error}) {
    // This is for backward compatibility
    onError(error: error);
  }

  @override
  void onPeerListUpdate({
    required List<HMSPeer> addedPeers,
    required List<HMSPeer> removedPeers,
  }) {
    // Handle updates to the peer list
    print(
      'Peers added: ${addedPeers.length}, Peers removed: ${removedPeers.length}',
    );
  }

  @override
  void onSessionStoreAvailable({HMSSessionStore? hmsSessionStore}) {
    // Handle session store availability
    if (hmsSessionStore != null) {
      print('Session store available');
    }
  }

  @override
  void onUpdateSpeakers({required List<HMSSpeaker> updateSpeakers}) {
    // Handle active speakers updates
    if (updateSpeakers.isNotEmpty) {
      print(
        'Active speakers: ${updateSpeakers.map((s) => s.peer.name).join(', ')}',
      );
    }
  }
}

class StudyRoomScreen extends StatefulWidget {
  final String roomId;

  const StudyRoomScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  _StudyRoomScreenState createState() => _StudyRoomScreenState();
}

class _StudyRoomScreenState extends State<StudyRoomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Streams for room data
  late Stream<DocumentSnapshot> _roomStream;
  late Stream<QuerySnapshot> _messagesStream;
  late Stream<QuerySnapshot> _participantsStream;

  // Room data
  Map<String, dynamic> _roomDetails = {};
  List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;

  // 100ms SDK variables
  HMSSDKInteractor? _hmsSDKInteractor;
  bool _isVideoOn = true;
  bool _isAudioOn = true;
  bool _isScreenShareOn = false;
  bool _isJoined = false;
  bool _isJoining = false;
  String _errorMessage = '';
  List<HMSPeer> _peers = [];
  HMSPeer? _localPeer;

  // Map to store remote video tracks by peer ID
  Map<String, HMSVideoTrack> _remoteVideoTracks = {};

  // Session tracking for duplicate prevention
  int _joinCount = 0;
  String? _currentSessionId;
  Set<String> _seenPeerIds = {};

  // Debug flags
  bool _showDebugInfo = false; // Set to false to hide debugging information
  List<String> _debugLogs = [];
  String _currentImplementation = 'Initializing...';
  int _sdkInitAttempts = 0;

  // Silent Study Mode state
  bool _isSilentStudyModeOn = false;

  // 100ms credentials (provided by user)
  final String _roomId = '67f5805302936b386a840d42';
  final String _authToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ2ZXJzaW9uIjoyLCJ0eXBlIjoiYXBwIiwiYXBwX2RhdGEiOm51bGwsImFjY2Vzc19rZXkiOiI2N2YzYjhiNTMzY2U3NGFiOWJlOTViMjEiLCJyb2xlIjoiaG9zdCIsInJvb21faWQiOiI2N2Y3ZDQ1MjM2ZDRjZmMxOTgxZjFhMDkiLCJ1c2VyX2lkIjoiNjQyNjNhMjgtMjgyYS00ZmQ3LTk4ZTQtN2ExZDc0NzYzYTBmIiwiZXhwIjoxNzQ0MzgxNDM1LCJqdGkiOiIzZGIzMmFlMi04NjM2LTQ0YjAtOWJmMy02MmM5MmI4NThiZTciLCJpYXQiOjE3NDQyOTUwMzUsImlzcyI6IjY3ZWZjNDk4NDk0NGYwNjczMTNhOTUwMiIsIm5iZiI6MTc0NDI5NTAzNSwic3ViIjoiYXBpIn0.Pl9HMs8qyfimn4-OjR7eYsQbgnGKZdfjTpaNI6jMjdI';

  // Timer variables
  bool _isTimerRunning = false;
  int _timerDuration = 25 * 60; // 25 minutes in seconds (Pomodoro default)
  int _currentTime = 25 * 60;
  Timer? _timer;

  // Text controller for chat
  final TextEditingController _messageController = TextEditingController();

  // Random number generator for participant colors
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Initialize Firestore streams
    _roomStream =
        _firestore.collection('studyRooms').doc(widget.roomId).snapshots();
    _messagesStream =
        _firestore
            .collection('studyRooms')
            .doc(widget.roomId)
            .collection('messages')
            .orderBy('timestamp', descending: false)
            .snapshots();
    _participantsStream =
        _firestore
            .collection('studyRooms')
            .doc(widget.roomId)
            .collection('participants')
            .snapshots();

    // Request permissions
    _requestPermissions();

    // Load initial data
    _loadRoomData();

    // Initialize 100ms SDK instead of WebView
    _initializeHMSSDK();
  }

  // This method will be removed as it's a duplicate

  // WebView controller for fallback solution
  WebViewController? _webViewController;
  bool _useNativeSDK = true;
  bool _fallbackToWebView = false;

  // Initialize WebView Controller (fallback solution)
  void _setupWebViewController() {
    _log("Initializing WebView controller");
    try {
      _webViewController =
          WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(Colors.black)
            ..setNavigationDelegate(
              NavigationDelegate(
                onPageStarted: (String url) {
                  _log('WebView started loading: $url');
                },
                onPageFinished: (String url) {
                  _log('WebView page finished loading: $url');
                  // Inject debug JavaScript
                  if (_showDebugInfo) {
                    _webViewController?.runJavaScript('''
                  console.log = function(message) {
                    if (window.Flutter) {
                      window.Flutter.postMessage("CONSOLE: " + message);
                    }
                    originalConsoleLog.apply(console, arguments);
                  };
                  var originalConsoleLog = console.log;
                  console.log("Debug logging enabled");
                ''');
                  }
                  // Update WebView theme after page loads
                  _updateWebViewTheme();
                  setState(() {
                    _isLoading = false;
                  });
                },
                onWebResourceError: (WebResourceError error) {
                  _log(
                    'WebView error: ${error.description} (${error.errorCode})',
                  );
                  setState(() {
                    _errorMessage =
                        'Error loading conference: ${error.description} (${error.errorCode})';
                  });
                },
              ),
            )
            ..addJavaScriptChannel(
              'Flutter',
              onMessageReceived: (JavaScriptMessage message) {
                _log('From JavaScript: ${message.message}');
                // Process messages from the web page
                if (message.message.startsWith('CONSOLE:')) {
                  _log('JS Console: ${message.message.substring(9)}');
                }
              },
            )
            ..enableZoom(false)
            ..loadHtmlString(_getHtml100msContent(), baseUrl: 'about:blank');

      _log("WebView controller initialized successfully");
    } catch (e) {
      _log("Error initializing WebView controller: $e");
      setState(() {
        _errorMessage = 'WebView initialization error: $e';
      });
    }
  }

  // Logger function for debugging
  void _log(String message) {
    if (_showDebugInfo) {
      print("DEBUG: $message");
      setState(() {
        _debugLogs.add(
          "${DateTime.now().toString().substring(11, 19)}: $message",
        );
        // Keep only last 20 logs
        if (_debugLogs.length > 20) {
          _debugLogs.removeAt(0);
        }
      });
    }
  }

  // Initialize 100ms SDK with robust error handling and WebView fallback
  Future<void> _initializeHMSSDK() async {
    setState(() {
      _errorMessage = '';
      _currentImplementation = 'Initializing native SDK...';
    });

    _log("Starting SDK initialization");

    try {
      // First try the native SDK
      _hmsSDKInteractor = HMSSDKInteractor();
      _useNativeSDK = true;
      _fallbackToWebView = false;
      _log("HMS SDK interactor created");

      // Initialize with retry mechanism
      bool success = false;
      _sdkInitAttempts = 0;
      const maxAttempts = 2; // Reduced attempt count to fail faster to WebView

      while (!success && _sdkInitAttempts < maxAttempts) {
        _sdkInitAttempts++;
        _log("SDK initialization attempt $_sdkInitAttempts");

        try {
          success = await _hmsSDKInteractor!.initialize();
          _log("SDK initialization attempt result: $success");
        } catch (initError) {
          _log("HMS SDK initialization error: $initError");
          // Detailed error reporting
          if (initError.toString().contains("MissingPluginException")) {
            _log("Native plugin not available on this platform");
          }
          success = false;
        }

        if (!success) {
          // Short delay before retry
          _log("Retrying in 500ms...");
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      if (success) {
        _log("Native SDK initialized successfully!");
        setState(() {
          _currentImplementation = 'Using native SDK';
        });
      } else {
        _log(
          "Native 100ms SDK failed to initialize after $_sdkInitAttempts attempts",
        );
        _log("Falling back to WebView implementation");
        // Fall back to WebView approach
        _useNativeSDK = false;
        _fallbackToWebView = true;
        setState(() {
          _currentImplementation = 'Using WebView fallback';
        });
        _initWebViewController();
      }
    } catch (e) {
      _log("Error in _initializeHMSSDK: $e");
      // Fall back to WebView on any error
      _useNativeSDK = false;
      _fallbackToWebView = true;
      setState(() {
        _currentImplementation = 'Using WebView fallback (after error)';
      });
      _initWebViewController();
    }
  }

  // Initialize WebView Controller with enhanced error reporting
  void _initWebViewController() {
    _log("Initializing WebView controller");
    try {
      _webViewController =
          WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(Colors.black)
            ..setNavigationDelegate(
              NavigationDelegate(
                onPageStarted: (String url) {
                  _log('WebView started loading: $url');
                },
                onPageFinished: (String url) {
                  _log('WebView page finished loading: $url');
                  // Inject debug JavaScript
                  if (_showDebugInfo) {
                    _webViewController?.runJavaScript('''
                  console.log = function(message) {
                    if (window.Flutter) {
                      window.Flutter.postMessage("CONSOLE: " + message);
                    }
                    originalConsoleLog.apply(console, arguments);
                  };
                  var originalConsoleLog = console.log;
                  console.log("Debug logging enabled");
                ''');
                  }
                  setState(() {
                    _isLoading = false;
                  });
                },
                onWebResourceError: (WebResourceError error) {
                  _log(
                    'WebView error: ${error.description} (${error.errorCode})',
                  );
                  setState(() {
                    _errorMessage =
                        'Error loading conference: ${error.description} (${error.errorCode})';
                  });
                },
              ),
            )
            ..addJavaScriptChannel(
              'Flutter',
              onMessageReceived: (JavaScriptMessage message) {
                _log('From JavaScript: ${message.message}');
                // Process messages from the web page
                if (message.message.startsWith('CONSOLE:')) {
                  _log('JS Console: ${message.message.substring(9)}');
                }
              },
            )
            ..enableZoom(false)
            ..loadHtmlString(
              _getHtml100msContent(),
              baseUrl: 'https://about:blank',
            );

      _log("WebView controller initialized successfully");
    } catch (e) {
      _log("Error initializing WebView controller: $e");
      setState(() {
        _errorMessage = 'WebView initialization error: $e';
      });
    }
  }

  // Get the 100ms HTML content as a string
  // Escaping JavaScript template literals to prevent Dart interpretation
  String _getHtml100msContent() {
    // HTML content from the 100ms_web.html file
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>100ms Conference</title>
    <style>
        body, html {
            margin: 0;
            padding: 0;
            height: 100%;
            width: 100%;
            overflow: hidden;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, "Open Sans", "Helvetica Neue", sans-serif;
        }
        
        #root {
            height: 100%;
            width: 100%;
            display: flex;
            flex-direction: column;
        }
        
        #conference {
            flex: 1;
            position: relative;
            background-color: #1a1a1a;
        }
        
        #join-screen {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            background-color: white;
            z-index: 10;
        }
        
        #controls {
            display: flex;
            justify-content: space-evenly;
            padding: 10px 0;
            background-color: #333;
        }
        
        .control-button {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            background-color: #555;
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
        }
        
        .red { background-color: #e53935; }
        .green { background-color: #43a047; }
        
        #videos {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 10px;
            padding: 10px;
            height: calc(100% - 60px);
            overflow-y: auto;
        }
        
        .video-container {
            position: relative;
            background-color: #333;
            border-radius: 5px;
            overflow: hidden;
            aspect-ratio: 16/9;
        }
        
        .video-container video {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        
        .participant-name {
            position: absolute;
            bottom: 10px;
            left: 10px;
            color: white;
            background-color: rgba(0, 0, 0, 0.5);
            padding: 3px 6px;
            border-radius: 3px;
            font-size: 12px;
        }
        
        .audio-indicator {
            position: absolute;
            top: 10px;
            right: 10px;
            color: white;
            font-size: 14px;
        }
        
        .avatar {
            width: 80px;
            height: 80px;
            border-radius: 50%;
            background-color: #2196f3;
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 32px;
            font-weight: bold;
        }
        
        .btn {
            padding: 8px 16px;
            border-radius: 4px;
            border: none;
            cursor: pointer;
            font-size: 14px;
            margin-top: 20px;
            background-color: #ff9800;
            color: white;
        }
        
        .disabled {
            opacity: 0.6;
            cursor: not-allowed;
        }
        
        .error-message {
            color: #e53935;
            margin-top: 10px;
            text-align: center;
            max-width: 80%;
        }
    </style>
    <script src="https://cdn.100ms.live/sdk/web/0.7.5/hms.js"></script>
</head>
<body>
    <div id="root">
        <div id="conference">
            <div id="join-screen">
                <div class="avatar">VC</div>
                <h2>Video Conference</h2>
                <p>Join the video conference to collaborate with others</p>
                <button id="join-btn" class="btn">Join Conference</button>
                <div id="error-message" class="error-message"></div>
            </div>
            <div id="videos"></div>
            <div id="controls" style="display: none;">
                <div class="control-button" id="mic-btn" title="Toggle Microphone">
                    <span id="mic-icon">🎤</span>
                </div>
                <div class="control-button" id="camera-btn" title="Toggle Camera">
                    <span id="camera-icon">📹</span>
                </div>
                <div class="control-button red" id="leave-btn" title="Leave Meeting">
                    <span>⏏</span>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        // Helper function to get initials from name
        function getInitials(name) {
            return name.split(' ').map(n => n[0]).join('').toUpperCase();
        }
        
        // Helper function to get a color based on name
        function getAvatarColor(name) {
            // Simple hash function for consistent color
            let hash = 0;
            for (let i = 0; i < name.length; i++) {
                hash = name.charCodeAt(i) + ((hash << 5) - hash);
            }
            const hue = Math.abs(hash % 360);
            return `hsl(\${hue}, 70%, 50%)`;
        }
        
        // Create avatar for video disabled
        function createAvatar(participant) {
            const videoContainer = document.createElement('div');
            videoContainer.className = 'video-container';
            videoContainer.id = `container-\${participant.id}`;
            
            const avatar = document.createElement('div');
            avatar.className = 'avatar';
            avatar.style.position = 'absolute';
            avatar.style.top = '50%';
            avatar.style.left = '50%';
            avatar.style.transform = 'translate(-50%, -50%)';
            avatar.style.backgroundColor = getAvatarColor(participant.name);
            avatar.innerText = getInitials(participant.name);
            
            const participantName = document.createElement('div');
            participantName.className = 'participant-name';
            participantName.innerText = participant.name + (participant.isLocal ? ' (You)' : '');
            
            const audioIndicator = document.createElement('div');
            audioIndicator.className = 'audio-indicator';
            audioIndicator.innerHTML = participant.audioTrack?.enabled ? '🔊' : '🔇';
            audioIndicator.id = `audio-\${participant.id}`;
            
            videoContainer.appendChild(avatar);
            videoContainer.appendChild(participantName);
            videoContainer.appendChild(audioIndicator);
            
            return videoContainer;
        }
        
        // Room variables
        let hmsClient;
        let roomId = '67f5805302936b386a840d42';
        let authToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ2ZXJzaW9uIjoyLCJ0eXBlIjoiYXBwIiwiYXBwX2RhdGEiOm51bGwsImFjY2Vzc19rZXkiOiI2N2YzYjhiNTMzY2U3NGFiOWJlOTViMjEiLCJyb2xlIjoiaG9zdCIsInJvb21faWQiOiI2N2Y1ODA1MzAyOTM2YjM4NmE4NDBkNDIiLCJ1c2VyX2lkIjoiMTk3YjE2MDUtZmEyMC00OTAxLWI0ZGUtOTk5NTZkOGE3ODlkIiwiZXhwIjoxNzQ0MjI5MTA5LCJqdGkiOiI1ZjgxYjZjOC02ZmJhLTRkNWQtOTIwOS1jM2Q2NTk3YTcyZmEiLCJpYXQiOjE3NDQxNDI3MDksImlzcyI6IjY3ZWZjNDk4NDk0NGYwNjczMTNhOTUwMiIsIm5iZiI6MTc0NDE0MjcwOSwic3ViIjoiYXBpIn0.3bthvTq34IEBXncTLqiN5py9twBYzwKI8vEx9fXfZUg';
        
        // DOM elements
        const joinScreen = document.getElementById('join-screen');
        const joinBtn = document.getElementById('join-btn');
        const videosGrid = document.getElementById('videos');
        const controls = document.getElementById('controls');
        const micBtn = document.getElementById('mic-btn');
        const cameraBtn = document.getElementById('camera-btn');
        const leaveBtn = document.getElementById('leave-btn');
        const errorMessage = document.getElementById('error-message');
        
        // State variables
        let isAudioEnabled = true;
        let isVideoEnabled = true;
        let username = "Anonymous";
        
        // Try to get a more meaningful username from Flutter
        try {
            if (window.Flutter) {
                window.handleFlutterMessage = function(message) {
                    const data = JSON.parse(message);
                    if (data.type === 'username') {
                        username = data.value || "Anonymous";
                    }
                    if (data.type === 'join') {
                        joinMeeting();
                    }
                };
            }
        } catch (e) {
            console.error('Error setting up Flutter message handler:', e);
        }
        
        // Function to join a 100ms room
        async function joinMeeting() {
            try {
                errorMessage.innerText = '';
                joinBtn.disabled = true;
                joinBtn.classList.add('disabled');
                joinBtn.innerText = 'Joining...';
                
                console.log('Initializing 100ms SDK...');
                hmsClient = new HMS();
                
                console.log('Joining room with ID:', roomId);
                
                await hmsClient.join({
                    authToken,
                    userName: username,
                    settings: {
                        isAudioMuted: !isAudioEnabled,
                        isVideoMuted: !isVideoEnabled
                    },
                    onSuccess: () => {
                        console.log('Successfully joined room');
                        joinScreen.style.display = 'none';
                        controls.style.display = 'flex';
                        
                        // Add all existing peers
                        const peers = hmsClient.getPeers();
                        peers.forEach(addPeerToGrid);
                    },
                    onError: (error) => {
                        console.error('Error joining room:', error);
                        errorMessage.innerText = 'Failed to join conference: ' + error.message;
                        joinBtn.disabled = false;
                        joinBtn.classList.remove('disabled');
                        joinBtn.innerText = 'Join Conference';
                    }
                });
                
                // Set up event listeners
                hmsClient.addEventListener('peer-join', (peer) => {
                    console.log('Peer joined:', peer.name);
                    addPeerToGrid(peer);
                });
                
                hmsClient.addEventListener('peer-leave', (peer) => {
                    console.log('Peer left:', peer.name);
                    const container = document.getElementById(`container-\${peer.id}`);
                    if (container) {
                        container.remove();
                    }
                });
                
                hmsClient.addEventListener('track-update', (track, peer) => {
                    console.log('Track update:', track.type, peer.name);
                    updatePeerMedia(peer);
                });
                
            } catch (error) {
                console.error('Error joining meeting:', error);
                errorMessage.innerText = 'Failed to join: ' + (error.message || 'Unknown error');
                joinBtn.disabled = false;
                joinBtn.classList.remove('disabled');
                joinBtn.innerText = 'Join Conference';
            }
        }
        
        // Add a peer to the video grid
        function addPeerToGrid(peer) {
            // Remove existing container if any
            const existingContainer = document.getElementById(`container-\${peer.id}`);
            if (existingContainer) {
                existingContainer.remove();
            }
            
            if (peer.videoTrack && peer.videoTrack.enabled) {
                // Create container with video
                const videoContainer = document.createElement('div');
                videoContainer.className = 'video-container';
                videoContainer.id = `container-\${peer.id}`;
                
                const video = document.createElement('video');
                video.autoplay = true;
                video.muted = peer.isLocal; // Mute local video
                video.id = `video-\${peer.id}`;
                
                const participantName = document.createElement('div');
                participantName.className = 'participant-name';
                participantName.innerText = peer.name + (peer.isLocal ? ' (You)' : '');
                
                const audioIndicator = document.createElement('div');
                audioIndicator.className = 'audio-indicator';
                audioIndicator.innerHTML = peer.audioTrack?.enabled ? '🔊' : '🔇';
                audioIndicator.id = `audio-\${peer.id}`;
                
                videoContainer.appendChild(video);
                videoContainer.appendChild(participantName);
                videoContainer.appendChild(audioIndicator);
                
                videosGrid.appendChild(videoContainer);
                
                // Attach stream to video element
                if (peer.videoTrack) {
                    hmsClient.attachVideo(peer.videoTrack, `video-\${peer.id}`);
                }
            } else {
                // Create container with avatar
                const avatarContainer = createAvatar(peer);
                videosGrid.appendChild(avatarContainer);
            }
        }
        
        // Update peer media when tracks change
        function updatePeerMedia(peer) {
            const container = document.getElementById(`container-\${peer.id}`);
            if (!container) return;
            
            // Update audio indicator
            const audioIndicator = document.getElementById(`audio-\${peer.id}`);
            if (audioIndicator) {
                audioIndicator.innerHTML = peer.audioTrack?.enabled ? '🔊' : '🔇';
            }
            
            // Handle video track update
            if (peer.videoTrack && peer.videoTrack.enabled) {
                // If container doesn't have video, replace with video
                if (!document.getElementById(`video-\${peer.id}`)) {
                    container.innerHTML = '';
                    
                    const video = document.createElement('video');
                    video.autoplay = true;
                    video.muted = peer.isLocal;
                    video.id = `video-\${peer.id}`;
                    
                    const participantName = document.createElement('div');
                    participantName.className = 'participant-name';
                    participantName.innerText = peer.name + (peer.isLocal ? ' (You)' : '');
                    
                    const audioIndicator = document.createElement('div');
                    audioIndicator.className = 'audio-indicator';
                    audioIndicator.innerHTML = peer.audioTrack?.enabled ? '🔊' : '🔇';
                    audioIndicator.id = `audio-\${peer.id}`;
                    
                    container.appendChild(video);
                    container.appendChild(participantName);
                    container.appendChild(audioIndicator);
                    
                    hmsClient.attachVideo(peer.videoTrack, `video-\${peer.id}`);
                }
            } else {
                // Replace with avatar if video disabled
                const videoElement = document.getElementById(`video-\${peer.id}`);
                if (videoElement) {
                    container.remove();
                    const avatarContainer = createAvatar(peer);
                    videosGrid.appendChild(avatarContainer);
                }
            }
        }
        
        // Toggle microphone
        function toggleMicrophone() {
            if (!hmsClient) return;
            
            isAudioEnabled = !isAudioEnabled;
            hmsClient.setLocalAudioEnabled(isAudioEnabled);
            micBtn.innerHTML = isAudioEnabled ? '<span>🎤</span>' : '<span>🔇</span>';
        }
        
        // Toggle camera
        function toggleCamera() {
            if (!hmsClient) return;
            
            isVideoEnabled = !isVideoEnabled;
            hmsClient.setLocalVideoEnabled(isVideoEnabled);
            cameraBtn.innerHTML = isVideoEnabled ? '<span>📹</span>' : '<span>🚫</span>';
            
            // Update local peer display
            const localPeer = hmsClient.getLocalPeer();
            if (localPeer) {
                updatePeerMedia(localPeer);
            }
        }
        
        // Leave meeting
        function leaveMeeting() {
            if (!hmsClient) return;
            
            hmsClient.leave().then(() => {
                console.log('Left meeting successfully');
                joinScreen.style.display = 'flex';
                controls.style.display = 'none';
                videosGrid.innerHTML = '';
                joinBtn.disabled = false;
                joinBtn.classList.remove('disabled');
                joinBtn.innerText = 'Join Conference';
                
                // Reset state
                isAudioEnabled = true;
                isVideoEnabled = true;
                micBtn.innerHTML = '<span>🎤</span>';
                cameraBtn.innerHTML = '<span>📹</span>';
            }).catch(error => {
                console.error('Error leaving meeting:', error);
            });
        }
        
        // Set up button event listeners
        joinBtn.addEventListener('click', joinMeeting);
        micBtn.addEventListener('click', toggleMicrophone);
        cameraBtn.addEventListener('click', toggleCamera);
        leaveBtn.addEventListener('click', leaveMeeting);
    </script>
</body>
</html>
    ''';
  }

  // Get initials from a name for avatar display
  String _getInitials(String name) {
    if (name.isEmpty) return '';
    List<String> nameParts = name.split(' ');
    String initials = '';
    for (var part in nameParts) {
      if (part.isNotEmpty) {
        initials += part[0].toUpperCase();
      }
      if (initials.length >= 2) break;
    }
    return initials;
  }

  // Get avatar color - using theme-aware colors
  Color _getAvatarColor(String name) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // Return appropriate colors based on theme mode
    return themeProvider.isDarkMode
        ? Color(0xFFBB8F7D) // Lighter brown for dark mode
        : Color(0xFF8D6E63); // Brown 400 for light mode
  }

  // Request camera and microphone permissions
  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses =
        await [Permission.camera, Permission.microphone].request();

    print("Camera permission: ${statuses[Permission.camera]}");
    print("Microphone permission: ${statuses[Permission.microphone]}");
  }

  // Duplicate method removed - keeping the comprehensive implementation below

  // Enhanced peer update method with improved deduplication logic
  // Enhanced peer update with more aggressive deduplication
  Future<void> _updatePeers() async {
    if (_hmsSDKInteractor == null || !_hmsSDKInteractor!.isInitialized) return;

    try {
      final allPeers = await _hmsSDKInteractor!.getAllPeers();
      final localPeer = await _hmsSDKInteractor!.getLocalPeer();

      // Create a map to deduplicate peers by their unique ID
      final Map<String, HMSPeer> uniquePeersMap = {};
      final Set<String> activePeerIds = {};

      // Also track names for additional deduplication
      final Map<String, List<String>> nameToIdMap = {};
      final Map<String, List<HMSPeer>> nameTopeersMap = {};

      // First, check if local peer is present (always prioritize local peer)
      String? localPeerName;
      String? localPeerId;
      if (localPeer != null) {
        localPeerName = localPeer.name;
        localPeerId = localPeer.peerId;
        // Always add local peer first
        if (localPeer.peerId.isNotEmpty) {
          uniquePeersMap[localPeer.peerId] = localPeer;
          activePeerIds.add(localPeer.peerId);
        }
      }

      // First pass: collect and organize all peers
      for (final peer in allPeers) {
        if (peer.peerId.isNotEmpty) {
          // Skip if this is the same as local peer (already added)
          if (peer.peerId == localPeerId) continue;

          // Add to the unique map temporarily (will filter later)
          uniquePeersMap[peer.peerId] = peer;
          activePeerIds.add(peer.peerId);

          // Group peers by name for duplicate detection
          if (!nameToIdMap.containsKey(peer.name)) {
            nameToIdMap[peer.name] = [];
            nameTopeersMap[peer.name] = [];
          }
          nameToIdMap[peer.name]!.add(peer.peerId);
          nameTopeersMap[peer.name]!.add(peer);
        }
      }

      // Handle the special case of first rejoin which is most prone to duplicates
      final isFirstRejoin = _joinCount == 2; // First time after rejoining

      // Second pass: aggressively remove duplicates with same name
      nameToIdMap.forEach((name, peerIds) {
        // If this is the local user's name, handle specially
        bool isLocalUserName = (name == localPeerName);

        // If multiple peers with same name, need deduplication
        if (peerIds.length > 1 || (isLocalUserName && peerIds.isNotEmpty)) {
          print(
            'Found ${peerIds.length} peers with name: $name (first rejoin: $isFirstRejoin)',
          );

          // SPECIAL CASE: Be extra aggressive on first rejoin for local user name
          if (isLocalUserName && isFirstRejoin) {
            print(
              'HANDLING SPECIAL CASE: First rejoin with own user name duplicates',
            );

            // During first rejoin, if we see multiple instances of our own name,
            // keep ONLY the localPeer and remove ALL remote peers with same name
            if (localPeerId != null) {
              // Remove every instance that's not the local peer ID
              for (final peerId in List<String>.from(peerIds)) {
                if (peerId != localPeerId) {
                  print(
                    '💀 Aggressively removing self-duplicate on first rejoin: $peerId',
                  );
                  uniquePeersMap.remove(peerId);
                  activePeerIds.remove(peerId);
                }
              }
            }
          }
          // Regular approach for local user name in other cases
          else if (isLocalUserName) {
            int remotesToKeep = 0;
            List<String> peersToRemove = [];

            // Find all remote peers with user's name to be removed (keep just one)
            for (final peerId in peerIds) {
              final peer = uniquePeersMap[peerId];
              if (peer != null) {
                // Keep one remote peer maximum with same name as local user
                if (remotesToKeep < 1) {
                  remotesToKeep++;
                  continue;
                }
                peersToRemove.add(peerId);
              }
            }

            // Remove the excess peers
            for (final peerId in peersToRemove) {
              print('Removing duplicate of local user: $name (ID: $peerId)');
              uniquePeersMap.remove(peerId);
              activePeerIds.remove(peerId);
            }
          }
          // For non-local names, just keep one instance
          else {
            // Find oldest peer to keep (assuming first in the array)
            String peerToKeep = peerIds.first;

            // Remove all other peers with this name
            for (final peerId in peerIds) {
              if (peerId == peerToKeep) continue;

              print('Removing non-local duplicate: $name (ID: $peerId)');
              uniquePeersMap.remove(peerId);
              activePeerIds.remove(peerId);
            }
          }
        }
      });

      // Convert filtered map back to a list
      final uniquePeers = uniquePeersMap.values.toList();

      if (mounted) {
        setState(() {
          // Replace entire peers list with deduplicated version
          _peers = List<HMSPeer>.from(uniquePeers);
          _localPeer = localPeer;

          // Clean up remote tracks for peers that are no longer active
          _remoteVideoTracks = Map<String, HMSVideoTrack>.from(
            _remoteVideoTracks,
          )..removeWhere((peerId, _) => !activePeerIds.contains(peerId));
        });
      }

      print('Updated to ${_peers.length} unique peers after deduplication');
    } catch (e) {
      print('Error updating peers: $e');
    }
  }

  // Toggle audio via SDK
  void _toggleAudio() async {
    if (!_isJoined || _hmsSDKInteractor == null) return;

    try {
      await _hmsSDKInteractor!.switchAudio(isOn: !_isAudioOn);
      setState(() {
        _isAudioOn = !_isAudioOn;
      });
    } catch (e) {
      print('Error toggling audio: $e');
    }
  }

  // Toggle video via SDK
  void _toggleVideo() async {
    if (!_isJoined || _hmsSDKInteractor == null) return;

    try {
      await _hmsSDKInteractor!.switchVideo(isOn: !_isVideoOn);
      setState(() {
        _isVideoOn = !_isVideoOn;
      });
    } catch (e) {
      print('Error toggling video: $e');
    }
  }

  // Toggle screen share via SDK
  void _toggleScreenShare() async {
    if (!_isJoined || _hmsSDKInteractor == null) return;

    try {
      if (_isScreenShareOn) {
        _hmsSDKInteractor!.stopScreenShare();
      } else {
        await _hmsSDKInteractor!.startScreenShare();
      }
      setState(() {
        _isScreenShareOn = !_isScreenShareOn;
      });
    } catch (e) {
      print('Error toggling screen share: $e');
    }
  }

  // Enhanced leave method with more thorough cleanup
  Future<void> _leaveVideoConference() async {
    if (!_isJoined) return;

    try {
      print(
        'Leaving video conference with thorough cleanup... (join count: $_joinCount)',
      );

      // Capture the current session ID before clearing it
      final oldSessionId = _currentSessionId;

      // First clear all state to prevent UI glitches
      setState(() {
        _isJoining = true; // Set to joining to prevent UI interactions
      });

      // Native SDK cleanup
      if (_useNativeSDK &&
          _hmsSDKInteractor != null &&
          _hmsSDKInteractor!.isInitialized) {
        print('Leaving via native SDK...');
        await _hmsSDKInteractor!.leave();
      }

      // WebView cleanup
      if (_fallbackToWebView && _webViewController != null) {
        print('Cleaning up WebView implementation...');
        await _webViewController!.runJavaScript('''
          try {
            if (hmsClient) {
              console.log("Leaving meeting via WebView...");
              hmsClient.leave().catch(e => console.error('Error leaving meeting:', e));
              
              // Also clear grid to prevent ghost participants
              if (document.getElementById('videos')) {
                document.getElementById('videos').innerHTML = '';
              }
            }
          } catch(e) {
            console.error('Error executing leave JavaScript:', e);
          }
        ''');
      }

      // Extra pause to ensure SDK has time to clean up
      await Future.delayed(Duration(milliseconds: 300));

      // Thorough state cleanup with explicit nulling of references
      setState(() {
        _isJoined = false;
        _isJoining = false;

        // Clear ALL peer data completely
        _peers = [];
        _remoteVideoTracks = {};
        _localPeer = null;
        _errorMessage = '';
      });

      print('Successfully left video conference and cleared all peer data');

      // Reset SDK state if needed
      if (_sdkInitAttempts > 1) {
        print('Reinitializing HMS SDK after multiple join/leave cycles');
        _initializeHMSSDK();
      }
    } catch (e) {
      print('Error leaving video conference: $e');

      // Force state cleanup even on error
      setState(() {
        _isJoined = false;
        _isJoining = false;
        _peers = [];
        _remoteVideoTracks = {};
        _localPeer = null;
      });
    }
  }

  void _loadRoomData() async {
    try {
      // Get room details
      DocumentSnapshot roomSnapshot =
          await _firestore.collection('studyRooms').doc(widget.roomId).get();

      if (roomSnapshot.exists) {
        setState(() {
          _roomDetails = roomSnapshot.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      }

      // Join the room as a participant if not already
      _joinRoom();
    } catch (e) {
      print('Error loading room data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _joinRoom() async {
    try {
      // Check if user is already a participant
      QuerySnapshot participantQuery =
          await _firestore
              .collection('studyRooms')
              .doc(widget.roomId)
              .collection('participants')
              .where('userId', isEqualTo: _auth.currentUser?.uid)
              .get();

      if (participantQuery.docs.isEmpty) {
        // Add user as participant
        await _firestore
            .collection('studyRooms')
            .doc(widget.roomId)
            .collection('participants')
            .add({
              'userId': _auth.currentUser?.uid,
              'name': _auth.currentUser?.email?.split('@')[0] ?? 'Anonymous',
              'isHost': false,
              'isMuted': false,
              'hasCamera': false,
              'joinedAt': FieldValue.serverTimestamp(),
            });

        // Update participant count
        await _firestore.collection('studyRooms').doc(widget.roomId).update({
          'participants': FieldValue.increment(1),
        });

        // Update rooms joined count in user profile
        _updateRoomsJoined();
      }
    } catch (e) {
      print('Error joining room: $e');
    }
  }

  // Update rooms joined count in user profile
  Future<void> _updateRoomsJoined() async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        // Get user document reference
        DocumentReference userRef = _firestore
            .collection('users')
            .doc(user.uid);

        // Get current rooms joined count
        DocumentSnapshot userDoc = await userRef.get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          // Update rooms joined count
          int currentRoomsJoined = userData['roomsJoined'] ?? 0;

          await userRef.update({'roomsJoined': currentRoomsJoined + 1});

          print('Rooms joined count updated successfully');
        }
      }
    } catch (e) {
      print('Error updating rooms joined count: $e');
    }
  }

  @override
  void dispose() {
    // Leave video conference if joined
    if (_isJoined && _hmsSDKInteractor != null) {
      _hmsSDKInteractor!.leave();
      _hmsSDKInteractor!.destroy();
    }

    _tabController.dispose();
    _messageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isTimerRunning = true;
      _currentTime = _timerDuration;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_currentTime > 0) {
          _currentTime--;
        } else {
          _isTimerRunning = false;
          _timer?.cancel();
          // Show notification or play sound when timer ends
          _showTimerCompleteDialog();
        }
      });
    });
  }

  void _pauseTimer() {
    setState(() {
      _isTimerRunning = false;
      _timer?.cancel();
    });
  }

  void _resetTimer() {
    setState(() {
      _isTimerRunning = false;
      _currentTime = _timerDuration;
      _timer?.cancel();
    });
  }

  void _showTimerCompleteDialog() {
    // Update study statistics in the user's profile
    _updateStudyStatistics(_timerDuration ~/ 60);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Time's Up!"),
            content: Text(
              "Your study session is complete. Take a short break before starting another session.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          ),
    );
  }

  // Update study statistics in Firestore
  Future<void> _updateStudyStatistics(int minutes) async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        // Get user document reference
        DocumentReference userRef = _firestore
            .collection('users')
            .doc(user.uid);

        // Get current study statistics
        DocumentSnapshot userDoc = await userRef.get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          // Update study statistics
          int currentSessions = userData['studySessions'] ?? 0;
          double currentHours = userData['studyHours'] ?? 0.0;
          double hours = minutes / 60.0;

          await userRef.update({
            'studySessions': currentSessions + 1,
            'studyHours': currentHours + hours,
          });

          print('Study statistics updated successfully');
        }
      }
    } catch (e) {
      print('Error updating study statistics: $e');
    }
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      try {
        // Add message to Firestore
        await _firestore
            .collection('studyRooms')
            .doc(widget.roomId)
            .collection('messages')
            .add({
              'sender': _auth.currentUser?.email?.split('@')[0] ?? 'Anonymous',
              'senderId': _auth.currentUser?.uid,
              'message': _messageController.text.trim(),
              'timestamp': FieldValue.serverTimestamp(),
            });

        _messageController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRoomDetailsDialog() {
    bool isPrivate = _roomDetails['isPrivate'] == true;
    String? roomCode = _roomDetails['roomCode'];
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_roomDetails['name'] ?? 'Study Room'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Topic: ${_roomDetails['topic'] ?? 'General'}'),
                SizedBox(height: 8),
                Text('Created by: ${_roomDetails['creatorName'] ?? 'Unknown'}'),
                SizedBox(height: 8),
                Text('Participants: ${_roomDetails['participants'] ?? 0}'),
                SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Room type: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isPrivate ? 'Private' : 'Public',
                      style: TextStyle(
                        color: isPrivate ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isPrivate)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Icon(Icons.lock, size: 16, color: Colors.red),
                      ),
                  ],
                ),
                if (isPrivate && roomCode != null) ...[
                  SizedBox(height: 16),
                  Text(
                    'Room Code:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          themeProvider.isDarkMode
                              ? Theme.of(context).colorScheme.surface
                              : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color:
                            themeProvider.isDarkMode
                                ? Colors.grey[700]!
                                : Colors.grey,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          roomCode,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.copy, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: () {
                            // Copy to clipboard functionality would go here
                            Clipboard.setData(ClipboardData(text: roomCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Room code copied!')),
                            );
                          },
                          tooltip: "Copy to clipboard",
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Share this code with friends to invite them to this room',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color:
                          themeProvider.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                    ),
                  ),
                ],
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

  // Method to show invite dialog
  void _showInviteDialog() {
    bool isPrivate = _roomDetails['isPrivate'] == true;
    String? roomCode = _roomDetails['roomCode'];
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    if (!isPrivate || roomCode == null) {
      // For public rooms or if code is missing
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text("Invite Friends"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This is a public room that anyone can join from the dashboard.',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'You can also share the room details directly:',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          themeProvider.isDarkMode
                              ? Theme.of(context).colorScheme.surface
                              : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Join my study room "${_roomDetails['name']}" to study together!',
                      style: TextStyle(fontStyle: FontStyle.italic),
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
      return;
    }

    // For private rooms with code
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Invite Friends"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Share this code with friends to invite them to your private study room:",
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color:
                        themeProvider.isDarkMode
                            ? Theme.of(context).colorScheme.surface
                            : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          themeProvider.isDarkMode
                              ? Colors.grey[700]!
                              : Colors.grey,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        roomCode,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                      SizedBox(width: 12),
                      IconButton(
                        icon: Icon(Icons.copy),
                        onPressed: () {
                          // Copy to clipboard functionality
                          Clipboard.setData(ClipboardData(text: roomCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Room code copied!')),
                          );
                        },
                        tooltip: "Copy to clipboard",
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "Your friends can enter this code on the dashboard by clicking \"Join by Code\" button.",
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        themeProvider.isDarkMode
                            ? Colors.grey[400]
                            : Colors.grey[700],
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

  // Build the navigation drawer
  Widget _buildNavigationDrawer() {
    return Drawer(
      child: Consumer<ThemeProvider>(
        builder:
            (context, themeProvider, _) => ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Study Room',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tools and Resources',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _auth.currentUser?.email ?? 'Not signed in',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.home,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text('Home Screen'),
                  subtitle: Text('Return to dashboard'),
                  onTap: () {
                    // Close the drawer first
                    Navigator.pop(context);
                    // Navigate back to home screen
                    Navigator.pop(context);
                  },
                ),
                Divider(),
                ListTile(
                  leading: Icon(
                    Icons.timer,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text('Pomodoro Timer'),
                  subtitle: Text('Focus and break timer'),
                  onTap: () {
                    // Close the drawer first
                    Navigator.pop(context);
                    // Navigate to the Pomodoro Timer screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PomodoroTimerScreen(),
                      ),
                    );
                  },
                ),
                Divider(),
                ListTile(
                  leading: Icon(
                    Icons.group,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text('Study Groups'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to study groups (not implemented)
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.book,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text('Resources'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to resources (not implemented)
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.settings,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to settings (not implemented)
                  },
                ),
              ],
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Loading Study Room...")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Check if this is a private room with a room code
    bool isPrivate = _roomDetails['isPrivate'] == true;
    String? roomCode = _roomDetails['roomCode'];

    return Consumer<ThemeProvider>(
      builder:
          (context, themeProvider, _) => Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              title: Text(_roomDetails['name'] ?? 'Study Room'),
              actions: [
                // Invite button for room sharing
                IconButton(
                  icon: Icon(Icons.person_add),
                  tooltip: "Invite Friends",
                  onPressed: () {
                    _showInviteDialog();
                  },
                ),
                IconButton(
                  icon: Icon(Icons.menu),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                IconButton(
                  icon: Icon(Icons.info_outline),
                  onPressed: () {
                    _showRoomDetailsDialog();
                  },
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    icon: Icon(Icons.videocam, color: Colors.white),
                    text: "Video Chat",
                  ),
                  Tab(
                    icon: Icon(Icons.chat, color: Colors.white),
                    text: "Live Chat",
                  ),
                  Tab(
                    icon: Icon(Icons.edit_note, color: Colors.white),
                    text: "Whiteboard",
                  ),
                  Tab(
                    icon: Icon(Icons.note_alt, color: Colors.white),
                    text: "Shared Notes",
                  ),
                ],
              ),
            ),
            drawer: _buildNavigationDrawer(),
            body: Column(
              children: [
                // Display room code for private rooms at the top
                if (isPrivate && roomCode != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    color:
                        themeProvider.isDarkMode
                            ? Theme.of(context).colorScheme.surface
                            : Colors.orange[50],
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Room Code: ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SelectableText(
                          roomCode,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            fontSize: 14,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, size: 18),
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          constraints: BoxConstraints(),
                          onPressed: () {
                            // Copy to clipboard functionality
                            Clipboard.setData(ClipboardData(text: roomCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Room code copied to clipboard!'),
                              ),
                            );
                          },
                          tooltip: "Copy to clipboard",
                        ),
                        Spacer(),
                        Text(
                          "Private Room",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main content area with tabs
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Video Chat Tab
                      _buildVideoChat(),

                      // Live Chat Tab
                      _buildLiveChat(),

                      // Whiteboard Tab
                      WhiteboardWidget(roomId: widget.roomId),

                      // Shared Notes Tab
                      SharedNotesWidget(roomId: widget.roomId),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // Enhanced join method with improved state management
  // Enhanced join method to prevent duplication issues
  void _joinVideoConference() async {
    if (_isJoining) return; // Prevent double-join attempts

    // Increment join count to track rejoins
    _joinCount++;

    // Generate a unique session ID for this join
    final newSessionId = DateTime.now().millisecondsSinceEpoch.toString();

    print(
      'Starting join process... (join #$_joinCount, session: $newSessionId)',
    );

    // First set joining state to prevent UI interactions
    setState(() {
      _isJoining = true;
      _errorMessage = '';
      _currentSessionId = newSessionId;
    });

    // If already in a conference, leave first with full cleanup
    if (_isJoined) {
      print('Already in a conference, leaving first...');
      await _leaveVideoConference();

      // More substantial delay to ensure full cleanup
      await Future.delayed(Duration(milliseconds: 800));
    }

    // Extra state reset with forced GC hints
    setState(() {
      // Clear all peer-related data
      _peers = [];
      _remoteVideoTracks = {};
      _localPeer = null;
    });

    // Force an additional delay to ensure clean slate
    await Future.delayed(Duration(milliseconds: 200));

    if (_useNativeSDK &&
        _hmsSDKInteractor != null &&
        _hmsSDKInteractor!.isInitialized) {
      // Use native SDK approach
      try {
        // Get user name from Firebase Auth
        String username =
            _auth.currentUser?.email?.split('@')[0] ?? 'Anonymous';

        // Join with native SDK
        bool joinSuccess = await _hmsSDKInteractor!.join(
          authToken: _authToken,
          username: username,
          onJoin: (HMSRoom room) {
            print('Successfully joined room: ${room.name}');
            if (mounted) {
              setState(() {
                _isJoined = true;
                _isJoining = false;
              });
            }
            _updatePeers();
          },
          onPeerUpdate: (HMSPeer peer, HMSPeerUpdate update) {
            print('Peer update: ${peer.name} - $update (${peer.peerId})');

            // Enhanced peer update handling with detailed logging
            switch (update) {
              case HMSPeerUpdate.peerLeft:
                print('🔴 Peer LEFT: ${peer.name} (${peer.peerId})');
                setState(() {
                  // Check list size before removal to detect if a peer was removed
                  final peerCountBefore = _peers.length;

                  // Remove the peer that left
                  _peers.removeWhere((p) => p.peerId == peer.peerId);

                  // Check if any peer was actually removed
                  final wasRemoved = peerCountBefore > _peers.length;

                  // Also remove any tracks associated with this peer
                  final hadTracks =
                      _remoteVideoTracks.remove(peer.peerId) != null;

                  print(
                    'Peer removal success: $wasRemoved (had video tracks: $hadTracks)',
                  );

                  // Double-check if we actually have other peers with same name to detect duplicates
                  final sameName =
                      _peers.where((p) => p.name == peer.name).toList();
                  if (sameName.isNotEmpty) {
                    print(
                      '⚠️ Still have ${sameName.length} other peers with name "${peer.name}"',
                    );
                    // Force a full refresh of the peer list to ensure deduplication
                    _updatePeers();
                  }
                });
                break;

              case HMSPeerUpdate.peerJoined:
                print('🟢 Peer JOINED: ${peer.name} (${peer.peerId})');
                // Check for potential duplicates
                final existingWithSameName =
                    _peers.where((p) => p.name == peer.name).toList();
                if (existingWithSameName.isNotEmpty) {
                  print(
                    '⚠️ Already have ${existingWithSameName.length} peers with name "${peer.name}"',
                  );
                }
                // Always use updatePeers for join events to ensure proper deduplication
                _updatePeers();
                break;

              case HMSPeerUpdate.roleUpdated:
                print('🔄 Peer ROLE UPDATED: ${peer.name} (${peer.peerId})');
                _updatePeers();
                break;

              case HMSPeerUpdate.networkQualityUpdated:
                // Don't log network updates to reduce noise
                _updatePeers();
                break;

              default:
                print(
                  'ℹ️ Other peer update: $update for ${peer.name} (${peer.peerId})',
                );
                _updatePeers();
                break;
            }
          },
          onTrackUpdate: (
            HMSTrack track,
            HMSTrackUpdate trackUpdate,
            HMSPeer peer,
          ) {
            String trackType = track is HMSVideoTrack ? "VIDEO" : "AUDIO";

            // Auto-mute new audio tracks when Silent Study Mode is active
            if (track is HMSAudioTrack &&
                _isSilentStudyModeOn &&
                !peer.isLocal) {
              if (trackUpdate == HMSTrackUpdate.trackAdded) {
                print(
                  'Silent Study Mode: Auto-muting new audio track from ${peer.name}',
                );
                if (_hmsSDKInteractor != null &&
                    _hmsSDKInteractor!.isInitialized &&
                    _hmsSDKInteractor!._hmsSDK != null) {
                  _hmsSDKInteractor!._hmsSDK!.changeTrackState(
                    forRemoteTrack: track,
                    mute: true,
                  );
                }
              }
            }

            // Handle video tracks specifically with enhanced duplicate detection
            if (track is HMSVideoTrack) {
              if (!peer.isLocal) {
                // Enhanced remote peer video track handling
                switch (trackUpdate) {
                  case HMSTrackUpdate.trackAdded:
                    print(
                      '➕ Remote video track ADDED: ${peer.name} (${peer.peerId})',
                    );

                    // First check for any potential duplicates of this peer
                    final existingWithSameName =
                        _peers
                            .where(
                              (p) =>
                                  p.peerId != peer.peerId &&
                                  p.name == peer.name,
                            )
                            .toList();

                    if (existingWithSameName.isNotEmpty) {
                      print(
                        '⚠️ DUPLICATE DETECTION: Already have ${existingWithSameName.length} other peers with name "${peer.name}"',
                      );
                      for (final duplicate in existingWithSameName) {
                        print('  - Duplicate ID: ${duplicate.peerId}');
                      }
                      // Force a full peer refresh to deduplicate
                      _updatePeers();
                    }

                    setState(() {
                      // Store the video track in our remote tracks map for rendering
                      _remoteVideoTracks[peer.peerId] = track;
                    });

                    // Manually subscribe to the track if needed
                    _trySubscribeToTrack(track, peer);
                    break;

                  case HMSTrackUpdate.trackRemoved:
                    print(
                      '➖ Remote video track REMOVED: ${peer.name} (${peer.peerId})',
                    );
                    setState(() {
                      _remoteVideoTracks.remove(peer.peerId);
                    });
                    break;

                  // Handle other track update cases...
                  default:
                    // For other updates, perform standard handling
                    if (_remoteVideoTracks.containsKey(peer.peerId)) {
                      setState(() {
                        _remoteVideoTracks[peer.peerId] = track;
                      });
                    }
                    break;
                }
              }
            }

            // Always update peers to ensure UI is accurate
            _updatePeers();
          },
          onError: (HMSException error) {
            print('HMS SDK Error: $error');
            if (mounted) {
              setState(() {
                _errorMessage = 'Error: ${error.message}';
                _isJoining = false;
              });
            }
          },
        );

        if (!joinSuccess && mounted) {
          setState(() {
            _isJoining = false;
            _errorMessage = 'Connection failed. Trying WebView approach...';
          });

          // Fall back to WebView on join failure
          _useNativeSDK = false;
          _fallbackToWebView = true;
          _initWebViewController();
          // Retry join with WebView after a short delay
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) _joinWithWebView();
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isJoining = false;
            _errorMessage =
                'Failed with native SDK: $e. Falling back to WebView...';
          });
        }

        // Fall back to WebView on any error
        _useNativeSDK = false;
        _fallbackToWebView = true;
        _initWebViewController();
        // Retry join with WebView after a short delay
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) _joinWithWebView();
        });
      }
    } else if (_fallbackToWebView && _webViewController != null) {
      // Use WebView approach if native SDK failed
      _joinWithWebView();
    } else {
      setState(() {
        _isJoining = false;
        _errorMessage =
            'Video conferencing is not available. Please try again later.';
      });
    }
  }

  // Try to manually subscribe to a track if needed
  void _trySubscribeToTrack(HMSVideoTrack track, HMSPeer peer) {
    if (_hmsSDKInteractor == null || !_hmsSDKInteractor!.isInitialized) return;

    try {
      // For now we're just verifying the track is not muted
      if (track.isMute) {
        print('⚠️ Not subscribing to muted track from ${peer.name}');
        return;
      }

      // Log that we are ready to display this track
      print('✅ Track from ${peer.name} is available for display');

      // In some versions of the 100ms SDK, you might need to explicitly subscribe
      // Uncomment the below code if your SDK version requires manual subscription
      /*
      _hmsSDKInteractor!._hmsSDK!.subscribeToTrack(
        trackId: track.trackId,
        highQuality: true,
        onSuccess: () {
          print('🎯 Successfully subscribed to track from ${peer.name}');
        },
        onFailure: (error) {
          print('❌ Failed to subscribe to track from ${peer.name}: $error');
        }
      );
      */
    } catch (e) {
      print('Error trying to subscribe to track: $e');
    }
  }

  // Update WebView theme based on current app theme
  void _updateWebViewTheme() {
    if (_webViewController != null) {
      final isDarkMode =
          Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
      _log('Updating WebView theme, dark mode: $isDarkMode');

      _webViewController!.runJavaScript('''
        try {
          if (typeof updateTheme === 'function') {
            updateTheme($isDarkMode);
            console.log("Theme updated to dark mode: $isDarkMode");
          } else {
            console.warn("updateTheme function not found in WebView");
          }
        } catch(e) {
          console.error("Error updating theme:", e);
        }
      ''');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Update WebView theme when app theme changes
    _updateWebViewTheme();
  }

  // Join with WebView approach (fallback) with enhanced error handling
  // Toggle Silent Study Mode
  void _toggleSilentStudyMode() async {
    setState(() {
      _isSilentStudyModeOn = !_isSilentStudyModeOn;
    });

    if (_isSilentStudyModeOn) {
      // If turning on, mute all remote participants
      if (_hmsSDKInteractor != null &&
          _hmsSDKInteractor!.isInitialized &&
          _isJoined) {
        await _hmsSDKInteractor!.muteAllRemoteParticipants();
      }

      // Show a confirmation snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Silent Study Mode activated. All participants are muted.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      // Show a confirmation when turning off
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Silent Study Mode deactivated.'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
      // Note: We don't automatically unmute everyone when turning off
    }
  }

  void _joinWithWebView() {
    if (_webViewController == null) {
      setState(() {
        _isJoining = false;
        _errorMessage = 'WebView not initialized. Please try again.';
      });
      _log("Attempted to join with WebView, but controller is null");
      return;
    }

    try {
      _log("Joining conference with WebView fallback");
      // Get username
      String username = _auth.currentUser?.email?.split('@')[0] ?? 'Anonymous';
      _log("Using username: $username");

      // Check WebView readiness with a simple test
      _webViewController!
          .runJavaScript('document.readyState')
          .then((_) {
            _log("WebView readyState check completed");

            // Send join command to WebView
            _log("Sending join command to WebView");
            _webViewController!.runJavaScript('''
          try {
            console.log("JS execution started");
            if (typeof window.handleFlutterMessage === 'function') {
              console.log("Using handleFlutterMessage");
              window.handleFlutterMessage(JSON.stringify({
                type: 'username',
                value: '$username'
              }));
              window.handleFlutterMessage(JSON.stringify({
                type: 'join'
              }));
            } else {
              console.log("Using direct join");
              // Direct call if handler not available
              username = '$username';
              // Check if joinMeeting function exists
              if (typeof joinMeeting === 'function') {
                joinMeeting();
              } else {
                console.error("joinMeeting function not found");
                // Try to initialize from scratch
                if (document.getElementById('join-btn')) {
                  document.getElementById('join-btn').click();
                }
              }
            }
            console.log("JS execution completed");
          } catch(e) {
            console.error("Error executing JavaScript: " + e.toString());
          }
        ''');
          })
          .catchError((error) {
            _log("Error checking WebView readiness: $error");
          });

      setState(() {
        _isJoined = true;
        _isJoining = false;
      });
      _log("WebView join status updated (joined)");
    } catch (e) {
      _log("Error joining with WebView: $e");
      setState(() {
        _isJoining = false;
        _errorMessage = 'Failed to join conference: $e';
      });
    }
  }

  // Debug widget to display runtime information
  Widget _buildDebugPanel() {
    if (!_showDebugInfo) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Debug Info",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text(
            "Implementation: $_currentImplementation",
            style: TextStyle(color: Colors.white),
          ),
          Text(
            "SDK Init Attempts: $_sdkInitAttempts",
            style: TextStyle(color: Colors.white),
          ),
          Text(
            "SDK State: ${_hmsSDKInteractor?.isInitialized ?? false ? 'Initialized' : 'Not Initialized'}",
            style: TextStyle(color: Colors.white),
          ),
          Text(
            "WebView: ${_webViewController != null ? 'Ready' : 'Not Ready'}",
            style: TextStyle(color: Colors.white),
          ),
          Text(
            "Using Native: $_useNativeSDK | Fallback: $_fallbackToWebView",
            style: TextStyle(color: Colors.white),
          ),
          if (_errorMessage.isNotEmpty)
            Text(
              "Error: $_errorMessage",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),

          // Recent logs (scrollable)
          Container(
            height: 100,
            margin: EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.white30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              padding: EdgeInsets.all(4),
              itemCount: _debugLogs.length,
              itemBuilder: (context, index) {
                return Text(
                  _debugLogs[index],
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                );
              },
            ),
          ),

          // Debug controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                child: Text("Retry Native", style: TextStyle(fontSize: 10)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onPressed: () => _initializeHMSSDK(),
              ),
              ElevatedButton(
                child: Text("Force WebView", style: TextStyle(fontSize: 10)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onPressed: () {
                  _useNativeSDK = false;
                  _fallbackToWebView = true;
                  _currentImplementation = 'Forced WebView';
                  _initWebViewController();
                },
              ),
              ElevatedButton(
                child: Text("Clear Logs", style: TextStyle(fontSize: 10)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onPressed: () {
                  setState(() {
                    _debugLogs.clear();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build the timer UI
  Widget _buildTimerSection(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color:
          themeProvider.isDarkMode
              ? Theme.of(context).colorScheme.surface
              : Colors.grey[100],
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use constraints to make layout responsive
          final availableWidth = constraints.maxWidth;
          final isNarrow = availableWidth < 500; // Threshold for narrow screens
          final isVeryNarrow =
              availableWidth < 360; // Extra threshold for very small screens

          return Row(
            children: [
              // Timer label and display - aligned left with minimal width
              Container(
                constraints: BoxConstraints(
                  maxWidth:
                      isVeryNarrow
                          ? availableWidth *
                              0.3 // Even smaller on very narrow screens
                          : (isNarrow
                              ? availableWidth * 0.35
                              : availableWidth * 0.4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hide "Pomodoro Timer:" text on very narrow screens
                    if (!isVeryNarrow)
                      Text(
                        "Timer: ", // Shorter label text
                        style: TextStyle(
                          fontSize: isNarrow ? 11 : 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    Text(
                      _formatTime(_currentTime),
                      style: TextStyle(
                        fontSize:
                            isVeryNarrow
                                ? 15
                                : (isNarrow ? 16 : 18), // Smaller font sizes
                        fontWeight: FontWeight.bold,
                        color:
                            _currentTime < 60
                                ? Colors.red
                                : themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              // Minimal spacer
              SizedBox(width: isVeryNarrow ? 2 : 4),

              // Controls - grouped closer together with smaller icons
              Container(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isTimerRunning ? Icons.pause : Icons.play_arrow,
                        color: Theme.of(context).primaryColor,
                        size:
                            isVeryNarrow
                                ? 16
                                : (isNarrow ? 17 : 19), // Smaller icons
                      ),
                      padding: EdgeInsets.all(1), // Reduced padding
                      constraints: BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      onPressed: _isTimerRunning ? _pauseTimer : _startTimer,
                    ),
                    SizedBox(width: 0), // No space between buttons
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: Theme.of(context).primaryColor,
                        size:
                            isVeryNarrow
                                ? 16
                                : (isNarrow ? 17 : 19), // Smaller icons
                      ),
                      padding: EdgeInsets.all(1), // Reduced padding
                      constraints: BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      onPressed: _resetTimer,
                    ),
                  ],
                ),
              ),

              // Spacer that expands to push dropdown to right
              Spacer(),

              // Dropdown - more compact with minimal width
              Container(
                width:
                    isVeryNarrow
                        ? 55
                        : (isNarrow ? 60 : 65), // Even smaller width
                child: DropdownButton<int>(
                  value: _timerDuration ~/ 60,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    size:
                        isVeryNarrow
                            ? 14
                            : (isNarrow ? 15 : 17), // Smaller icon
                  ),
                  iconSize:
                      isVeryNarrow ? 14 : (isNarrow ? 15 : 17), // Smaller icon
                  elevation: 8,
                  isExpanded: true,
                  isDense: true,
                  style: TextStyle(
                    color:
                        themeProvider.isDarkMode ? Colors.white : Colors.black,
                    fontSize:
                        isVeryNarrow
                            ? 10
                            : (isNarrow ? 11 : 13), // Smaller font
                  ),
                  underline: Container(
                    height: 1,
                    color: Theme.of(context).primaryColor,
                  ),
                  items:
                      [5, 15, 25, 30, 45, 60].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(
                            "$value min",
                            style: TextStyle(
                              fontSize:
                                  isVeryNarrow
                                      ? 10
                                      : (isNarrow ? 11 : 13), // Smaller font
                            ),
                          ),
                        );
                      }).toList(),
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _timerDuration = newValue * 60;
                        _currentTime = _timerDuration;
                      });
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoChat() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // If no initialization yet, show loading
    if (_hmsSDKInteractor == null && _webViewController == null) {
      return Stack(
        children: [
          Center(child: CircularProgressIndicator()),
          if (_showDebugInfo) _buildDebugPanel(),
        ],
      );
    }
    // If using native SDK approach
    if (_useNativeSDK && !_fallbackToWebView) {
      // Native SDK loading state
      if (!_isJoined) {
        return Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam, size: 80, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    "Video Conference",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Join the video conference to collaborate with others",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          themeProvider.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: Icon(Icons.video_call),
                    label: Text(_isJoining ? "Joining..." : "Join Conference"),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _isJoining ? null : _joinVideoConference,
                  ),
                  if (_errorMessage.isNotEmpty)
                    Container(
                      margin: EdgeInsets.all(16.0),
                      padding: EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Error",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _errorMessage,
                            style: TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (_showDebugInfo) _buildDebugPanel(),
          ],
        );
      }
      // Native SDK joined state
      return Column(
        children: [
          // Timer section - only show when joined
          _buildTimerSection(context),

          // Main video area with 100ms native SDK
          Expanded(
            flex: 3,
            child: Container(
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Debug information for remote tracks
                  if (_showDebugInfo)
                    Container(
                      width: double.infinity,
                      color: Colors.black54,
                      padding: EdgeInsets.all(4),
                      child: Text(
                        "Remote Video Tracks: ${_remoteVideoTracks.length} | Total Peers: ${_peers.length}",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Silent Study Mode indicator banner
                  if (_isSilentStudyModeOn)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      color: Colors.red.withOpacity(0.2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.volume_off, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            "Silent Study Mode Active - All participants are muted",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Main video grid
                  Expanded(
                    child:
                        _peers.isEmpty
                            ? Center(
                              child: Text(
                                "No participants yet",
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                            : GridView.builder(
                              padding: EdgeInsets.all(8),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _peers.length > 3 ? 2 : 1,
                                    childAspectRatio: 1.0,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                              itemCount: _peers.length,
                              itemBuilder: (context, index) {
                                final peer = _peers[index];
                                final isLocalPeer = peer.isLocal;

                                // Determine if this is a remote peer with active video
                                final hasRemoteTrack =
                                    !isLocalPeer &&
                                    _remoteVideoTracks.containsKey(peer.peerId);

                                // For remote peers, prioritize tracks from our map
                                HMSVideoTrack? videoTrack;
                                if (isLocalPeer) {
                                  videoTrack = peer.videoTrack;
                                } else {
                                  // Use our stored remote track first, fallback to peer.videoTrack
                                  videoTrack =
                                      _remoteVideoTracks[peer.peerId] ??
                                      peer.videoTrack;
                                }

                                final hasVideoTrack =
                                    videoTrack != null && !videoTrack.isMute;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: Color(0xFF333333),
                                    borderRadius: BorderRadius.circular(8),
                                    // Add a colored border for peers with active remote video
                                    border:
                                        hasRemoteTrack
                                            ? Border.all(
                                              color: Colors.greenAccent,
                                              width: 2,
                                            )
                                            : null,
                                  ),
                                  child: Stack(
                                    children: [
                                      // Video or avatar - styled exactly as in example
                                      Center(
                                        child:
                                            hasVideoTrack
                                                ? HMSVideoView(
                                                  track: videoTrack!,
                                                  scaleType:
                                                      ScaleType
                                                          .SCALE_ASPECT_FILL,
                                                )
                                                : Container(
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  color: Colors.black,
                                                  child: Center(
                                                    child: Container(
                                                      width: 80,
                                                      height: 80,
                                                      decoration: BoxDecoration(
                                                        color: _getAvatarColor(
                                                          peer.name,
                                                        ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      alignment:
                                                          Alignment.center,
                                                      child: Text(
                                                        _getInitials(peer.name),
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 36,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                      ),

                                      // Video indicator for remote peers with active video
                                      if (hasRemoteTrack)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.videocam,
                                              color: Colors.greenAccent,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      // Name and mic status overlay
                                      Positioned(
                                        bottom: 8,
                                        left: 8,
                                        right: 8,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                peer.audioTrack?.isMute == false
                                                    ? Icons.mic
                                                    : Icons.mic_off,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  "${peer.name}${isLocalPeer
                                                      ? ' (You)'
                                                      : hasRemoteTrack
                                                      ? ' (Remote)'
                                                      : ''}",
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
          ),

          // Video controls
          Container(
            padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mic button
                IconButton(
                  icon: Icon(
                    _isAudioOn ? Icons.mic : Icons.mic_off,
                    color:
                        _isAudioOn
                            ? (themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black)
                            : Colors.red,
                  ),
                  onPressed: _toggleAudio,
                  tooltip: _isAudioOn ? "Mute Microphone" : "Unmute Microphone",
                ),
                // Camera button
                IconButton(
                  icon: Icon(
                    _isVideoOn ? Icons.videocam : Icons.videocam_off,
                    color:
                        _isVideoOn
                            ? (themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black)
                            : Colors.red,
                  ),
                  onPressed: _toggleVideo,
                  tooltip: _isVideoOn ? "Turn Off Camera" : "Turn On Camera",
                ),
                // Screen share button
                IconButton(
                  icon: Icon(
                    _isScreenShareOn
                        ? Icons.stop_screen_share
                        : Icons.screen_share,
                    color:
                        _isScreenShareOn
                            ? Colors.green
                            : (themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black),
                  ),
                  onPressed: _toggleScreenShare,
                  tooltip:
                      _isScreenShareOn ? "Stop Screen Sharing" : "Share Screen",
                ),
                // Silent Study Mode button
                IconButton(
                  icon: Icon(
                    _isSilentStudyModeOn ? Icons.volume_off : Icons.volume_up,
                    color:
                        _isSilentStudyModeOn
                            ? Colors.red
                            : (themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black),
                  ),
                  onPressed: _toggleSilentStudyMode,
                  tooltip:
                      _isSilentStudyModeOn
                          ? "Disable Silent Study Mode"
                          : "Enable Silent Study Mode (Mutes All Other Participants)",
                ),
                // Leave button
                IconButton(
                  icon: Icon(Icons.call_end, color: Colors.red),
                  onPressed: _leaveVideoConference,
                  tooltip: "Leave Conference",
                ),
              ],
            ),
          ),
        ],
      );
    }
    // If using WebView fallback approach
    else if (_fallbackToWebView && _webViewController != null) {
      // WebView join screen
      if (!_isJoined) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam, size: 80, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                "Video Conference",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "Join the video conference to collaborate with others",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      themeProvider.isDarkMode
                          ? Colors.grey[400]
                          : Colors.grey[600],
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                icon: Icon(Icons.video_call),
                label: Text(_isJoining ? "Joining..." : "Join Conference"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _isJoining ? null : _joinVideoConference,
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      }

      // WebView joined state
      return Column(
        children: [
          // WebView container
          Expanded(
            child: Container(
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: WebViewWidget(controller: _webViewController!),
            ),
          ),

          // Info text about fallback mode
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Using web-based conference mode",
              style: TextStyle(
                color:
                    themeProvider.isDarkMode
                        ? Colors.grey[400]
                        : Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    // Error state - neither approach is working
    else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
            SizedBox(height: 16),
            Text(
              "Video Conference Unavailable",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                "We're having trouble initializing the video conference. Please try again later.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      themeProvider.isDarkMode
                          ? Colors.grey[400]
                          : Colors.grey[600],
                ),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text("Try Again"),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _initializeHMSSDK,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildLiveChat() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      children: [
        // Chat messages
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _messagesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error loading messages'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!.docs;

              if (messages.isEmpty) {
                return Center(
                  child: Text('No messages yet. Start the conversation!'),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(8.0),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message =
                      messages[index].data() as Map<String, dynamic>;
                  final isCurrentUser =
                      message['senderId'] == _auth.currentUser?.uid;

                  return Align(
                    alignment:
                        isCurrentUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 4.0),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isCurrentUser
                                ? Theme.of(context).primaryColor
                                : themeProvider.isDarkMode
                                ? Theme.of(context).colorScheme.surface
                                : Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isCurrentUser)
                            Text(
                              message['sender'] ?? 'Anonymous',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color:
                                    themeProvider.isDarkMode
                                        ? Colors.grey[300]
                                        : Colors.black87,
                              ),
                            ),
                          Text(
                            message['message'] ?? '',
                            style: TextStyle(
                              color:
                                  isCurrentUser
                                      ? Colors.white
                                      : themeProvider.isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Message input
        Container(
          padding: EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
