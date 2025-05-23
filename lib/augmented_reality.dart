import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'services/satellite_service.dart';
import 'models/Satellite.dart';

class AugmentedRealityPage extends StatefulWidget {
  const AugmentedRealityPage({super.key});

  @override
  State<AugmentedRealityPage> createState() => _AugmentedRealityPageState();
}

class _AugmentedRealityPageState extends State<AugmentedRealityPage> {
  late WebViewController _webViewController;
  bool _isLoading = false;
  Timer? _loadingTimer;
  bool _noSatellitesFound = false;
  bool _satelliteAdded = false;
  String? _errorMessage;
  List<Satellite> _satellites = [];
  bool _isInitializing = true;
  bool _useCamera = false;
  bool _cameraReady = false;
  bool _showCameraInstructions = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _startSatelliteTimeout();
  }

  void _startSatelliteTimeout() {
    Future.delayed(const Duration(seconds: 20), () {
      if (!_satelliteAdded && mounted) {
        setState(() {
          _noSatellitesFound = true;
        });
      }
    });
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isInitializing = false;
              });
            }
            // Delay to ensure WebView is fully loaded
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) _loadARScene();
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ WebView Error: ${error.description}');
            if (mounted) {
              setState(() {
                _errorMessage = null; // Don't show connection errors, use fallback
                _isLoading = false;
              });
            }
          },
          onHttpError: (HttpResponseError error) {
            debugPrint('❌ HTTP Error: ${error.response?.statusCode}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJavaScriptMessage(message.message);
        },
      );

    // Load embedded HTML directly to avoid connection issues
    _loadEmbeddedHtml();
  }

  void _loadEmbeddedHtml() async {
    try {
      await _webViewController.loadHtmlString(_getFullArHtmlContent());
    } catch (e) {
      debugPrint('❌ Failed to load embedded HTML: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize AR system: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _handleJavaScriptMessage(String message) {
    try {
      Map<String, dynamic> data = json.decode(message);
      String type = data['type'];

      debugPrint('📥 Received from WebView: $type');

      if (!mounted) return;

      switch (type) {
        case 'satelliteAdded':
          setState(() {
            _satelliteAdded = true;
          });
          break;
        case 'satelliteClicked':
          _showSatelliteDetailDialog(data['satellite']);
          break;
        case 'satellitePosition':
          debugPrint('🛰️ Satellite position update');
          break;
        case 'error':
          setState(() {
            _errorMessage = data['message'] ?? 'Unknown AR error';
          });
          break;
        case 'arReady':
          debugPrint('✅ AR.js is ready');
          break;
        case 'cameraReady':
          debugPrint('📷 Camera initialized');
          setState(() {
            _useCamera = true;
            _cameraReady = true;
            _showCameraInstructions = false;
          });
          break;
        case 'cameraError':
          debugPrint('❌ Camera error: ${data['message']}');
          setState(() {
            _useCamera = false;
            _cameraReady = false;
          });
          break;
        case 'instructionsDismissed':
          setState(() {
            _showCameraInstructions = false;
          });
          break;
      }
    } catch (e) {
      debugPrint('❌ Error parsing JavaScript message: $e');
    }
  }

  void _showSatelliteDetailDialog(Map<String, dynamic> satelliteData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.satellite_alt, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                satelliteData['name'] ?? 'Unknown Satellite',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', satelliteData['id']?.toString() ?? 'Unknown'),
              _buildDetailRow('Altitude', '${satelliteData['altitude']?.toStringAsFixed(1) ?? 'Unknown'} km'),
              _buildDetailRow('Latitude', '${satelliteData['latitude']?.toStringAsFixed(4) ?? 'Unknown'}°'),
              _buildDetailRow('Longitude', '${satelliteData['longitude']?.toStringAsFixed(4) ?? 'Unknown'}°'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About this Satellite:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This satellite is currently orbiting at ${satelliteData['altitude']?.toStringAsFixed(0) ?? 'unknown'} km above Earth. '
                          'It appears in your sky view based on your current location and the satellite\'s orbital position.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _loadARScene() async {
    if (!mounted) return;

    try {
      debugPrint('📍 Getting location...');
      Position position = await _getCurrentLocation();
      debugPrint("📍 Location: ${position.latitude}, ${position.longitude}");

      debugPrint('🛰️ Fetching satellites...');
      List<Satellite> satellites = await SatelliteService.fetchSatellitesAbove(
          position.latitude,
          position.longitude
      );

      if (satellites.isEmpty) {
        if (mounted) {
          setState(() {
            _noSatellitesFound = true;
          });
        }
        return;
      }

      _satellites = satellites;
      await _sendSatelliteDataToWebView(satellites, position.latitude, position.longitude);

    } catch (e) {
      debugPrint("❌ AR Scene loading error: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Location/Satellite error: $e';
        });
      }
    }
  }

  Future<void> _sendSatelliteDataToWebView(List<Satellite> satellites, double userLat, double userLon) async {
    if (!mounted) return;

    List<Map<String, dynamic>> satelliteData = [];

    for (Satellite satellite in satellites.take(8)) {
      if (satellite.latitude == null || satellite.longitude == null) {
        continue;
      }

      // Calculate azimuth and elevation for realistic positioning
      double latDiff = satellite.latitude! - userLat;
      double lonDiff = satellite.longitude! - userLon;

      // Convert to 3D coordinates for AR positioning
      double azimuth = math.atan2(lonDiff, latDiff);
      double distance = math.sqrt(latDiff * latDiff + lonDiff * lonDiff);
      double elevation = math.atan2(satellite.altitude ?? 400, distance * 111.32); // km per degree

      satelliteData.add({
        'name': satellite.name ?? 'Unknown Satellite',
        'id': satellite.id ?? 'unknown',
        'altitude': satellite.altitude ?? 400,
        'latitude': satellite.latitude,
        'longitude': satellite.longitude,
        'azimuth': azimuth,
        'elevation': elevation,
        'distance': distance,
      });
    }

    Map<String, dynamic> message = {
      'type': 'updateSatellites',
      'data': {
        'satellites': satelliteData,
        'userLocation': {
          'latitude': userLat,
          'longitude': userLon,
        }
      }
    };

    try {
      await _webViewController.runJavaScript('''
        console.log('📤 Sending satellite data to WebView');
        if (typeof window.handleFlutterMessage === 'function') {
          window.handleFlutterMessage(${json.encode(message)});
        }
      ''');

      if (mounted) {
        setState(() {
          _satelliteAdded = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to send data to WebView: $e');
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled. Please enable location services.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied. Please allow location access.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission permanently denied. Please enable in settings.");
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
  }

  String _getFullArHtmlContent() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <title>AR Satellite Tracker</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
    <style>
        body { 
            margin: 0; 
            font-family: 'Segoe UI', Arial, sans-serif; 
            background: #000; 
            color: #fff; 
            overflow: hidden;
            touch-action: pan-x pan-y;
        }
        
        .ar-container {
            position: relative;
            width: 100%;
            height: 100vh;
            overflow: hidden;
        }
        
        #videoElement {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            object-fit: cover;
            z-index: 1;
        }
        
        #threeCanvas {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            z-index: 2;
            pointer-events: auto;
        }
        
        .camera-instructions {
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: rgba(0, 0, 0, 0.9);
            padding: 30px;
            border-radius: 15px;
            text-align: center;
            z-index: 1000;
            border: 2px solid #4CAF50;
            box-shadow: 0 0 30px rgba(76, 175, 80, 0.3);
            max-width: 300px;
        }
        
        .camera-instructions h3 {
            color: #4CAF50;
            margin-bottom: 15px;
            font-size: 20px;
        }
        
        .camera-instructions p {
            margin-bottom: 20px;
            line-height: 1.5;
        }
        
        .camera-instructions button {
            background: #4CAF50;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 25px;
            cursor: pointer;
            font-size: 16px;
            transition: background 0.3s;
        }
        
        .camera-instructions button:hover {
            background: #45a049;
        }
        
        .status-overlay {
            position: fixed;
            top: 20px;
            left: 20px;
            right: 20px;
            background: rgba(0, 0, 0, 0.8);
            padding: 15px;
            border-radius: 10px;
            border: 1px solid #4CAF50;
            z-index: 100;
            text-align: center;
            backdrop-filter: blur(10px);
        }
        
        .controls-overlay {
            position: fixed;
            bottom: 20px;
            left: 20px;
            right: 20px;
            background: rgba(0, 0, 0, 0.8);
            padding: 15px;
            border-radius: 10px;
            border: 1px solid #4CAF50;
            z-index: 100;
            text-align: center;
            backdrop-filter: blur(10px);
        }
        
        .loading {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            background: linear-gradient(45deg, #1a1a2e, #16213e);
        }
        
        .spinner {
            border: 3px solid #333;
            border-top: 3px solid #4CAF50;
            border-radius: 50%;
            width: 50px;
            height: 50px;
            animation: spin 1s linear infinite;
            margin-bottom: 20px;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .satellite-info-popup {
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: rgba(0, 0, 0, 0.95);
            padding: 20px;
            border-radius: 15px;
            border: 2px solid #4CAF50;
            z-index: 1000;
            max-width: 300px;
            display: none;
            backdrop-filter: blur(10px);
        }
        
        .camera-error {
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: rgba(255, 0, 0, 0.1);
            border: 2px solid #ff4444;
            padding: 20px;
            border-radius: 15px;
            text-align: center;
            z-index: 1000;
            backdrop-filter: blur(10px);
        }
    </style>
</head>
<body>
    <div id="loading" class="loading">
        <div class="spinner"></div>
        <h2>🚀 Initializing AR System</h2>
        <p>Setting up camera and satellite tracking...</p>
    </div>
    
    <div id="cameraInstructions" class="camera-instructions" style="display: none;">
        <h3>📱 Hold Camera Towards Sky</h3>
        <p>Point your device camera towards the sky to see satellites in augmented reality.</p>
        <p><strong>Note:</strong> Move slowly and keep the camera steady for best results.</p>
        <button onclick="dismissInstructions()">Got It!</button>
    </div>
    
    <div id="arContainer" class="ar-container" style="display: none;">
        <video id="videoElement" autoplay muted playsinline></video>
        <canvas id="threeCanvas"></canvas>
        
        <div id="statusOverlay" class="status-overlay">
            <p>🛰️ AR Satellite Tracker Active</p>
            <p id="satelliteCount">Satellites: 0</p>
            <p id="locationStatus">📍 Getting location...</p>
        </div>
        
        <div class="controls-overlay">
            <p><strong>Controls:</strong> Pinch to zoom • Drag to pan • Tap satellites for info</p>
        </div>
    </div>
    
    <div id="cameraError" class="camera-error" style="display: none;">
        <h3>📷 Camera Access Required</h3>
        <p>Please allow camera access and point towards the sky to see satellites</p>
        <button onclick="initCamera()">Try Again</button>
    </div>
    
    <script>
        console.log('🚀 AR System loading...');
        
        let scene, camera, renderer;
        let satellites = [];
        let satelliteObjects = [];
        let userLocation = null;
        let isInitialized = false;
        let videoElement;
        let isDragging = false;
        let previousMousePosition = { x: 0, y: 0 };
        let cameraRotation = { x: 0, y: 0 };
        let zoomLevel = 1;
        
        // Initialize AR system
        setTimeout(() => {
            initAR();
        }, 2000);
        
        function initAR() {
            document.getElementById('loading').style.display = 'none';
            document.getElementById('cameraInstructions').style.display = 'block';
        }
        
        function dismissInstructions() {
            document.getElementById('cameraInstructions').style.display = 'none';
            document.getElementById('arContainer').style.display = 'block';
            initCamera();
            initThreeJS();
            
            if (window.FlutterChannel) {
                window.FlutterChannel.postMessage(JSON.stringify({
                    type: 'instructionsDismissed'
                }));
            }
        }
        
        function initCamera() {
            videoElement = document.getElementById('videoElement');
            
            if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
                const constraints = {
                    video: {
                        facingMode: 'environment', // Use back camera
                        width: { ideal: 1280 },
                        height: { ideal: 720 }
                    }
                };
                
                navigator.mediaDevices.getUserMedia(constraints)
                    .then(stream => {
                        videoElement.srcObject = stream;
                        videoElement.play();
                        
                        console.log('📷 Camera access granted');
                        if (window.FlutterChannel) {
                            window.FlutterChannel.postMessage(JSON.stringify({
                                type: 'cameraReady'
                            }));
                        }
                    })
                    .catch(err => {
                        console.log('❌ Camera access denied:', err);
                        document.getElementById('cameraError').style.display = 'block';
                        
                        if (window.FlutterChannel) {
                            window.FlutterChannel.postMessage(JSON.stringify({
                                type: 'cameraError',
                                data: { message: err.message }
                            }));
                        }
                    });
            }
        }
        
        function initThreeJS() {
            const canvas = document.getElementById('threeCanvas');
            scene = new THREE.Scene();
            
            camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
            camera.position.set(0, 0, 0);
            
            renderer = new THREE.WebGLRenderer({ canvas: canvas, alpha: true });
            renderer.setSize(window.innerWidth, window.innerHeight);
            renderer.setClearColor(0x000000, 0); // Transparent background
            
            // Add lighting
            const ambientLight = new THREE.AmbientLight(0x404040, 0.6);
            scene.add(ambientLight);
            
            const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
            directionalLight.position.set(1, 1, 1);
            scene.add(directionalLight);
            
            // Add touch controls
            addTouchControls(canvas);
            
            // Start render loop
            animate();
            
            if (window.FlutterChannel) {
                window.FlutterChannel.postMessage(JSON.stringify({
                    type: 'arReady'
                }));
            }
            
            isInitialized = true;
        }
        
        function addTouchControls(canvas) {
            let touches = [];
            let lastTouchDistance = 0;
            
            canvas.addEventListener('touchstart', (e) => {
                e.preventDefault();
                touches = Array.from(e.touches);
                
                if (touches.length === 1) {
                    isDragging = true;
                    previousMousePosition = {
                        x: touches[0].clientX,
                        y: touches[0].clientY
                    };
                } else if (touches.length === 2) {
                    lastTouchDistance = getTouchDistance(touches);
                }
            }, { passive: false });
            
            canvas.addEventListener('touchmove', (e) => {
                e.preventDefault();
                touches = Array.from(e.touches);
                
                if (touches.length === 1 && isDragging) {
                    // Pan
                    const deltaX = touches[0].clientX - previousMousePosition.x;
                    const deltaY = touches[0].clientY - previousMousePosition.y;
                    
                    cameraRotation.y += deltaX * 0.01;
                    cameraRotation.x += deltaY * 0.01;
                    
                    // Limit vertical rotation
                    cameraRotation.x = Math.max(-Math.PI/2, Math.min(Math.PI/2, cameraRotation.x));
                    
                    updateCameraRotation();
                    
                    previousMousePosition = {
                        x: touches[0].clientX,
                        y: touches[0].clientY
                    };
                } else if (touches.length === 2) {
                    // Zoom
                    const currentDistance = getTouchDistance(touches);
                    const zoomDelta = (currentDistance - lastTouchDistance) * 0.01;
                    zoomLevel = Math.max(0.5, Math.min(3, zoomLevel + zoomDelta));
                    
                    camera.fov = 75 / zoomLevel;
                    camera.updateProjectionMatrix();
                    
                    lastTouchDistance = currentDistance;
                }
            }, { passive: false });
            
            canvas.addEventListener('touchend', (e) => {
                e.preventDefault();
                isDragging = false;
                touches = [];
            }, { passive: false });
            
            // Mouse controls for desktop testing
            canvas.addEventListener('mousedown', (e) => {
                isDragging = true;
                previousMousePosition = { x: e.clientX, y: e.clientY };
            });
            
            canvas.addEventListener('mousemove', (e) => {
                if (isDragging) {
                    const deltaX = e.clientX - previousMousePosition.x;
                    const deltaY = e.clientY - previousMousePosition.y;
                    
                    cameraRotation.y += deltaX * 0.01;
                    cameraRotation.x += deltaY * 0.01;
                    cameraRotation.x = Math.max(-Math.PI/2, Math.min(Math.PI/2, cameraRotation.x));
                    
                    updateCameraRotation();
                    
                    previousMousePosition = { x: e.clientX, y: e.clientY };
                }
            });
            
            canvas.addEventListener('mouseup', () => {
                isDragging = false;
            });
            
            canvas.addEventListener('wheel', (e) => {
                e.preventDefault();
                const zoomDelta = e.deltaY * -0.001;
                zoomLevel = Math.max(0.5, Math.min(3, zoomLevel + zoomDelta));
                
                camera.fov = 75 / zoomLevel;
                camera.updateProjectionMatrix();
            }, { passive: false });
        }
        
        function getTouchDistance(touches) {
            const dx = touches[0].clientX - touches[1].clientX;
            const dy = touches[0].clientY - touches[1].clientY;
            return Math.sqrt(dx * dx + dy * dy);
        }
        
        function updateCameraRotation() {
            camera.rotation.order = 'YXZ';
            camera.rotation.y = cameraRotation.y;
            camera.rotation.x = cameraRotation.x;
        }
        
        function createSatellite3D(satelliteData) {
            const group = new THREE.Group();
            
            // Main satellite body
            const bodyGeometry = new THREE.BoxGeometry(0.8, 0.8, 1.2);
            const bodyMaterial = new THREE.MeshPhongMaterial({ 
                color: 0xcccccc,
                shininess: 100
            });
            const body = new THREE.Mesh(bodyGeometry, bodyMaterial);
            group.add(body);
            
            // Solar panels
            const panelGeometry = new THREE.BoxGeometry(1.5, 0.1, 0.8);
            const panelMaterial = new THREE.MeshPhongMaterial({ 
                color: 0x1a237e,
                shininess: 50
            });
            
            const leftPanel = new THREE.Mesh(panelGeometry, panelMaterial);
            leftPanel.position.set(-1.2, 0, 0);
            group.add(leftPanel);
            
            const rightPanel = new THREE.Mesh(panelGeometry, panelMaterial);
            rightPanel.position.set(1.2, 0, 0);
            group.add(rightPanel);
            
            // Antenna
            const antennaGeometry = new THREE.CylinderGeometry(0.02, 0.02, 0.8);
            const antennaMaterial = new THREE.MeshPhongMaterial({ color: 0xffffff });
            const antenna = new THREE.Mesh(antennaGeometry, antennaMaterial);
            antenna.position.set(0, 0.8, 0);
            group.add(antenna);
            
            // Glow effect
            const glowGeometry = new THREE.SphereGeometry(1.5);
            const glowMaterial = new THREE.MeshBasicMaterial({
                color: 0x4CAF50,
                transparent: true,
                opacity: 0.2
            });
            const glow = new THREE.Mesh(glowGeometry, glowMaterial);
            group.add(glow);
            
            // Position satellite based on azimuth and elevation
            const distance = 50; // Fixed distance for AR visualization
            const x = Math.sin(satelliteData.azimuth) * Math.cos(satelliteData.elevation) * distance;
            const y = Math.sin(satelliteData.elevation) * distance;
            const z = -Math.cos(satelliteData.azimuth) * Math.cos(satelliteData.elevation) * distance;
            
            group.position.set(x, y, z);
            group.userData = satelliteData;
            
            // Add click detection
            group.userData.clickable = true;
            
            return group;
        }
        
        function animate() {
            requestAnimationFrame(animate);
            
            // Rotate satellites slightly
            satelliteObjects.forEach((satellite, index) => {
                satellite.rotation.y += 0.01;
                satellite.children[4].rotation.y += 0.02; // Glow rotation
                
                // Subtle floating animation
                const time = Date.now() * 0.001;
                satellite.position.y += Math.sin(time + index) * 0.02;
            });
            
            renderer.render(scene, camera);
        }
        
        // Handle Flutter messages
        window.handleFlutterMessage = function(message) {
            console.log('📥 Received from Flutter:', message);
            
            if (message.type === 'updateSatellites') {
                satellites = message.data.satellites;
                userLocation = message.data.userLocation;
                updateSatelliteDisplay();
                
                document.getElementById('satelliteCount').textContent = 
                    'Satellites: ' + satellites.length;
                document.getElementById('locationStatus').textContent = 
                    '📍 Location: ' + userLocation.latitude.toFixed(2) + ', ' + userLocation.longitude.toFixed(2);
                
                if (window.FlutterChannel) {
                    window.FlutterChannel.postMessage(JSON.stringify({
                        type: 'satelliteAdded',
                        data: { count: satellites.length }
                    }));
                }
            }
        };
        
        function updateSatelliteDisplay() {
            if (!isInitialized || !scene) return;
            
            // Clear existing satellites
            satelliteObjects.forEach(satellite => {
                scene.remove(satellite);
            });
            satelliteObjects = [];
            
            // Add new satellites
            satellites.forEach(satelliteData => {
                const satellite3D = createSatellite3D(satelliteData);
                scene.add(satellite3D);
                satelliteObjects.push(satellite3D);
            });
            
            console.log('✅ Updated satellite display with', satellites.length, 'satellites');
        }
        
        // Handle satellite clicks
        function onSatelliteClick(event) {
            event.preventDefault();
            
            const mouse = new THREE.Vector2();
            mouse.x = (event.clientX / window.innerWidth) * 2 - 1;
            mouse.y = -(event.clientY / window.innerHeight) * 2 + 1;
            
            const raycaster = new THREE.Raycaster();
            raycaster.setFromCamera(mouse, camera);
            
            const intersects = raycaster.intersectObjects(satelliteObjects, true);
            
            if (intersects.length > 0) {
                const clickedSatellite = intersects[0].object.parent;
                const satelliteData = clickedSatellite.userData;
                
                if (satelliteData && window.FlutterChannel) {
                    window.FlutterChannel.postMessage(JSON.stringify({
                        type: 'satelliteClicked',
                        satellite: satelliteData
                    }));
                }
            }
        }
        
        // Add click listener after DOM is loaded
        document.addEventListener('DOMContentLoaded', function() {
            setTimeout(() => {
                const canvas = document.getElementById('threeCanvas');
                if (canvas) {
                    canvas.addEventListener('click', onSatelliteClick);
                }
            }, 3000);
        });
        
        // Handle window resize
        window.addEventListener('resize', () => {
            if (camera && renderer) {
                camera.aspect = window.innerWidth / window.innerHeight;
                camera.updateProjectionMatrix();
                renderer.setSize(window.innerWidth, window.innerHeight);
            }
        });
        
        // Add touch-specific satellite selection
        function onTouchEnd(event) {
            if (event.changedTouches.length === 1 && !isDragging) {
                const touch = event.changedTouches[0];
                const mouse = new THREE.Vector2();
                mouse.x = (touch.clientX / window.innerWidth) * 2 - 1;
                mouse.y = -(touch.clientY / window.innerHeight) * 2 + 1;
                
                const raycaster = new THREE.Raycaster();
                raycaster.setFromCamera(mouse, camera);
                
                const intersects = raycaster.intersectObjects(satelliteObjects, true);
                
                if (intersects.length > 0) {
                    const clickedSatellite = intersects[0].object.parent;
                    const satelliteData = clickedSatellite.userData;
                    
                    if (satelliteData && window.FlutterChannel) {
                        window.FlutterChannel.postMessage(JSON.stringify({
                            type: 'satelliteClicked',
                            satellite: satelliteData
                        }));
                    }
                }
            }
        }
        
        // Add touch listener after canvas is created
        setTimeout(() => {
            const canvas = document.getElementById('threeCanvas');
            if (canvas) {
                canvas.addEventListener('touchend', onTouchEnd);
            }
        }, 3000);
        
        console.log('✅ AR System initialized');
    </script>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AR Satellite Tracker'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isInitializing && _cameraReady)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadARScene,
              tooltip: 'Refresh Satellites',
            ),
          if (_satellites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: _showSatelliteListDialog,
              tooltip: 'Satellite List',
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          if (_errorMessage != null)
            _buildErrorView()
          else if (_noSatellitesFound)
            _buildNoSatellitesView()
          else
            WebViewWidget(controller: _webViewController),

          // Loading overlay
          if (_isLoading || _isInitializing)
            _buildLoadingOverlay(),

          // Camera instructions overlay
          if (_showCameraInstructions && !_isLoading)
            _buildCameraInstructionsOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraInstructionsOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.green, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 20),
              const Text(
                '📱 Hold Camera Towards Sky',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Point your device camera towards the sky to see satellites in augmented reality.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Move slowly and keep the camera steady for best results.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showCameraInstructions = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Got It!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('How to Use AR Satellite Tracker'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '📱 Camera Setup:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              Text('• Allow camera access when prompted'),
              Text('• Point camera towards the sky'),
              Text('• Hold device steady for best results'),
              SizedBox(height: 12),
              Text(
                '🛰️ Viewing Satellites:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              Text('• Satellites appear as glowing 3D models'),
              Text('• Tap any satellite for detailed information'),
              Text('• Satellites are positioned based on real orbital data'),
              SizedBox(height: 12),
              Text(
                '🎮 Controls:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              Text('• Drag to pan the view'),
              Text('• Pinch to zoom in/out'),
              Text('• Tap satellites for information'),
              SizedBox(height: 12),
              Text(
                '📍 Location:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              Text('• GPS location is used to find satellites above you'),
              Text('• Refresh to update satellite positions'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSatelliteListDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Visible Satellites'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: _satellites.length,
            itemBuilder: (context, index) {
              final satellite = _satellites[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Icon(Icons.satellite_alt, color: Colors.green),
                  ),
                  title: Text(
                    satellite.name ?? 'Unknown Satellite',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (satellite.altitude != null)
                        Text('🚀 Altitude: ${satellite.altitude!.toStringAsFixed(1)} km'),
                      if (satellite.latitude != null && satellite.longitude != null)
                        Text('🌍 Position: ${satellite.latitude!.toStringAsFixed(2)}°, ${satellite.longitude!.toStringAsFixed(2)}°'),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showSatelliteDetailDialog({
                      'name': satellite.name,
                      'id': satellite.id,
                      'altitude': satellite.altitude,
                      'latitude': satellite.latitude,
                      'longitude': satellite.longitude,
                    });
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isLoading = true;
                  });
                  _loadEmbeddedHtml();
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Go Back", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoSatellitesView() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.satellite_alt, color: Colors.grey, size: 64),
            const SizedBox(height: 16),
            const Text(
              "No satellites found above your location",
              style: TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Satellites may be out of range or below the horizon.\nTry again in a few minutes or move to a different location.",
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _noSatellitesFound = false;
                  _isLoading = true;
                });
                _loadARScene();
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Try Again"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Go Back", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.green,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              _isInitializing ? "🚀 Initializing AR System..." : "📡 Loading Satellite Data...",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isInitializing
                  ? "Setting up camera and 3D rendering..."
                  : "Getting your location and finding satellites above you...",
              style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}