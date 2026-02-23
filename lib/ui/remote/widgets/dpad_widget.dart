import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/ui/remote/widgets/remote_button.dart';

class DPadWidget extends StatelessWidget {
  final void Function(RemoteCommand) onCommand;

  const DPadWidget({super.key, required this.onCommand});

  @override
  Widget build(BuildContext context) {
    const Color ringColor = Color(0xFF1E1E26);
    const Color purpleAccent = Color(0xFF8B5CF6);
    const Color iconColor = Color(0xFFD4D4D8);

    return Column(
      children: [
        // D-PAD HALKASI
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ringColor,
            border: Border.all(color: Colors.white.withValues(alpha: 0.04), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(top: 8, child: _DirBtn(icon: Icons.keyboard_arrow_up_rounded, onTap: () => onCommand(RemoteCommand.up))),
              Positioned(bottom: 8, child: _DirBtn(icon: Icons.keyboard_arrow_down_rounded, onTap: () => onCommand(RemoteCommand.down))),
              Positioned(left: 8, child: _DirBtn(icon: Icons.keyboard_arrow_left_rounded, onTap: () => onCommand(RemoteCommand.left))),
              Positioned(right: 8, child: _DirBtn(icon: Icons.keyboard_arrow_right_rounded, onTap: () => onCommand(RemoteCommand.right))),

              // ORTA OK TUŞU (GLOW EFEKTLİ)
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: purpleAccent.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 4,
                    )
                  ],
                ),
                child: RemoteButton.circle(
                  size: 76,
                  color: purpleAccent,
                  onTap: () { HapticFeedback.mediumImpact(); onCommand(RemoteCommand.ok); },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // GERİ VE HOME TUŞLARI
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RemoteButton(
              width: 80, height: 52,
              color: const Color(0xFF22222A),
              borderRadius: BorderRadius.circular(26),
              onTap: () => onCommand(RemoteCommand.back),
              child: const Icon(Icons.arrow_back_rounded, color: iconColor, size: 22),
            ),
            RemoteButton(
              width: 80, height: 52,
              color: const Color(0xFF22222A),
              borderRadius: BorderRadius.circular(26),
              onTap: () => onCommand(RemoteCommand.home),
              child: const Icon(Icons.home_outlined, color: iconColor, size: 24),
            ),
          ],
        ),
      ],
    );
  }
}

class _DirBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _DirBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return RemoteButton.circle(
      size: 64,
      color: Colors.transparent,
      isFlat: true,
      border: Border.all(color: Colors.transparent),
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Icon(icon, size: 36, color: const Color(0xFF8A8A93)),
    );
  }
}