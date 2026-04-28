import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DisguiseScreen extends StatefulWidget {
  const DisguiseScreen({super.key});

  @override
  State<DisguiseScreen> createState() => _DisguiseScreenState();
}

class _DisguiseScreenState extends State<DisguiseScreen> {
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    // 1. Hide Status Bar & Nav Bar completely (Looks like phone is dead)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // 2. Restore normal UI when leaving this screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _holdTimer?.cancel();
    super.dispose();
  }

  // --- LOGIC: Hold for 3 seconds to Exit ---
  void _startHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 3), () {
      // Success! Vibrate and Exit
      HapticFeedback.heavyImpact();
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  void _cancelHoldTimer() {
    _holdTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    // 3. Block Physical Back Button
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          // Detect touch down/up for the custom timer
          onLongPressDown: (_) => _startHoldTimer(),
          onLongPressUp: () => _cancelHoldTimer(),
          onLongPressCancel: () => _cancelHoldTimer(),
          // Ensure touches are caught everywhere
          behavior: HitTestBehavior.opaque,
          child: SizedBox.expand(
            child: Center(
              // Faint text to trick anyone looking at the screen
              child: Text(
                "System Halted.",
                style: TextStyle(
                  color: Colors.grey[900], // Almost invisible
                  fontSize: 10,
                  fontFamily: "Courier", // Looks like code
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
