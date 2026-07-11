import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import '../../theme/dashly_theme.dart';
import '../tracking/race_interlock_screen.dart';

/// ════════════════════════════════════════════════════════════════
/// RedeemScreen — Join Event via Manual Token
/// ════════════════════════════════════════════════════════════════
/// Default view: manual 6-digit code entry.
/// ════════════════════════════════════════════════════════════════
class RedeemScreen extends StatefulWidget {
  const RedeemScreen({super.key});

  @override
  State<RedeemScreen> createState() => _RedeemScreenState();
}

class _RedeemScreenState extends State<RedeemScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isProcessing = false;
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // ── Submit token to backend ───────────────────────────────────
  Future<void> _submitToken(String token) async {
    final trimmed = token.trim().toUpperCase();
    if (trimmed.isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);
    debugPrint('[RedeemScreen] Submitting token: $trimmed');

    final provider = context.read<EventProvider>();
    final result = await provider.joinEventViaToken(trimmed);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result != null && result['success'] == true) {
      debugPrint('[RedeemScreen] ✅ Join success');
      _showSnack(result['message'] ?? 'Successfully joined!', false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RaceInterlockScreen(
            eventId: result['eventId'],
            eventName: result['eventName'] ?? 'Event',
            category: result['category'] == 'CYCLING' ? 'CYCLING' : 'RUNNING',
          ),
        ),
      );
    } else {
      debugPrint('[RedeemScreen] ❌ Failed: ${provider.errorMessage}');
      _showSnack(provider.errorMessage ?? 'Failed to join event', true);
    }
  }

  void _showSnack(String msg, bool isError) {
    final c = context.dashlyColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: isError ? Colors.white : Colors.black, size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, style: TextStyle(
            color: isError ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ))),
        ]),
        backgroundColor: isError ? c.error : c.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colors = context.dashlyColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.textHint, size: 20),
        ),
        title: Column(children: [
          Text('JOIN EVENT', style: TextStyle(
            color: colors.accent, fontWeight: FontWeight.w900,
            fontSize: 10, letterSpacing: 2.5,
          )),
          Text('Enter Access Code', style: TextStyle(
            color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16,
          )),
        ]),
        centerTitle: true,
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Icon ────────────────────────────────────────
                Center(
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accent.withValues(alpha: 0.1),
                    ),
                    child: Icon(Icons.qr_code_2_rounded,
                        size: 40, color: colors.accent),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Code Input ──────────────────────────────────
                Text('Enter Access Code', style: TextStyle(
                  color: colors.textPrimary, fontWeight: FontWeight.w800,
                  fontSize: 18,
                ), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Ask the event organizer for the 6-character code',
                  style: TextStyle(color: colors.textHint, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // ── TextField ───────────────────────────────────
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    _UpperCaseFormatter(),
                  ],
                  style: TextStyle(
                    color: colors.textPrimary, fontWeight: FontWeight.w900,
                    fontSize: 28, letterSpacing: 12,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '● ● ● ● ● ●',
                    hintStyle: TextStyle(
                      color: colors.textHint.withValues(alpha: 0.3),
                      fontSize: 24, letterSpacing: 12,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: colors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.accent, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 22,
                    ),
                  ),
                  onSubmitted: (_) => _submitToken(_codeController.text),
                ),
                const SizedBox(height: 20),

                // ── Submit Button ───────────────────────────────
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            _submitToken(_codeController.text);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: colors.surfaceLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isProcessing
                        ? SizedBox(width: 24, height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: colors.textHint,
                            ))
                        : const Text('JOIN EVENT',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15, letterSpacing: 1.5,
                            )),
                  ),
                ),
                const SizedBox(height: 28),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
