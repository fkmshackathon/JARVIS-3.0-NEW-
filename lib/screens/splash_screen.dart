import 'package:flutter/material.dart';

import '../brand/synchro_mark.dart';
import '../state/scheduling_controller.dart';
import '../theme/tokens.dart';
import 'app_shell.dart';

/// Branded entry into the frontend-only prototype. The scheduling backend is
/// intentionally not contacted during startup; the manual timetable workspace
/// is usable with local demo data before any external service is configured.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.controller});

  /// Kept for compatibility with the existing application boundary. Startup
  /// does not call it in the frontend-only prototype.
  final SchedulingController controller;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: SynchroMotion.settle,
  )..forward();

  bool _left = false;

  @override
  void initState() {
    super.initState();
    _enterWorkspace();
  }

  Future<void> _enterWorkspace() async {
    await _sweep.forward();
    if (!mounted || _left) return;
    _left = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: SynchroMotion.standard,
        reverseTransitionDuration: SynchroMotion.quick,
        pageBuilder: (_, _, _) => AppShell(controller: widget.controller),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: SynchroMotion.entrance,
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const _NavyBackdrop(),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(SynchroSpacing.xxl),
              child: AnimatedBuilder(
                animation: _sweep,
                builder: (_, _) => FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _sweep,
                    curve: Curves.easeOut,
                  ),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.94, end: 1).animate(
                      CurvedAnimation(
                        parent: _sweep,
                        curve: SynchroMotion.entrance,
                      ),
                    ),
                    child: const SynchroWordmark(size: 104, onDark: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _NavyBackdrop extends StatelessWidget {
  const _NavyBackdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [SynchroColors.navyDeep, SynchroColors.navy],
      ),
    ),
    child: SizedBox.expand(),
  );
}
