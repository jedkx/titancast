import 'dart:async';
import 'package:flutter/material.dart';
import 'package:titancast/core/app_logger.dart';

const _tag = 'KeyboardInputSheet';

/// Bottom sheet for sending text to TV character-by-character.
///
/// No Send button — characters are sent as the user types (120 ms debounce).
/// [onSend] receives incremental new characters (delta only, not full string).
///
/// Mic button is on the main remote screen, not here.
class KeyboardInputSheet extends StatefulWidget {
  /// Called with incremental new characters to send to the TV.
  final Future<void> Function(String chars) onSend;

  const KeyboardInputSheet({
    super.key,
    required this.onSend,
  });

  @override
  State<KeyboardInputSheet> createState() => _KeyboardInputSheetState();
}

class _KeyboardInputSheetState extends State<KeyboardInputSheet>
{
  final _controller = TextEditingController();
  final _focusNode  = FocusNode();

  // Tracks how many chars have already been sent, to compute deltas.
  int _sentLength = 0;

  // Debounce timer — waits 120 ms after last keystroke before sending.
  Timer? _debounce;

  // Whether a send is currently in flight.
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  // ---------------------------------------------------------------------------
  // Text input — key-by-key send
  // ---------------------------------------------------------------------------

  void _onTextChanged() {
    final current = _controller.text;
    if (current.length <= _sentLength) {
      // Backspace — reset sent cursor so next typing sends from scratch.
      // We don't send delete/backspace over the air (not supported by all TVs).
      _sentLength = current.length;
      return;
    }

    // New characters appended — debounce then send delta.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () async {
      final text   = _controller.text;
      final delta  = text.substring(_sentLength);
      if (delta.isEmpty || _sending) return;

      _sentLength = text.length;

      if (mounted) setState(() => _sending = true);

      try {
        await widget.onSend(delta);
      } catch (e) {
        AppLogger.e(_tag, 'send delta failed: $e');
      } finally {
        if (mounted) setState(() => _sending = false);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Voice input
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
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
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              const Icon(Icons.keyboard_outlined,
                  color: Color(0xFF8B5CF6), size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TV Keyboard',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    Text('Characters sent as you type',
                        style: TextStyle(
                            color: Color(0xFF8A8A93), fontSize: 12)),
                  ],
                ),
              ),
              // Live send indicator
              AnimatedOpacity(
                opacity: _sending ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: const Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 6),
                    const Text('Sending',
                        style: TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Text field
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            maxLines: 3,
            minLines: 1,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => Navigator.pop(context),
            decoration: InputDecoration(
              hintText: 'Type here — sent as you type',
              hintStyle: const TextStyle(
                  color: Color(0xFF8A8A93), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFF22222A),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFF8B5CF6), width: 1.5)),
              // Suffix: clear button
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: Color(0xFF8A8A93), size: 18),
                      onPressed: () {
                        _controller.clear();
                        _sentLength = 0;
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),


        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
