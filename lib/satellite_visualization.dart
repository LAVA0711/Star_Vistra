import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'services/satellite_service.dart';
import 'models/Satellite.dart';

class SatelliteVisualization extends StatefulWidget {
  final List<Satellite>? satellites; // Accept satellites from track page

  const SatelliteVisualization({super.key, this.satellites});

  @override
  State<SatelliteVisualization> createState() => _SatelliteVisualizationState();
}

class _SatelliteVisualizationState extends State<SatelliteVisualization> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  bool _singleMode = false;
  bool _showDebugConsole = false;
  bool _showSatelliteInfo = false;
  List<String> _debugLogs = [];
  String? _errorMessage;
  List<Satellite> _satellites = [];
  int _currentSatelliteIndex = 0;
  PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _addDebugLog('🚀 3D Visualization initializing...');

    // Use provided satellites or fetch them
    if (widget.satellites != null && widget.satellites!.isNotEmpty) {
      _satellites = widget.satellites!;
      _addDebugLog('📦 Using provided ${_satellites.length} satellites');
    }
  }

  void _addDebugLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logEntry = '[$timestamp] $message';
    if (mounted) {
      setState(() {
        _debugLogs.add(logEntry);
        // Keep only last 100 logs to prevent memory issues
        if (_debugLogs.length > 100) {
          _debugLogs.removeAt(0);
        }
      });
    }
    debugPrint(logEntry);
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            _addDebugLog('📄 Loading 3D scene...');
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (String url) {
            _addDebugLog('✅ 3D scene loaded successfully');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            _loadSatelliteData();
          },
          onWebResourceError: (WebResourceError error) {
            _addDebugLog('❌ WebView Error: ${error.description}');
            if (mounted) {
              setState(() {
                _errorMessage = '3D Loading Error: ${error.description}';
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'Flutter3D',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJavaScriptMessage(message.message);
        },
      )
      ..loadHtmlString(_get3DVisualizationHTML());
  }

  void _handleJavaScriptMessage(String message) {
    try {
      Map<String, dynamic> data = json.decode(message);
      String type = data['type'];

      _addDebugLog('📥 Received: $type');

      switch (type) {
        case 'sceneReady':
          _addDebugLog('🎭 3D Scene initialized');
          break;
        case 'satelliteAdded':
          _addDebugLog('🛰️ Satellite added: ${data['name']}');
          break;
        case 'cameraReset':
          _addDebugLog('📷 Camera position reset');
          break;
        case 'modeChanged':
          _addDebugLog('🔄 Mode changed to: ${data['mode']}');
          break;
        case 'satelliteChanged':
          if (mounted) {
            setState(() {
              _currentSatelliteIndex = data['index'] ?? 0;
              if (_pageController.hasClients) {
                _pageController.animateToPage(
                  _currentSatelliteIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            });
          }
          break;
        case 'error':
          _addDebugLog('❌ Error: ${data['message']}');
          break;
        case 'console':
          _addDebugLog('🌐 JS: ${data['message']}');
          break;
      }
    } catch (e) {
      _addDebugLog('❌ Error parsing message: $e');
    }
  }

  void _loadSatelliteData() async {
    try {
      // If satellites were provided, use them directly
      if (_satellites.isNotEmpty) {
        _addDebugLog('📍 Using provided satellites, getting location...');
        Position position = await _getCurrentLocation();
        _addDebugLog('📍 Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');
        await _sendSatelliteDataTo3D(_satellites, position.latitude, position.longitude);
        return;
      }

      // Otherwise fetch satellites above current location
      _addDebugLog('📍 Getting location...');
      Position position = await _getCurrentLocation();
      _addDebugLog('📍 Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');

      _addDebugLog('🛰️ Fetching satellites...');
      List<Satellite> satellites = await SatelliteService.fetchSatellitesAbove(
          position.latitude,
          position.longitude
      );

      _addDebugLog('📊 Found ${satellites.length} satellites');

      if (satellites.isNotEmpty) {
        _satellites = satellites;
        await _sendSatelliteDataTo3D(satellites, position.latitude, position.longitude);
      } else {
        _addDebugLog('⚠️ No satellites found above location');
      }
    } catch (e) {
      _addDebugLog('❌ Error loading satellites: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Satellite loading error: $e';
        });
      }
    }
  }

  Future<void> _sendSatelliteDataTo3D(List<Satellite> satellites, double userLat, double userLon) async {
    List<Map<String, dynamic>> satelliteData = [];
// Replace this section (around lines 190-205):
    for (int i = 0; i < satellites.length; i++) {
      final satellite = satellites[i];
      if (satellite.latitude == null || satellite.longitude == null) continue;

      // Calculate proper 3D spherical coordinates
      double lat = satellite.latitude! * (math.pi / 180); // Convert to radians
      double lon = satellite.longitude! * (math.pi / 180); // Convert to radians
      double altitude = satellite.altitude ?? 400;

      // Earth radius in the same units as our 3D scene (Earth sphere radius = 5)
      double earthRadius = 5.0;
      double satelliteDistance = earthRadius + (altitude * 0.01); // Scale altitude appropriately

      // Convert spherical coordinates to Cartesian (3D) coordinates
      double x = satelliteDistance * math.cos(lat) * math.cos(lon);
      double y = satelliteDistance * math.sin(lat);
      double z = satelliteDistance * math.cos(lat) * math.sin(lon);

      // Calculate distances
      double distanceFromEarth = altitude;
      double distanceFromMoon = 384400 - altitude;

      satelliteData.add({
        'id': satellite.id ?? 'sat_$i',
        'name': satellite.name ?? 'Satellite $i',
        'latitude': satellite.latitude,
        'longitude': satellite.longitude,
        'altitude': altitude,
        'distanceFromEarth': distanceFromEarth,
        'distanceFromMoon': distanceFromMoon,
        'x': x,
        'y': y,
        'z': z,
        'color': _getSatelliteColor(i),
      });
    }
    Map<String, dynamic> message = {
      'type': 'loadSatellites',
      'data': {
        'satellites': satelliteData,
        'userLocation': {'latitude': userLat, 'longitude': userLon},
        'singleMode': _singleMode,
      }
    };

    await _webViewController.runJavaScript('''
      if (typeof window.handleFlutterMessage === 'function') {
        window.handleFlutterMessage(${json.encode(message)});
      }
    ''');

    _addDebugLog('📤 Sent ${satelliteData.length} satellites to 3D scene');
  }

  String _getSatelliteColor(int index) {
    List<String> colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7', '#DDA0DD'];
    return colors[index % colors.length];
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services disabled");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied");
      }
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }

  void _toggleSingleMode() {
    setState(() {
      _singleMode = !_singleMode;
    });
    _addDebugLog('🔄 Toggled to ${_singleMode ? "single" : "all"} satellite view');

    _webViewController.runJavaScript('''
      if (typeof window.toggleSingleMode === 'function') {
        window.toggleSingleMode($_singleMode);
      }
    ''');
  }

  void _resetCameraPosition() {
    _addDebugLog('📷 Camera position reset');
    _webViewController.runJavaScript('''
      if (typeof window.resetCamera === 'function') {
        window.resetCamera();
      }
    ''');
  }

  void _toggleDebugConsole() {
    setState(() {
      _showDebugConsole = !_showDebugConsole;
      if (_showDebugConsole) {
        _showSatelliteInfo = false; // Hide info when showing debug
      }
    });
    _addDebugLog('🐛 Debug console ${_showDebugConsole ? "shown" : "hidden"}');
  }

  void _toggleSatelliteInfo() {
    setState(() {
      _showSatelliteInfo = !_showSatelliteInfo;
      if (_showSatelliteInfo) {
        _showDebugConsole = false; // Hide debug when showing info
      }
    });
    _addDebugLog('ℹ️ Satellite info ${_showSatelliteInfo ? "shown" : "hidden"}');
  }

  void _onSatellitePageChanged(int index) {
    setState(() {
      _currentSatelliteIndex = index;
    });

    // Highlight satellite in 3D view
    _webViewController.runJavaScript('''
      if (typeof window.highlightSatellite === 'function') {
        window.highlightSatellite($index);
      }
    ''');

    // If in single mode, show the selected satellite
    if (_singleMode) {
      _webViewController.runJavaScript('''
        if (typeof window.showSatelliteAtIndex === 'function') {
          window.showSatelliteAtIndex($index);
        }
      ''');
    }
  }

  String _get3DVisualizationHTML() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>3D Satellite Visualization</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
    <style>
        body { margin: 0; padding: 0; background: #000; overflow: hidden; font-family: Arial, sans-serif; }
        #container { width: 100vw; height: 100vh; position: relative; }
        #loading { 
            position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);
            color: white; text-align: center; z-index: 1000;
        }
        .spinner { 
            border: 3px solid #333; border-top: 3px solid #fff; border-radius: 50%;
            width: 40px; height: 40px; animation: spin 1s linear infinite; margin: 0 auto 20px;
        }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        #info {
            position: absolute; top: 10px; left: 10px; color: white; 
            background: rgba(0,0,0,0.7); padding: 10px; border-radius: 5px;
            font-size: 12px; max-width: 300px; z-index: 100;
        }
        #singleModeInfo {
            position: absolute; bottom: 10px; left: 50%; transform: translateX(-50%);
            color: white; background: rgba(0,0,0,0.8); padding: 8px 16px; border-radius: 20px;
            font-size: 14px; z-index: 100; display: none;
        }
    </style>
</head>
<body>
    <div id="container">
        <div id="loading">
            <div class="spinner"></div>
            <h3>Loading 3D Satellite Visualization</h3>
            <p>Initializing Three.js scene...</p>
        </div>
        <div id="info">
            <div>🛰️ 3D Satellite Tracker</div>
            <div>Use mouse/touch to rotate and zoom</div>
            <div id="satelliteCount">Satellites: 0</div>
        </div>
        <div id="singleModeInfo">
            <div id="currentSatelliteName">Satellite Name</div>
            <div id="currentSatelliteId">ID: 12345</div>
        </div>
    </div>

    <script>
        // Global variables
        let scene, camera, renderer, controls;
        let satellites = [];
        let satelliteHighlights = [];
        let earth, satelliteGroup;
        let singleMode = false;
        let currentSatelliteIndex = 0;
        let satellitesData = [];

        // Console logging function that sends to Flutter
        function logToFlutter(message) {
            if (window.Flutter3D) {
                window.Flutter3D.postMessage(JSON.stringify({
                    type: 'console',
                    message: message,
                    timestamp: Date.now()
                }));
            }
        }

        // Override console.log to capture messages
        const originalLog = console.log;
        console.log = function(...args) {
            const message = args.map(arg => typeof arg === 'object' ? JSON.stringify(arg) : String(arg)).join(' ');
            logToFlutter(message);
            originalLog.apply(console, args);
        };

        // Initialize Three.js scene
        function init() {
            console.log('🚀 Initializing 3D scene...');
            
            // Scene setup
            scene = new THREE.Scene();
            scene.background = new THREE.Color(0x000011);

            // Camera setup
            camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
            camera.position.set(0, 10, 20);

            // Renderer setup
            renderer = new THREE.WebGLRenderer({ antialias: true });
            renderer.setSize(window.innerWidth, window.innerHeight);
            renderer.shadowMap.enabled = true;
            renderer.shadowMap.type = THREE.PCFSoftShadowMap;
            
            // Add renderer to container
            const container = document.getElementById('container');
            container.appendChild(renderer.domElement);

            // Controls setup
            if (typeof THREE.OrbitControls !== 'undefined') {
                controls = new THREE.OrbitControls(camera, renderer.domElement);
                controls.enableDamping = true;
                controls.dampingFactor = 0.05;
                controls.enableZoom = true;
                controls.enablePan = true;
            } else {
                console.warn('OrbitControls not loaded, using basic mouse controls');
                setupBasicControls();
            }

            // Add lighting
            const ambientLight = new THREE.AmbientLight(0x404040, 0.6);
            scene.add(ambientLight);

            const directionalLight = new THREE.DirectionalLight(0xffffff, 1);
            directionalLight.position.set(50, 50, 50);
            directionalLight.castShadow = true;
            scene.add(directionalLight);

            // Create Earth
            createEarth();

            // Create satellite group
            satelliteGroup = new THREE.Group();
            scene.add(satelliteGroup);

            // Add stars
            createStarField();

            // Hide loading screen
            document.getElementById('loading').style.display = 'none';
            
            // Start render loop
            animate();
            
            console.log('✅ 3D scene initialized');
            sendMessageToFlutter('sceneReady', {});
        }

        function createEarth() {
            const earthGeometry = new THREE.SphereGeometry(5, 32, 32);
            const earthMaterial = new THREE.MeshPhongMaterial({
                color: 0x2194ce,
                shininess: 100,
                transparent: true,
                opacity: 0.8
            });
            
            earth = new THREE.Mesh(earthGeometry, earthMaterial);
            earth.receiveShadow = true;
            scene.add(earth);

            // Add atmosphere
            const atmosphereGeometry = new THREE.SphereGeometry(5.2, 32, 32);
            const atmosphereMaterial = new THREE.MeshBasicMaterial({
                color: 0x87ceeb,
                transparent: true,
                opacity: 0.1,
                side: THREE.BackSide
            });
            const atmosphere = new THREE.Mesh(atmosphereGeometry, atmosphereMaterial);
            scene.add(atmosphere);
        }

        function createStarField() {
            const starGeometry = new THREE.BufferGeometry();
            const starCount = 1000;
            const positions = new Float32Array(starCount * 3);

            for (let i = 0; i < starCount * 3; i++) {
                positions[i] = (Math.random() - 0.5) * 200;
            }

            starGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
            const starMaterial = new THREE.PointsMaterial({ color: 0xffffff, size: 0.1 });
            const stars = new THREE.Points(starGeometry, starMaterial);
            scene.add(stars);
        }
        function createAltitudeLine(satelliteData) {
    // Create line from Earth surface to satellite
    const earthRadius = 5;
    
    // Calculate Earth surface point (directly below satellite)
    const earthSurfacePoint = new THREE.Vector3(
        satelliteData.x,
        satelliteData.y,
        satelliteData.z
    ).normalize().multiplyScalar(earthRadius);
    
    // Satellite position
    const satellitePoint = new THREE.Vector3(
        satelliteData.x,
        satelliteData.y,
        satelliteData.z
    );
    
    // Create line geometry
    const lineGeometry = new THREE.BufferGeometry().setFromPoints([
        earthSurfacePoint,
        satellitePoint
    ]);
    
    // Create line material (semi-transparent)
    const lineMaterial = new THREE.LineBasicMaterial({
        color: satelliteData.color || 0x4CC3D9,
        transparent: true,
        opacity: 0.3,
        linewidth: 2
    });
    
    // Create line
    const line = new THREE.Line(lineGeometry, lineMaterial);
    
    return line;
}
        function createSatellite(satelliteData) {
            const group = new THREE.Group();

            // More realistic satellite model
            // Main body (cylindrical)
            const bodyGeometry = new THREE.CylinderGeometry(0.3, 0.3, 0.8, 8);
            const bodyMaterial = new THREE.MeshPhongMaterial({ 
                color: satelliteData.color || 0x4CC3D9,
                shininess: 50
            });
            const body = new THREE.Mesh(bodyGeometry, bodyMaterial);
            body.castShadow = true;
            group.add(body);

            // Solar panels (larger and more detailed)
            const panelGeometry = new THREE.BoxGeometry(2.4, 0.04, 1.2);
            const panelMaterial = new THREE.MeshPhongMaterial({ 
                color: 0x1a1a2e,
                shininess: 100
            });

            const leftPanel = new THREE.Mesh(panelGeometry, panelMaterial);
            leftPanel.position.set(-1.6, 0, 0);
            group.add(leftPanel);

            const rightPanel = new THREE.Mesh(panelGeometry, panelMaterial);
            rightPanel.position.set(1.6, 0, 0);
            group.add(rightPanel);

            // Communication dish
            const dishGeometry = new THREE.ConeGeometry(0.1, 0.05, 8);
            const dishMaterial = new THREE.MeshPhongMaterial({ color: 0xffffff });
            const dish = new THREE.Mesh(dishGeometry, dishMaterial);
            dish.position.set(0, 0.25, 0);
            dish.rotation.x = Math.PI;
            group.add(dish);

            // Antennas
            const antennaGeometry = new THREE.CylinderGeometry(0.005, 0.005, 0.3);
            const antennaMaterial = new THREE.MeshPhongMaterial({ color: 0xff6b6b });
            
            const antenna1 = new THREE.Mesh(antennaGeometry, antennaMaterial);
            antenna1.position.set(0.1, 0.35, 0.1);
            group.add(antenna1);
            
            const antenna2 = new THREE.Mesh(antennaGeometry, antennaMaterial);
            antenna2.position.set(-0.1, 0.35, -0.1);
            group.add(antenna2);

            // Label
            const canvas = document.createElement('canvas');
            const context = canvas.getContext('2d');
            canvas.width = 256;
            canvas.height = 64;
            context.fillStyle = 'white';
            context.font = '16px Arial';
            context.textAlign = 'center';
            context.fillText(satelliteData.name, 128, 40);

            const texture = new THREE.CanvasTexture(canvas);
            const labelMaterial = new THREE.SpriteMaterial({ map: texture, transparent: true });
            const label = new THREE.Sprite(labelMaterial);
            label.position.set(0, 1.2, 0);
            label.scale.set(2, 0.5, 1);
            group.add(label);

            // Position the satellite
            group.position.set(satelliteData.x, satelliteData.y, satelliteData.z);
            
            // Add rotation animation
            group.userData = {
                rotationSpeed: Math.random() * 0.02 + 0.01,
                originalPosition: group.position.clone(),
                satelliteData: satelliteData
            };

            return group;
        }

        function createHighlight(satellite) {
            // Create green square highlight
            const highlightGeometry = new THREE.PlaneGeometry(3, 3);
            const highlightMaterial = new THREE.MeshBasicMaterial({
                color: 0x00ff00,
                transparent: true,
                opacity: 0.3,
                side: THREE.DoubleSide
            });
            const highlight = new THREE.Mesh(highlightGeometry, highlightMaterial);
            
            // Position highlight behind satellite
            highlight.position.copy(satellite.position);
            highlight.position.z -= 0.5;
            highlight.lookAt(camera.position);
            
            return highlight;
        }

        function setupBasicControls() {
            let isDragging = false;
            let previousMousePosition = { x: 0, y: 0 };

            renderer.domElement.addEventListener('mousedown', (e) => {
                isDragging = true;
                previousMousePosition = { x: e.clientX, y: e.clientY };
            });

            renderer.domElement.addEventListener('mousemove', (e) => {
                if (isDragging) {
                    const deltaMove = {
                        x: e.clientX - previousMousePosition.x,
                        y: e.clientY - previousMousePosition.y
                    };

                    const deltaRotationQuaternion = new THREE.Quaternion()
                        .setFromEuler(new THREE.Euler(
                            toRadians(deltaMove.y * 1),
                            toRadians(deltaMove.x * 1),
                            0,
                            'XYZ'
                        ));

                    camera.quaternion.multiplyQuaternions(deltaRotationQuaternion, camera.quaternion);
                    previousMousePosition = { x: e.clientX, y: e.clientY };
                }
            });

            renderer.domElement.addEventListener('mouseup', () => {
                isDragging = false;
            });

            renderer.domElement.addEventListener('wheel', (e) => {
                const scale = e.deltaY > 0 ? 1.1 : 0.9;
                camera.position.multiplyScalar(scale);
            });

            // Add swipe support for mobile
            let touchStartX = 0;
            let touchStartY = 0;

            renderer.domElement.addEventListener('touchstart', (e) => {
                touchStartX = e.touches[0].clientX;
                touchStartY = e.touches[0].clientY;
            });

            renderer.domElement.addEventListener('touchend', (e) => {
                const touchEndX = e.changedTouches[0].clientX;
                const touchEndY = e.changedTouches[0].clientY;
                const deltaX = touchEndX - touchStartX;
                const deltaY = touchEndY - touchStartY;

                // Detect swipe
                if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 50) {
                    if (singleMode && satellites.length > 1) {
                        if (deltaX > 0) {
                            // Swipe right - next satellite
                            currentSatelliteIndex = (currentSatelliteIndex + 1) % satellites.length;
                        } else {
                            // Swipe left - previous satellite
                            currentSatelliteIndex = (currentSatelliteIndex - 1 + satellites.length) % satellites.length;
                        }
                        showSatelliteAtIndex(currentSatelliteIndex);
                        sendMessageToFlutter('satelliteChanged', { index: currentSatelliteIndex });
                    }
                }
            });
        }

        function toRadians(angle) {
            return angle * (Math.PI / 180);
        }

        function animate() {
            requestAnimationFrame(animate);

            // Rotate Earth
            if (earth) {
                earth.rotation.y += 0.001;
            }

            // Animate satellites
            satelliteGroup.children.forEach(satellite => {
                if (satellite.userData && satellite.userData.rotationSpeed) {
                    satellite.rotation.y += satellite.userData.rotationSpeed;
                }
            });

            // Update highlights to face camera
            satelliteHighlights.forEach(highlight => {
                if (highlight.visible) {
                    highlight.lookAt(camera.position);
                }
            });

            // Update controls
            if (controls) {
                controls.update();
            }

            renderer.render(scene, camera);
        }

        // Handle window resize
        window.addEventListener('resize', () => {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        });
function createAltitudeLine(satelliteData) {
    // Create line from Earth surface to satellite
    const earthRadius = 5;
    
    // Calculate Earth surface point (directly below satellite)
    const earthSurfacePoint = new THREE.Vector3(
        satelliteData.x,
        satelliteData.y,
        satelliteData.z
    ).normalize().multiplyScalar(earthRadius);
    
    // Satellite position
    const satellitePoint = new THREE.Vector3(
        satelliteData.x,
        satelliteData.y,
        satelliteData.z
    );
    
    // Create line geometry
    const lineGeometry = new THREE.BufferGeometry().setFromPoints([
        earthSurfacePoint,
        satellitePoint
    ]);
    
    // Create line material (semi-transparent)
    const lineMaterial = new THREE.LineBasicMaterial({
        color: satelliteData.color || 0x4CC3D9,
        transparent: true,
        opacity: 0.3,
        linewidth: 2
    });
    
    // Create line
    const line = new THREE.Line(lineGeometry, lineMaterial);
    
    return line;
}
        // Flutter communication functions
        function sendMessageToFlutter(type, data) {
            const message = { type: type, data: data, timestamp: Date.now() };
            if (window.Flutter3D) {
                window.Flutter3D.postMessage(JSON.stringify(message));
            }
            console.log('📤 Sent to Flutter:', message);
        }

        window.handleFlutterMessage = function(message) {
            console.log('📥 Received from Flutter:', message);
            
            if (message.type === 'loadSatellites') {
                loadSatellites(message.data);
            }
        };

        function loadSatellites(data) {
            console.log('🛰️ Loading satellites:', data.satellites.length);
            
            // Clear existing satellites and highlights
            satelliteGroup.clear();
            satelliteHighlights.forEach(highlight => scene.remove(highlight));
            satellites = [];
            satelliteHighlights = [];
            satellitesData = data.satellites;

            // Add satellites
data.satellites.forEach((satData, index) => {
    const satellite = createSatellite(satData);
    satelliteGroup.add(satellite);
    satellites.push(satellite);
    
    // Add altitude line
    const altitudeLine = createAltitudeLine(satData);
    satelliteGroup.add(altitudeLine);
    
    // Debug logging
    console.log('🛰️ Satellite ' + index + ': ' + satData.name);
    console.log('   Position: x=' + satData.x.toFixed(2) + ', y=' + satData.y.toFixed(2) + ', z=' + satData.z.toFixed(2));
    console.log('   Lat/Lon: ' + satData.latitude.toFixed(4) + ', ' + satData.longitude.toFixed(4));
    console.log('   Altitude: ' + satData.altitude.toFixed(2) + ' km');
    
    // Create highlight for each satellite
    const highlight = createHighlight(satellite);
    highlight.visible = false;
    scene.add(highlight);
    satelliteHighlights.push(highlight);
    
    // Add entrance animation
    satellite.scale.set(0, 0, 0);
    const targetScale = new THREE.Vector3(1, 1, 1);
    animateScale(satellite, targetScale, 1000 + index * 200);
    
    sendMessageToFlutter('satelliteAdded', { name: satData.name, index: index });
});
            // Update UI
            document.getElementById('satelliteCount').textContent = 'Satellites: ' + satellites.length;
            
            // Set single mode if requested
            if (data.singleMode) {
                toggleSingleMode(true);
            }
        }

        function animateScale(object, targetScale, duration) {
            const startScale = object.scale.clone();
            const startTime = Date.now();

            function update() {
                const elapsed = Date.now() - startTime;
                const progress = Math.min(elapsed / duration, 1);
                const eased = 1 - Math.pow(1 - progress, 3); // Ease-out cubic

                object.scale.lerpVectors(startScale, targetScale, eased);

                if (progress < 1) {
                    requestAnimationFrame(update);
                }
            }
            update();
        }

        window.toggleSingleMode = function(single) {
            singleMode = single;
            console.log('🔄 Toggle single mode:', singleMode);
            
            const singleModeInfo = document.getElementById('singleModeInfo');
            
            if (singleMode && satellites.length > 0) {
                // Show only one satellite
                showSatelliteAtIndex(currentSatelliteIndex);
                singleModeInfo.style.display = 'block';
                updateSingleModeInfo();
            } else {
                // Show all satellites
                satellites.forEach(sat => {
                    sat.visible = true;
                });
                // Hide all highlights
                satelliteHighlights.forEach(highlight => {
                    highlight.visible = false;
                });
                singleModeInfo.style.display = 'none';
            }
            
            sendMessageToFlutter('modeChanged', { mode: singleMode ? 'single' : 'all' });
        };

        window.showSatelliteAtIndex = function(index) {
            if (index >= 0 && index < satellites.length) {
                currentSatelliteIndex = index;
                
                satellites.forEach((sat, i) => {
                    sat.visible = (i === index);
                });
                
                // Hide all highlights first
                satelliteHighlights.forEach(highlight => {
                    highlight.visible = false;
                });
                
                // Show highlight for current satellite
                if (satelliteHighlights[index]) {
                    satelliteHighlights[index].visible = true;
                }
                
                updateSingleModeInfo();
            }
        };

        window.highlightSatellite = function(index) {
            // Hide all highlights first
            satelliteHighlights.forEach(highlight => {
                highlight.visible = false;
            });
            
            // Show highlight for selected satellite
            if (index >= 0 && index < satelliteHighlights.length) {
                satelliteHighlights[index].visible = true;
            }
        };

        function updateSingleModeInfo() {
            if (currentSatelliteIndex < satellitesData.length) {
                const satData = satellitesData[currentSatelliteIndex];
                document.getElementById('currentSatelliteName').textContent = satData.name;
                document.getElementById('currentSatelliteId').textContent = 'ID: ' + satData.id;
            }
        }

        window.resetCamera = function() {
            console.log('📷 Resetting camera position');
            camera.position.set(0, 10, 20);
            camera.lookAt(0, 0, 0);
            
            if (controls) {
                controls.reset();
            }
            
            sendMessageToFlutter('cameraReset', {});
        };

        // Initialize scene when page loads
        window.addEventListener('load', () => {
            console.log('🌐 Page loaded, initializing 3D scene');
            setTimeout(init, 100);
        });

        // Error handling
        window.addEventListener('error', (e) => {
            console.error('❌ 3D Error:', e.message);
            sendMessageToFlutter('error', { message: e.message });
        });

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
        title: Text(
            _satellites.isNotEmpty
                ? 'Visualizing ${_satellites.length} Satellites'
                : 'Satellite 3D Visualization'
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // Single Mode Toggle
          Row(
            children: [
              const Text(
                'Single Mode',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              Switch(
                value: _singleMode,
                onChanged: (value) => _toggleSingleMode(),
                activeColor: Colors.blue,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(width: 8),

          // Info Toggle
          IconButton(
            icon: Icon(
              _showSatelliteInfo ? Icons.info : Icons.info_outline,
              color: _showSatelliteInfo ? Colors.blue : Colors.white70,
            ),
            onPressed: _toggleSatelliteInfo,
            tooltip: 'Satellite Info',
          ),

          // Debug Console Toggle
          IconButton(
            icon: Icon(
              _showDebugConsole ? Icons.bug_report : Icons.bug_report_outlined,
              color: _showDebugConsole ? Colors.green : Colors.white70,
            ),
            onPressed: _toggleDebugConsole,
            tooltip: 'Debug Console',
          ),

          // Reset Camera
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _resetCameraPosition,
            tooltip: 'Reset Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main 3D WebView
          if (_errorMessage != null)
            _buildError()
          else
            WebViewWidget(controller: _webViewController),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading 3D Visualization...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Initializing Three.js scene',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // Satellite Info Panel
          if (_showSatelliteInfo && _satellites.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  border: Border(
                    top: BorderSide(color: Colors.blue.withOpacity(0.5), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Info Panel Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        border: Border(
                          bottom: BorderSide(color: Colors.blue.withOpacity(0.3)),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.satellite_alt, color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Satellite Details',
                            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '${_currentSatelliteIndex + 1} of ${_satellites.length}',
                            style: const TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    // Satellite Details PageView
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _satellites.length,
                        onPageChanged: _onSatellitePageChanged,
                        itemBuilder: (context, index) {
                          final satellite = _satellites[index];
                          return _buildSatelliteDetailCard(satellite, index);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Debug Console
          if (_showDebugConsole)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  border: Border(
                    top: BorderSide(color: Colors.green.withOpacity(0.5), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Debug Console Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        border: Border(
                          bottom: BorderSide(color: Colors.green.withOpacity(0.3)),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.terminal, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Debug Console',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.clear_all, color: Colors.green, size: 16),
                            onPressed: () {
                              setState(() {
                                _debugLogs.clear();
                              });
                            },
                            tooltip: 'Clear Logs',
                          ),
                        ],
                      ),
                    ),

                    // Debug Logs
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _debugLogs.length,
                        reverse: false,
                        itemBuilder: (context, index) {
                          final log = _debugLogs[index];
                          Color logColor = Colors.white70;

                          if (log.contains('❌')) logColor = Colors.red;
                          else if (log.contains('✅')) logColor = Colors.green;
                          else if (log.contains('⚠️')) logColor = Colors.orange;
                          else if (log.contains('🛰️')) logColor = Colors.blue;
                          else if (log.contains('📍')) logColor = Colors.purple;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              log,
                              style: TextStyle(
                                color: logColor,
                                fontSize: 11,
                                fontFamily: 'Courier New',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSatelliteDetailCard(Satellite satellite, int index) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Satellite Name
            Row(
              children: [
                Icon(Icons.satellite_alt, color: _getSatelliteColorAsColor(index), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    satellite.name ?? 'Unknown Satellite',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Details Grid
            _buildDetailRow('ID', satellite.id?.toString() ?? 'N/A'),
            _buildDetailRow('Latitude', satellite.latitude?.toStringAsFixed(6) ?? 'N/A'),
            _buildDetailRow('Longitude', satellite.longitude?.toStringAsFixed(6) ?? 'N/A'),
            _buildDetailRow('Altitude', '${satellite.altitude?.toStringAsFixed(2) ?? 'N/A'} km'),
            _buildDetailRow('Distance from Earth', '${satellite.altitude?.toStringAsFixed(2) ?? 'N/A'} km'),
            _buildDetailRow('Distance from Moon', '${(384400 - (satellite.altitude ?? 0)).toStringAsFixed(2)} km'),

            const SizedBox(height: 16),

            // Swipe Instruction
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.swipe, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Swipe left/right to navigate satellites',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSatelliteColorAsColor(int index) {
    List<Color> colors = [
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFF45B7D1),
      const Color(0xFF96CEB4),
      const Color(0xFFFFEAA7),
      const Color(0xFFDDA0DD),
    ];
    return colors[index % colors.length];
  }

  Widget _buildError() {
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
                  _initializeWebView();
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}