import 'package:flutter/material.dart';

import '../brand/synchro_mark.dart';
import '../state/scheduling_controller.dart';
import '../theme/tokens.dart';
import 'app_shell.dart';

/// Boots in the open: the mark sweeps while the app asks the backend whether the
/// solver is actually there. If it is not, this screen says so with the URL and the
/// command — a demo must never present a timetable it could not compute.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.controller});

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

  bool _checking = true;
  bool _failed = false;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _checking = true;
      _failed = false;
    });
    await widget.controller.connect();
    if (!mounted || _left) return;
    if (widget.controller.phase == LinkPhase.offline) {
      setState(() => _failed = true);
      return;
    }

    await widget.controller.loadDemoCampus();
    if (!mounted || _left) return;
    if (widget.controller.phase == LinkPhase.offline) {
      setState(() => _failed = true);
      return;
    }

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _NavyBackdrop(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: SynchroSpacing.xxl,
                vertical: SynchroSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _failed ? _failure(context) : _brand(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _brand(BuildContext context) => [
    const SizedBox(height: 72),
    Center(
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (_, _) => FadeTransition(
          opacity: CurvedAnimation(parent: _sweep, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(
              CurvedAnimation(parent: _sweep, curve: SynchroMotion.entrance),
            ),
            child: SynchroWordmark(
              size: 104,
              onDark: true,
              progress: Curves.easeOutCubic.transform(_sweep.value),
            ),
          ),
        ),
      ),
    ),
    const SizedBox(height: SynchroSpacing.xxl),
    Text(
      'A clearer week starts here.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(color: SynchroColors.onNavy),
    ),
    const SizedBox(height: SynchroSpacing.sm),
    Text(
      'Smart campus scheduling, checked by the solver.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: SynchroColors.onNavyMuted),
    ),
    const SizedBox(height: SynchroSpacing.xxl),
    SizedBox(
      width: 140,
      child: Column(
        children: [
          Text(
            _checking ? 'CONTACTING SOLVER' : 'LOADING CAMPUS',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: SynchroColors.onNavyMuted),
          ),
          const SizedBox(height: SynchroSpacing.md),
          const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    ),
  ];

  List<Widget> _failure(BuildContext context) {
    final message = widget.controller.linkError ?? 'The solver did not answer.';
    return [
      const SizedBox(height: 60),
      const SynchroWordmark(size: 72, onDark: true),
      const SizedBox(height: SynchroSpacing.xxl),
      const Icon(
        Icons.cloud_off_outlined,
        size: 44,
        color: SynchroColors.orange,
      ),
      const SizedBox(height: SynchroSpacing.xl),
      Text(
        'Backend unreachable',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: SynchroColors.onNavy),
      ),
      const SizedBox(height: SynchroSpacing.md),
      Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: SynchroColors.onNavyMuted),
      ),
      const SizedBox(height: SynchroSpacing.xl),
      Container(
        padding: const EdgeInsets.all(SynchroSpacing.lg),
        decoration: BoxDecoration(
          color: SynchroColors.navy,
          borderRadius: BorderRadius.circular(SynchroRadius.chip),
          border: Border.all(color: SynchroColors.navySoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            SelectableText(
              widget.controller.backendUrl,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: SynchroType.body,
              ),
            ),
            const SizedBox(height: SynchroSpacing.lg),
            Text(
              'Start the backend with',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 2),
            const SelectableText(
              'uvicorn app.main:app --host 0.0.0.0 --port 8000',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: SynchroType.label,
              ),
            ),
            const SizedBox(height: SynchroSpacing.md),
            Text(
              'On an Android emulator the host is 10.0.2.2, not localhost. '
              'Override with --dart-define=SYNCHRO_API=http://<host>:8000.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: SynchroColors.onNavyMuted),
            ),
          ],
        ),
      ),
      const SizedBox(height: SynchroSpacing.xl),
      FilledButton(onPressed: _boot, child: const Text('Retry connection')),
    ];
  }
}

/// Navy field with the cream horizon of the colloquium poster — flat colour plus a
/// hairline, not a gradient wash.
class _NavyBackdrop extends StatelessWidget {
  const _NavyBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
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
}
