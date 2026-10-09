import 'package:flutter/material.dart';

/// Splash visuals only. Navigation away from it lives in
/// SplashScreenRedirect (main.dart); a second timer here used to push the
/// main screen a second time.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      body: SafeArea(
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween, // Space top and bottom
            crossAxisAlignment:
                CrossAxisAlignment.center, // Center horizontally
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 150),
                child: Image.asset(
                  'assets/splash/forditva-logo.png',
                  width: 300,
                  fit: BoxFit.contain,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Image.asset(
                  'assets/splash/Logo-WIU.png',
                  width: 250,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
