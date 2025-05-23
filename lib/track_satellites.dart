import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'models/satellite_type.dart';
import 'services/satellite_service.dart';
import 'satellite_visualization.dart';
import 'models/Satellite.dart';

class TrackSatellitesPage extends StatefulWidget {
  const TrackSatellitesPage({super.key});

  @override
  State<TrackSatellitesPage> createState() => _TrackSatellitesPageState();
}

class _TrackSatellitesPageState extends State<TrackSatellitesPage> {
  List<SatelliteType> satelliteTypes = [];
  List<Satellite> availableSatellites = [];
  SatelliteType? selectedType;
  List<Satellite> selectedSatellites = [];
  int selectedNumberOfSatellites = 1;
  final List<int> satelliteNumbers = [1, 2, 3, 4, 5];
  String warningMessage = '';
  String? errorMessage;
  bool isLoadingTypes = false;
  bool isLoadingSatellites = false;
  bool showDebugInfo = false;
  List<String> debugLogs = [];

  late VideoPlayerController _controller;
  bool _controllerInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _addDebugLog('🚀 TrackSatellitesPage initializing...');
    fetchTypes();
  }

  void _addDebugLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logEntry = '[$timestamp] $message';
    setState(() {
      debugLogs.add(logEntry);
      // Keep only last 50 logs to prevent memory issues
      if (debugLogs.length > 50) {
        debugLogs.removeAt(0);
      }
    });
    debugPrint(logEntry);
  }

  void _initializeVideo() {
    _addDebugLog('📹 Initializing background video...');
    _controller = VideoPlayerController.asset('assets/videos/background.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _controllerInitialized = true;
          });
          _controller.setLooping(true);
          _controller.play();
          _addDebugLog('✅ Background video initialized');
        }
      }).catchError((error) {
        _addDebugLog('❌ Video initialization error: $error');
        // Continue without video background
        if (mounted) {
          setState(() {
            _controllerInitialized = false;
          });
        }
      });
  }

  Future<void> fetchTypes() async {
    _addDebugLog('📡 Fetching satellite types...');
    setState(() {
      isLoadingTypes = true;
      errorMessage = null;
    });

    try {
      final types = await SatelliteService.fetchSatelliteTypes();
      if (mounted) {
        setState(() {
          satelliteTypes = types;
          isLoadingTypes = false;
          if (types.isNotEmpty) {
            selectedType = types.first;
            _addDebugLog('✅ Loaded ${types.length} satellite types');
            fetchSatellites(selectedType!.categoryId);
          } else {
            _addDebugLog('⚠️ No satellite types found');
            warningMessage = 'No satellite types available';
          }
        });
      }
    } catch (e) {
      _addDebugLog('❌ Error loading satellite types: $e');
      if (mounted) {
        setState(() {
          isLoadingTypes = false;
          errorMessage = 'Failed to load satellite types: $e';
        });
      }
    }
  }

  Future<void> fetchSatellites(int categoryId) async {
    if (selectedType == null) return;

    _addDebugLog('🛰️ Fetching satellites for category: $categoryId');
    setState(() {
      isLoadingSatellites = true;
      errorMessage = null;
    });

    try {
      final satellites = await SatelliteService.fetchSatellitesByCategory(categoryId);
      satellites.sort((a, b) => a.name.compareTo(b.name));

      // Check for duplicate IDs and remove them
      final uniqueSatellites = <Satellite>[];
      final seenIds = <int>{};

      for (final satellite in satellites) {
        if (!seenIds.contains(satellite.id)) {
          seenIds.add(satellite.id);
          uniqueSatellites.add(satellite);
        }
      }

      if (mounted) {
        setState(() {
          availableSatellites = uniqueSatellites;
          isLoadingSatellites = false;
          // Reset selected satellites when changing categories
          selectedSatellites = [];
          warningMessage = '';

          // Only add satellites if available
          if (availableSatellites.isNotEmpty) {
            final toSelect = availableSatellites.length < selectedNumberOfSatellites
                ? availableSatellites.length
                : selectedNumberOfSatellites;
            selectedSatellites = availableSatellites.take(toSelect).toList();
            _addDebugLog('✅ Loaded ${uniqueSatellites.length} satellites, selected ${selectedSatellites.length}');
          } else {
            _addDebugLog('⚠️ No satellites found for category');
            warningMessage = 'No satellites available for this type';
          }
        });
      }
    } catch (e) {
      _addDebugLog('❌ Error loading satellites: $e');
      if (mounted) {
        setState(() {
          isLoadingSatellites = false;
          errorMessage = 'Failed to load satellites: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _addDebugLog('🔄 Disposing TrackSatellitesPage');
    _controller.dispose();
    super.dispose();
  }

  void handleTrack() {
    if (selectedSatellites.isEmpty) {
      setState(() {
        warningMessage = "Please select at least one satellite.";
      });
      _addDebugLog('⚠️ Attempted to track with no satellites selected');
      return;
    }

    _addDebugLog('🎯 Tracking ${selectedSatellites.length} satellites');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SatelliteVisualization(satellites: selectedSatellites),
        ),
      ).then((_) {
        // Re-add debug log when returning from visualization
        _addDebugLog('🔄 Returned from satellite visualization');
      });
    } catch (e) {
      _addDebugLog('❌ Navigation error: $e');
      setState(() {
        errorMessage = 'Navigation failed: $e';
      });
    }
  }

  void handleSatelliteSelection(Satellite satellite) {
    setState(() {
      // Check if the satellite is already selected
      if (selectedSatellites.any((selected) => selected.id == satellite.id)) {
        // Remove it if it's already selected
        selectedSatellites.removeWhere((selected) => selected.id == satellite.id);
        warningMessage = '';
        _addDebugLog('➖ Removed satellite: ${satellite.name}');
      } else {
        // Add it if there's room
        if (selectedSatellites.length < selectedNumberOfSatellites) {
          selectedSatellites.add(satellite);
          warningMessage = '';
          _addDebugLog('➕ Added satellite: ${satellite.name}');
        } else {
          warningMessage = "You can only select up to $selectedNumberOfSatellites satellites.";
          _addDebugLog('⚠️ Cannot add more satellites, limit reached');
        }
      }
    });
  }

  // Open the satellite selector dialog
  void _openSatelliteSelector() async {
    if (availableSatellites.isEmpty) {
      setState(() {
        warningMessage = "No satellites available for selection.";
      });
      _addDebugLog('⚠️ No satellites available for selection');
      return;
    }

    // Filter out satellites that are already selected
    final unselectedSatellites = availableSatellites
        .where((sat) => !selectedSatellites.any((selected) => selected.id == sat.id))
        .toList();

    if (unselectedSatellites.isEmpty) {
      setState(() {
        warningMessage = "All satellites already selected.";
      });
      _addDebugLog('⚠️ All satellites already selected');
      return;
    }

    _addDebugLog('📋 Opening satellite selector with ${unselectedSatellites.length} options');

    // Show the dialog and wait for the result
    final result = await showDialog<Satellite>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Select a Satellite"),
          content: SizedBox(
            width: double.maxFinite,
            child: unselectedSatellites.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No satellites available'),
            )
                : ListView.builder(
              shrinkWrap: true,
              itemCount: unselectedSatellites.length,
              itemBuilder: (context, index) {
                final satellite = unselectedSatellites[index];
                return ListTile(
                  title: Text(satellite.name),
                  subtitle: satellite.id != null
                      ? Text('ID: ${satellite.id}', style: const TextStyle(fontSize: 12))
                      : null,
                  onTap: () {
                    Navigator.of(context).pop(satellite);
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    // Handle the selected satellite
    if (result != null) {
      handleSatelliteSelection(result);
    }
  }

  void _toggleDebugInfo() {
    setState(() {
      showDebugInfo = !showDebugInfo;
    });
    _addDebugLog('🐛 Debug info ${showDebugInfo ? "shown" : "hidden"}');
  }

  void _clearDebugLogs() {
    setState(() {
      debugLogs.clear();
    });
    _addDebugLog('🧹 Debug logs cleared');
  }

  void _retryOperation() {
    _addDebugLog('🔄 Retrying failed operation');
    setState(() {
      errorMessage = null;
      warningMessage = '';
    });

    if (satelliteTypes.isEmpty) {
      fetchTypes();
    } else if (selectedType != null && availableSatellites.isEmpty) {
      fetchSatellites(selectedType!.categoryId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background video or fallback
          if (_controllerInitialized && _controller.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          else
          // Fallback background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0F0F23), Color(0xFF1A1A2E)],
                  ),
                ),
              ),
            ),

          // Overlay
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.4))),

          // Main content
          Center(
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with debug toggle
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                              "Track Satellites",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            showDebugInfo ? Icons.bug_report : Icons.bug_report_outlined,
                            color: showDebugInfo ? Colors.green : Colors.grey,
                          ),
                          onPressed: _toggleDebugInfo,
                          tooltip: 'Debug Info',
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Error message display
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                              ),
                            ),
                            TextButton(
                              onPressed: _retryOperation,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Satellite Type dropdown with loading indicator
                    Row(
                      children: [
                        const Expanded(
                          flex: 4,
                          child: Text("Satellite Type", style: TextStyle(fontSize: 14)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: Stack(
                            children: [
                              buildDropdownRow<SatelliteType>(
                                "Satellite Type",
                                satelliteTypes,
                                selectedType,
                                    (value) {
                                  setState(() {
                                    selectedType = value;
                                    selectedSatellites.clear();
                                    warningMessage = '';
                                    if (selectedType != null) {
                                      fetchSatellites(selectedType!.categoryId);
                                    }
                                  });
                                },
                              ),
                              if (isLoadingTypes)
                                Positioned(
                                  right: 30,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Number of satellites dropdown
                    Row(
                      children: [
                        const Expanded(
                          flex: 4,
                          child: Text("Number of Satellites", style: TextStyle(fontSize: 14)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: buildDropdownRow<int>(
                            "Number of Satellites",
                            satelliteNumbers,
                            selectedNumberOfSatellites,
                                (value) {
                              setState(() {
                                selectedNumberOfSatellites = value!;
                                // Clear selection when changing number of satellites
                                selectedSatellites.clear();
                                warningMessage = '';
                              });
                              _addDebugLog('🔢 Changed satellite count to: $selectedNumberOfSatellites');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Satellite selector with loading indicator
                    Row(
                      children: [
                        const Expanded(
                          flex: 4,
                          child: Text("Satellites", style: TextStyle(fontSize: 14)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: Stack(
                            children: [
                              buildCustomSatelliteSelector(),
                              if (isLoadingSatellites)
                                Positioned(
                                  right: 30,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Selected satellites chips
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: selectedSatellites.map((satellite) {
                          return Chip(
                            label: Text(satellite.name, style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () => handleSatelliteSelection(satellite),
                            backgroundColor: Colors.blue.shade100,
                          );
                        }).toList(),
                      ),
                    ),

                    // Warning message
                    if (warningMessage.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.orange.shade600, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                  warningMessage,
                                  style: TextStyle(color: Colors.orange.shade700, fontSize: 13)
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 15),

                    // Track button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedSatellites.isEmpty ? Colors.grey : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: selectedSatellites.isEmpty ? null : handleTrack,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.track_changes, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Track ${selectedSatellites.length} Satellite${selectedSatellites.length != 1 ? 's' : ''}",
                              style: const TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Debug info panel
                    if (showDebugInfo) ...[
                      const SizedBox(height: 15),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.terminal, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Debug Logs',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.clear_all, size: 16),
                                    onPressed: _clearDebugLogs,
                                    tooltip: 'Clear logs',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: debugLogs.length,
                                itemBuilder: (context, index) {
                                  final log = debugLogs[index];
                                  Color logColor = Colors.black87;

                                  if (log.contains('❌')) logColor = Colors.red;
                                  else if (log.contains('✅')) logColor = Colors.green.shade700;
                                  else if (log.contains('⚠️')) logColor = Colors.orange.shade700;
                                  else if (log.contains('🛰️')) logColor = Colors.blue.shade700;
                                  else if (log.contains('📡')) logColor = Colors.purple.shade700;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 1),
                                    child: Text(
                                      log,
                                      style: TextStyle(
                                        color: logColor,
                                        fontSize: 10,
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
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Custom satellite selector button
  Widget buildCustomSatelliteSelector() {
    // Get the count of available unselected satellites
    final availableCount = availableSatellites
        .where((sat) => !selectedSatellites.any((selected) => selected.id == sat.id))
        .length;

    final isEnabled = selectedSatellites.length < selectedNumberOfSatellites &&
        availableCount > 0 &&
        !isLoadingSatellites;

    return OutlinedButton(
      onPressed: isEnabled ? _openSatelliteSelector : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        alignment: Alignment.centerLeft,
        side: BorderSide(color: isEnabled ? Colors.black : Colors.grey),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isLoadingSatellites
                ? "Loading..."
                : availableCount == 0
                ? "No satellites available"
                : "Select Satellite ($availableCount available)",
            style: TextStyle(
              fontSize: 12,
              color: isEnabled ? Colors.black : Colors.grey,
            ),
          ),
          Icon(
            Icons.arrow_drop_down,
            color: isEnabled ? Colors.black : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget buildDropdownRow<T>(
      String label,
      List<T> items,
      T? selectedValue,
      Function(T?) onChanged,
      ) {
    // Improved value existence check
    bool valueExists = false;
    if (selectedValue != null) {
      if (selectedValue is SatelliteType) {
        valueExists = items.any((item) =>
        item is SatelliteType && item.categoryId == (selectedValue).categoryId);
      } else {
        valueExists = items.contains(selectedValue);
      }
    }

    return DropdownButtonFormField<T>(
      value: valueExists ? selectedValue : null,
      hint: Text("Select $label", style: const TextStyle(fontSize: 12)),
      items: items.map((item) {
        String displayText;
        Key itemKey;

        if (item is SatelliteType) {
          displayText = item.name;
          itemKey = ValueKey('type-${item.categoryId}');
        } else {
          displayText = item.toString();
          itemKey = ValueKey('item-${item.hashCode}');
        }

        return DropdownMenuItem<T>(
          key: itemKey,
          value: item,
          child: Text(
            displayText,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: items.isEmpty ? null : (value) {
        if (value != null) {
          onChanged(value);
        }
      },
      isExpanded: true,
      decoration: dropdownDecoration(),
    );
  }

  InputDecoration dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blue),
      ),
    );
  }
}