import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/event_model.dart';
import '../../providers/event_list_provider.dart';
import '../../providers/event_provider.dart';
import '../../theme/dashly_theme.dart';
import 'tracking_screen.dart';
import 'stats_tracking_screen.dart';

/// ════════════════════════════════════════════════════════════════
/// Race Interlock Screen — Double-Lock Security Gate
/// ════════════════════════════════════════════════════════════════
/// Shows after token redemption. Implements the two conditions:
/// 1. TIME LOCK: currentTime >= actualStart (countdown if not met)
/// 2. ADMIN LOCK: event.status === 'START' (waiting UI if not met)
///
/// Only when BOTH conditions are met, the "Start Tracking" button
/// becomes available.
/// ════════════════════════════════════════════════════════════════
class RaceInterlockScreen extends StatefulWidget {
  final int eventId;
  final String eventName;
  final String category;

  const RaceInterlockScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    this.category = 'RUNNING',
  });

  @override
  State<RaceInterlockScreen> createState() => _RaceInterlockScreenState();
}

class _RaceInterlockScreenState extends State<RaceInterlockScreen>
    with TickerProviderStateMixin {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  final TextEditingController _bibController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    // Tick the clock every second for countdown
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    // Pulse animation for waiting indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Bounce animation for ready state
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Start polling event status & autofill BIB if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final eventProv = context.read<EventProvider>();
      eventProv.fetchEvent(widget.eventId);
      eventProv.startPolling(widget.eventId);

      final eventListProv = context.read<EventListProvider>();
      final enrichedEvent = eventListProv.getEventWithParticipantData(widget.eventId);
      if (enrichedEvent?.bibNumber != null && enrichedEvent!.bibNumber!.isNotEmpty) {
        _bibController.text = enrichedEvent.bibNumber!;
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulseController.dispose();
    _bounceController.dispose();
    _bibController.dispose();
    context.read<EventProvider>().stopPolling();
    super.dispose();
  }

  void _startTracking({required bool isMapMode}) {
    final eventProv = context.read<EventProvider>();
    eventProv.stopPolling();

    if (isMapMode) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TrackingScreen(
            eventId: widget.eventId,
            eventName: widget.eventName,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => StatsTrackingScreen(
            eventId: widget.eventId,
            eventName: widget.eventName,
          ),
        ),
      );
    }
  }

  Future<void> _showTrackingModeDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.dashlyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SELECT TRACKING MODE",
                style: TextStyle(
                  color: context.dashlyColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Choose how you want to track your race progress:",
                style: TextStyle(color: context.dashlyColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // MODE 1: MAP MODE
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _startTracking(isMapMode: true);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.dashlyColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.dashlyColors.accent),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map_rounded, color: context.dashlyColors.accent, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "TRACKING WITH MAP",
                              style: TextStyle(color: context.dashlyColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Interactive 3D navigation map with route & live position.",
                              style: TextStyle(color: context.dashlyColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: context.dashlyColors.accent, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // MODE 2: STATS ONLY (BATTERY SAVER)
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _startTracking(isMapMode: false);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.dashlyColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.dashlyColors.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: Colors.orangeAccent, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "TRACKING WITHOUT MAP (STATS ONLY)",
                              style: TextStyle(color: context.dashlyColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Battery saver mode. Displays metrics & altitude charts.",
                              style: TextStyle(color: context.dashlyColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: context.dashlyColors.textHint, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _verifyAndStartTracking() async {
    final bib = _bibController.text.trim();
    if (bib.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your BIB number'), backgroundColor: context.dashlyColors.error),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await context.read<EventListProvider>().verifyBib(widget.eventId, bib);
      
      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (result['success'] == true) {
        await _showTrackingModeDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Invalid BIB number'), backgroundColor: context.dashlyColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to verify BIB'), backgroundColor: context.dashlyColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventProv = context.watch<EventProvider>();
    final event = eventProv.currentEvent;

    // Determine lock states
    final bool isTimeLockOpen = event?.actualStart != null && _now.isAfter(event!.actualStart!);
    final bool isAdminLockOpen = event?.status == EventStatus.start;
    final bool canStart = isTimeLockOpen && isAdminLockOpen;
    final bool isFinished = event?.status == EventStatus.finished;

    // Build countdown string
    String? countdown;
    if (event?.actualStart != null && !isTimeLockOpen) {
      final diff = event!.actualStart!.difference(_now);
      if (diff.isNegative) {
        countdown = null;
      } else {
        final h = diff.inHours.toString().padLeft(2, '0');
        final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
        countdown = '$h:$m:$s';
      }
    }

    final bool isCycling = (event?.category == EventCategory.cycling) || widget.category == 'CYCLING';

    return Scaffold(
      backgroundColor: context.dashlyColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // ── Top Bar ──────────────────────────────────────────
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_rounded,
                        color: context.dashlyColors.textHint, size: 20),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RACE INTERLOCK',
                          style: TextStyle(
                            color: context.dashlyColors.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 2.5,
                          ),
                        ),
                        Text(
                          widget.eventName,
                          style: TextStyle(
                            color: context.dashlyColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCycling
                          ? Colors.blue.withOpacity(0.15)
                          : Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCycling
                            ? Colors.blue.withOpacity(0.3)
                            : Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCycling ? Icons.directions_bike_rounded : Icons.directions_run_rounded,
                          size: 14,
                          color: isCycling ? Colors.blue : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCycling ? 'CYCLING' : 'RUNNING',
                          style: TextStyle(
                            color: isCycling ? Colors.blue : Colors.green,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // ── Main Status Display ──────────────────────────────
              if (event == null)
                _buildLoadingState()
              else if (isFinished)
                _buildFinishedState()
              else if (!isTimeLockOpen)
                _buildCountdownState(countdown)
              else if (!isAdminLockOpen)
                _buildWaitingForAdmin()
              else
                _buildReadyState(),

              const SizedBox(height: 48),

              // ── Lock Status Indicators ───────────────────────────
              _buildLockIndicators(isTimeLockOpen, isAdminLockOpen, isFinished),

              const SizedBox(height: 24),

              // ── BIB Input ────────────────────────────────────────
              TextField(
                controller: _bibController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: context.dashlyColors.textPrimary),
                decoration: DashlyTheme.inputDecoration(
                  context,
                  label: 'BIB Number',
                  prefixIcon: Icons.numbers_rounded,
                ),
              ),
              const SizedBox(height: 16),

              // ── Action Button ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (canStart && !_isProcessing) ? _verifyAndStartTracking : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canStart
                        ? context.dashlyColors.accent
                        : context.dashlyColors.surface,
                    disabledBackgroundColor: context.dashlyColors.surface,
                    foregroundColor: canStart ? Colors.white : context.dashlyColors.textHint,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: canStart ? 8 : 0,
                    shadowColor: canStart ? context.dashlyColors.accent.withOpacity(0.4) : Colors.transparent,
                  ),
                  child: _isProcessing 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            canStart ? Icons.play_arrow_rounded : Icons.lock_rounded,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            canStart ? 'VERIFY & START' : 'LOCKED',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: context.dashlyColors.accent,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'LOADING EVENT...',
          style: TextStyle(
            color: context.dashlyColors.textHint,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildFinishedState() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.dashlyColors.surface,
            border: Border.all(color: Colors.grey.withOpacity(0.3), width: 3),
          ),
          child: Icon(Icons.flag_rounded, size: 48, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        Text(
          'RACE FINISHED',
          style: TextStyle(
            color: context.dashlyColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This event has already concluded.',
          style: TextStyle(
            color: context.dashlyColors.textHint,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCountdownState(String? countdown) {
    return Column(
      children: [
        // Countdown Ring
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.dashlyColors.surface,
            border: Border.all(
              color: context.dashlyColors.accent.withOpacity(0.2),
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: context.dashlyColors.accent.withOpacity(0.1),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_rounded,
                    size: 28, color: context.dashlyColors.accent.withOpacity(0.6)),
                const SizedBox(height: 8),
                Text(
                  countdown ?? '--:--:--',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: context.dashlyColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'MONITORING WINDOW OPENS IN',
          style: TextStyle(
            color: context.dashlyColors.accent,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The race hasn\'t started yet.\nPlease wait for the monitoring window to open.',
          style: TextStyle(
            color: context.dashlyColors.textHint,
            fontSize: 13,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWaitingForAdmin() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.08);
        return Column(
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.4),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.15 * _pulseController.value),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(Icons.hourglass_top_rounded,
                    size: 48, color: Colors.amber),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'WAITING FOR ORGANIZER',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The monitoring window is open, but the\norganizer/admin hasn\'t started the ​race yet.',
              style: TextStyle(
                color: context.dashlyColors.textHint,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.amber.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Polling status every    5 seconds...',
                  style: TextStyle(
                    color: context.dashlyColors.textHint.withOpacity(0.6),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildReadyState() {
    return AnimatedBuilder(
      animation: _bounceController,
      builder: (context, child) {
        final offset = _bounceController.value * 6;
        return Column(
          children: [
            Transform.translate(
              offset: Offset(0, -offset),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      context.dashlyColors.accent,
                      context.dashlyColors.accent.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.dashlyColors.accent.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  size: 56,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'READY TO RACE!',
              style: TextStyle(
                color: context.dashlyColors.accent,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Both locks are open.\nTap the button below to begin tracking.',
              style: TextStyle(
                color: context.dashlyColors.textHint,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLockIndicators(bool timeLock, bool adminLock, bool finished) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.dashlyColors.divider,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildLockItem(
              icon: Icons.schedule_rounded,
              label: 'TIME LOCK',
              isOpen: timeLock || finished,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: context.dashlyColors.divider,
          ),
          Expanded(
            child: _buildLockItem(
              icon: Icons.admin_panel_settings_rounded,
              label: 'ADMIN LOCK',
              isOpen: adminLock || finished,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockItem({
    required IconData icon,
    required String label,
    required bool isOpen,
  }) {
    return Column(
      children: [
        Icon(
          isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
          size: 24,
          color: isOpen ? Colors.green : context.dashlyColors.textHint,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isOpen ? Colors.green : context.dashlyColors.textHint,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isOpen
                ? Colors.green.withOpacity(0.15)
                : context.dashlyColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isOpen ? 'OPEN' : 'LOCKED',
            style: TextStyle(
              color: isOpen ? Colors.green : context.dashlyColors.error,
              fontWeight: FontWeight.w900,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}
