import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/intro/rotate.mp4')
      ..initialize().then((_) {
        _controller.setLooping(false);
        _controller.play();
        _controller.addListener(() {
          if (_controller.value.isInitialized &&
              !_controller.value.isPlaying &&
              _controller.value.position >= _controller.value.duration) {
            _navigateToHome();
          }
        });
        //refresh to show initialized video
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Ensure a full black background
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
          aspectRatio: _controller.value.aspectRatio, // Maintain video ratio
          child: VideoPlayer(_controller),
        )
            : const CircularProgressIndicator(), // Show loader until the video is initialized
      ),
    );
  }

  void _navigateToHome() {
    Navigator.of(context)
        .pushReplacementNamed('/home'); // Change `/home` to your route
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose the controller to free resources
    super.dispose();
  }
}
