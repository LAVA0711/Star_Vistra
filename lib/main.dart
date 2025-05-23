import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'track_satellites.dart';
import 'augmented_reality.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VideoBackground(),
    );
  }
}

class VideoBackground extends StatefulWidget {
  const VideoBackground({super.key});

  @override
  _VideoBackgroundState createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground>
    with TickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool isVideoInitialized = false;

  late AnimationController _arAnimationController;
  late Animation<double> _arScaleAnimation;

  late AnimationController _trackAnimationController;
  late Animation<double> _trackScaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset("assets/videos/background.mp4")
      ..initialize().then((_) {
        setState(() {
          isVideoInitialized = true;
        });
        _controller.setLooping(true);
        _controller.setVolume(0);
        _controller.play();
      }).catchError((error) {
        print("Video Error: $error");
      });

    _arAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.8,
      upperBound: 1.0,
    );
    _arScaleAnimation =
        Tween<double>(begin: 1.0, end: 0.8).animate(_arAnimationController);

    _trackAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.8,
      upperBound: 1.0,
    );
    _trackScaleAnimation =
        Tween<double>(begin: 1.0, end: 0.8).animate(_trackAnimationController);
  }

  @override
  void dispose() {
    _controller.dispose();
    _arAnimationController.dispose();
    _trackAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: isVideoInitialized
                ? FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            )
                : const Center(child: CircularProgressIndicator()),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Text(
                            "Satellite Tracker App",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      GestureDetector(
                        onTapDown: (_) => _arAnimationController.reverse(),
                        onTapUp: (_) {
                          _arAnimationController.forward();
                          Future.delayed(const Duration(milliseconds: 100), () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                  const AugmentedRealityPage()),
                            );
                          });
                        },
                        child: ScaleTransition(
                          scale: _arScaleAnimation,
                          child: ElevatedButton(
                            onPressed: () {
                              _arAnimationController.reverse();
                              Future.delayed(const Duration(milliseconds: 100),
                                      () {
                                    _arAnimationController.forward();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                          const AugmentedRealityPage()),
                                    );
                                  });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white, // Ensures text is white
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 15),
                            ),
                            child: const Text("Augmented Reality",
                                style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      GestureDetector(
                        onTapDown: (_) => _trackAnimationController.reverse(),
                        onTapUp: (_) {
                          _trackAnimationController.forward();
                          Future.delayed(const Duration(milliseconds: 100), () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const TrackSatellitesPage()),
                            );
                          });
                        },
                        child: ScaleTransition(
                          scale: _trackScaleAnimation,
                          child: ElevatedButton(
                            onPressed: () {
                              _trackAnimationController.reverse();
                              Future.delayed(const Duration(milliseconds: 100),
                                      () {
                                    _trackAnimationController.forward();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                          const TrackSatellitesPage()),
                                    );
                                  });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white, // Ensures text is white
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 15),
                            ),
                            child: const Text("Track Satellites",
                                style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: Colors.white,
                        child: const Center(
                          child: Text(
                            "Your Gateway to the Stars",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}