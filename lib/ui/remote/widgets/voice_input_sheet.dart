import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:titancast/core/app_logger.dart';

const _tag = 'VoiceInputSheet';

/// Bottom sheet that listens to microphone input and returns recognized text
/// to the caller via [onSend]. Used to send voice-dictated text to the TV.
///
/// Uses the [speech_to_text] package. Microphone permission must be granted
/// by the OS — the package handles the permission request internally.
class VoiceInputSheet extends StatefulWidget {
  /// Called with the final recognized text when the user taps Send.
  /// Accepts async callbacks so callers can await the TV send operation.
  final Future<void> Function(String text) onSend;

  const VoiceInputSheet({super.key, required this.onSend});

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String) onSend,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15151A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => VoiceInputSheet(onSend: onSend),
    );
  }

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends State<VoiceInputSheet>
    with SingleTickerProviderStateMixin {
  final _speech = SpeechToText();

  bool _initializing = true;
  bool _available    = false;
  bool _listening    = false;
  String _finalText  = '';
  String _partial    = '';

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    // Defer _init so that any log calls inside do not fire ValueNotifier
    // notifications while the widget tree is still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _init() async {
    AppLogger.d(_tag, 'initializing speech_to_text');
    final ok = await _speech.initialize(
      onError: (e) {
        AppLogger.e(_tag, 'speech error: ${e.errorMsg} permanent=${e.permanent}');
        if (mounted) setState(() => _listening = false);
      },
      onStatus: (s) {
        AppLogger.d(_tag, 'speech status: $s');
        if (mounted && s == 'done') setState(() => _listening = false);
      },
    );
    AppLogger.i(_tag, 'speech_to_text available=$ok');
    if (!mounted) return;
    setState(() {
      _available    = ok;
      _initializing = false;
    });
    if (ok) _startListening();
  }

  Future<void> _startListening() async {
    if (!_available || _listening) return;
    setState(() {
      _listening   = true;
      _finalText   = '';
      _partial     = '';
    });
    _pulseCtrl.repeat(reverse: true);

    await _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() {
          if (r.finalResult) {
            _finalText = r.recognizedWords;
            _partial   = '';
            _listening = false;
            _pulseCtrl.stop();
          } else {
            _partial = r.recognizedWords;
          }
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: false,
      partialResults: true,
    );
  }

  void _stopListening() {
    _speech.stop();
    _pulseCtrl.stop();
    setState(() => _listening = false);
  }

  Future<void> _send() async {
    final text = _finalText.isNotEmpty ? _finalText : _partial;
    if (text.trim().isEmpty) return;
    AppLogger.i(_tag, 'sending recognized text: "$text"');
    await widget.onSend(text.trim());
    if (mounted) Navigator.pop(context);
  }

  String get _displayText {
    if (_finalText.isNotEmpty) return _finalText;
    if (_partial.isNotEmpty)   return _partial;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Voice Search',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 28),

              // Mic button with pulse
              if (_initializing)
                const SizedBox(
                  width: 80, height: 80,
                  child: CircularProgressIndicator(
                      color: Color(0xFF8B5CF6), strokeWidth: 3),
                )
              else if (!_available)
                _UnavailableState()
              else
                GestureDetector(
                  onTap: _listening ? _stopListening : _startListening,
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) => Transform.scale(
                      scale: _listening ? _pulseAnim.value : 1.0,
                      child: child,
                    ),
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _listening
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFF22222A),
                        boxShadow: _listening
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ]
                            : [],
                        border: Border.all(
                          color: _listening
                              ? const Color(0xFF8B5CF6)
                              : Colors.white.withValues(alpha: 0.1),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _listening ? Colors.white : const Color(0xFF8A8A93),
                        size: 36,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),

              // Status label
              if (!_initializing && _available)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _listening ? 'Listening…' : 'Tap mic to speak',
                    key: ValueKey(_listening),
                    style: TextStyle(
                      color: _listening
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF8A8A93),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Recognized text box
              if (_available) ...[
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 64),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22222A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _displayText.isNotEmpty
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: _displayText.isEmpty
                      ? const Text(
                          'Recognized text will appear here…',
                          style: TextStyle(color: Color(0xFF5A5A6A), fontSize: 14),
                        )
                      : Text(
                          _displayText,
                          style: TextStyle(
                            color: _finalText.isNotEmpty
                                ? Colors.white
                                : const Color(0xFF8A8A93),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
                const SizedBox(height: 20),

                // Send button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _displayText.isNotEmpty
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF22222A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _displayText.isNotEmpty ? _send : null,
                    icon: const Icon(Icons.send_rounded, size: 20),
                    label: const Text('Send to TV',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailableState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          ),
          child: const Icon(Icons.mic_off_rounded,
              color: Color(0xFFEF4444), size: 36),
        ),
        const SizedBox(height: 16),
        const Text(
          'Microphone not available',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Check microphone permission in device settings\nor use the keyboard to type text instead.',
            style: TextStyle(
                color: Color(0xFF8A8A93), fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
