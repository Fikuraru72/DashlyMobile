import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/dashly_api_service.dart';

/// A standalone screen that lets you verify connectivity to the NestJS backend.
/// Drop it into your Navigator as an initial route while developing.
class SyncCheckScreen extends StatefulWidget {
  const SyncCheckScreen({super.key});

  @override
  State<SyncCheckScreen> createState() => _SyncCheckScreenState();
}

class _SyncCheckScreenState extends State<SyncCheckScreen> {
  final DashlyApiService _api = DashlyApiService();

  bool _loading = false;
  SyncResponse? _result;
  String? _error;
  int? _latencyMs;

  Future<void> _ping() async {
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
      _latencyMs = null;
    });

    final sw = Stopwatch()..start();
    try {
      final data = await _api.checkSync();
      sw.stop();
      setState(() {
        _result = data;
        _latencyMs = sw.elapsedMilliseconds;
        _loading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Connected — ${data.userCount} users · ${data.eventCount} events · ${sw.elapsedMilliseconds}ms',
          ),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } on DioException catch (e) {
      sw.stop();
      final msg = e.response?.data?.toString() ??
          e.message ??
          'Network error';
      setState(() {
        _error = msg;
        _latencyMs = sw.elapsedMilliseconds;
        _loading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $msg'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      sw.stop();
      setState(() {
        _error = e.toString();
        _latencyMs = sw.elapsedMilliseconds;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Color(0xFF1E293B),
        title: Text(
          'System Sync Check',
          style: TextStyle(
            color: Color(0xFFF1F5F9),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFF1F5F9)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header card ──────────────────────────────────────────────
              _GlassCard(
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.electric_bolt_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Backend Connectivity Test',
                      style: TextStyle(
                        color: Color(0xFFF1F5F9),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verifies DB · Network · Server are all reachable',
                      style:
                          TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Status / result card ──────────────────────────────────────
              _GlassCard(
                borderColor: _loading
                    ? Color(0xFF3B82F6)
                    : _result != null
                        ? Color(0xFF10B981)
                        : _error != null
                            ? Color(0xFFEF4444)
                            : Color(0xFF334155),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF60A5FA),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Pinging backend…',
                                style: TextStyle(
                                    color: Color(0xFF93C5FD), fontSize: 13)),
                          ],
                        ),
                      )
                    : _result != null
                        ? _ResultsList(result: _result!, latencyMs: _latencyMs)
                        : _error != null
                            ? _ErrorWidget(message: _error!)
                            : Text(
                                'Press the button below to run the sync test.',
                                style: TextStyle(
                                    color: Color(0xFF64748B), fontSize: 13),
                              ),
              ),

              const SizedBox(height: 20),

              // ── Ping button ───────────────────────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _ping,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6366F1),
                    disabledBackgroundColor: Color(0xFF6366F1).withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(Icons.wifi_tethering_rounded, size: 20),
                  label: Text(
                    _loading ? 'Testing…' : 'Test Backend Connection',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              // ── Latency badge ─────────────────────────────────────────────
              if (_latencyMs != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Last ping: ${_latencyMs}ms',
                  style: TextStyle(
                      color: Color(0xFF64748B), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper widgets ──────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _GlassCard({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? Color(0xFF334155),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

class _ResultsList extends StatelessWidget {
  final SyncResponse result;
  final int? latencyMs;

  const _ResultsList({required this.result, this.latencyMs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Row(icon: '🗄️', label: 'DB Connected',
            value: result.dbConnected ? 'Yes ✓' : 'No ✗',
            valueColor: result.dbConnected
                ? Color(0xFF34D399)
                : Color(0xFFF87171)),
        const SizedBox(height: 8),
        _Row(icon: '👤', label: 'Users in DB',
            value: '${result.userCount}'),
        const SizedBox(height: 8),
        _Row(icon: '📅', label: 'Events in DB',
            value: '${result.eventCount}'),
        const SizedBox(height: 8),
        _Row(icon: '🟢', label: 'Status',
            value: result.status,
            valueColor: result.status == 'OK'
                ? Color(0xFF34D399)
                : Color(0xFFF87171)),
        const SizedBox(height: 8),
        _Row(icon: '🕐', label: 'Server Time',
            value: result.serverTime.substring(0, 19).replaceFirst('T', ' ')),
        if (latencyMs != null) ...[
          const SizedBox(height: 8),
          _Row(icon: '⚡', label: 'Round-trip', value: '${latencyMs}ms'),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _Row(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: Color(0xFF94A3B8), fontSize: 13)),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Color(0xFFE2E8F0),
            fontWeight: FontWeight.w600,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;

  const _ErrorWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('✗',
            style: TextStyle(
                color: Color(0xFFF87171),
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
                color: Color(0xFFFCA5A5), fontSize: 12),
          ),
        ),
      ],
    );
  }
}
