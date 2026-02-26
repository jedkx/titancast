import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class AmbiStyle {
  static const followVideo = 'FOLLOW_VIDEO';
  static const followAudio = 'FOLLOW_AUDIO';
  static const followColor = 'FOLLOW_COLOR';
  static const lounge      = 'LOUNGE';
  static const off         = 'OFF';

  /// menuSetting values for FOLLOW_VIDEO
  static const videoMenuSettings = [
    'STANDARD', 'NATURAL', 'VIVID', 'GAME', 'COMFORT', 'RELAX',
  ];

  /// algorithm values for FOLLOW_AUDIO
  static const audioAlgorithms = [
    'ENERGY_ADAPTIVE_BRIGHTNESS',
    'ENERGY_ADAPTIVE_COLORS',
    'VU_METER',
    'SPECTRUM_ANALYZER',
    'KNIGHT_RIDER_CLOCKWISE',
    'KNIGHT_RIDER_ALTERNATING',
    'RANDOM_PIXEL_FLASH',
    'STROBO',
    'PARTY',
  ];

  static String videoLabel(String s) => switch (s) {
    'STANDARD' => 'Standard',
    'NATURAL'  => 'Natural',
    'VIVID'    => 'Vivid',
    'GAME'     => 'Game',
    'COMFORT'  => 'Comfort',
    'RELAX'    => 'Relax',
    _          => s,
  };

  static String audioLabel(String s) => switch (s) {
    'ENERGY_ADAPTIVE_BRIGHTNESS'  => 'Adaptive Brightness',
    'ENERGY_ADAPTIVE_COLORS'      => 'Adaptive Colors',
    'VU_METER'                    => 'VU Meter',
    'SPECTRUM_ANALYZER'           => 'Spectrum',
    'KNIGHT_RIDER_CLOCKWISE'      => 'Knight Rider',
    'KNIGHT_RIDER_ALTERNATING'    => 'K.R. Alternating',
    'RANDOM_PIXEL_FLASH'          => 'Random Flash',
    'STROBO'                      => 'Strobo',
    'PARTY'                       => 'Party',
    _                             => s,
  };
}

/// Preset colors for Ambilight fixed-color mode.
const _ambilightPresets = [
  _ColorPreset('Red',       Color(0xFFEF4444), 239,  68,  68),
  _ColorPreset('Orange',    Color(0xFFF97316), 249, 115,  22),
  _ColorPreset('Yellow',    Color(0xFFF59E0B), 245, 158,  11),
  _ColorPreset('Green',     Color(0xFF10B981),  16, 185, 129),
  _ColorPreset('Cyan',      Color(0xFF06B6D4),   6, 182, 212),
  _ColorPreset('Blue',      Color(0xFF3B82F6),  59, 130, 246),
  _ColorPreset('Violet',    Color(0xFF8B5CF6), 139,  92, 246),
  _ColorPreset('Pink',      Color(0xFFEC4899), 236,  72, 153),
  _ColorPreset('Warm White',Color(0xFFFFF3E0), 255, 243, 224),
  _ColorPreset('White',     Color(0xFFFFFFFF), 255, 255, 255),
];

class _ColorPreset {
  final String name;
  final Color color;
  final int r, g, b;
  const _ColorPreset(this.name, this.color, this.r, this.g, this.b);
}

/// Bottom sheet for brand-specific TV features.
/// Philips: 3 tabs — Apps, Ambilight, Keyboard
/// Others:  1 tab  — Apps + keyboard + color keys

// ignore: library_private_types_in_public_api
class AmbilightTab extends StatelessWidget {
  final ScrollController scrollController;
  final bool ambilightOn;
  final String ambilightMode;
  final String? ambilightSub;
  final Future<void> Function() onToggle;
  final Future<void> Function(String styleName, {String? menuSetting, String? algorithm})
  onModeChanged;
  // Callback for fixed color selection; null if not Philips / not connected
  final Future<void> Function(int r, int g, int b)? onSetColor;

  const AmbilightTab({
    required this.scrollController,
    required this.ambilightOn,
    required this.ambilightMode,
    required this.ambilightSub,
    required this.onToggle,
    required this.onModeChanged,
    this.onSetColor,
  });

  static const _topStyles = [
    _AmbiStyleDef(
      styleName:   AmbiStyle.followVideo,
      label:       'Follow Video',
      description: 'LEDs follow on-screen colors',
      icon:        Icons.tv_rounded,
      color:       Color(0xFF3B82F6),
    ),
    _AmbiStyleDef(
      styleName:   AmbiStyle.followAudio,
      label:       'Follow Audio',
      description: 'LEDs dance to music',
      icon:        Icons.music_note_rounded,
      color:       Color(0xFF10B981),
    ),
    _AmbiStyleDef(
      styleName:   AmbiStyle.followColor,
      label:       'Fixed Color',
      description: 'Set a fixed ambient color',
      icon:        Icons.palette_rounded,
      color:       Color(0xFFF59E0B),
    ),
    _AmbiStyleDef(
      styleName:   AmbiStyle.lounge,
      label:       'Lounge Mode',
      description: 'Slow relaxing color flow',
      icon:        Icons.nights_stay_rounded,
      color:       Color(0xFF8B5CF6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        // Power toggle
        _PowerRow(
          on: ambilightOn,
          mode: ambilightMode,
          sub: ambilightSub,
          onToggle: onToggle,
        ),
        const SizedBox(height: 20),

        // Style cards
        _SectionLabel('Style'),
        const SizedBox(height: 12),
        ...List.generate(_topStyles.length, (i) {
          final def      = _topStyles[i];
          final isActive = ambilightOn && ambilightMode == def.styleName;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AmbiStyleCard(
              def:      def,
              isActive: isActive,
              onTap:    () => onModeChanged(def.styleName),
              subWidget: isActive ? _buildSubOptions(def.styleName) : null,
            ),
          );
        }),
      ],
    );
  }

  Widget? _buildSubOptions(String styleName) {
    if (styleName == AmbiStyle.followVideo) {
      return _SubOptionRow(
        options:  AmbiStyle.videoMenuSettings,
        selected: ambilightSub ?? 'STANDARD',
        labelOf:  AmbiStyle.videoLabel,
        onSelect: (s) => onModeChanged(styleName, menuSetting: s),
      );
    }
    if (styleName == AmbiStyle.followAudio) {
      return _SubOptionRow(
        options:  AmbiStyle.audioAlgorithms,
        selected: ambilightSub ?? AmbiStyle.audioAlgorithms.first,
        labelOf:  AmbiStyle.audioLabel,
        onSelect: (s) => onModeChanged(styleName, algorithm: s),
      );
    }
    if (styleName == AmbiStyle.followColor) {
      // Show color picker even if onSetColor is null (to indicate the feature).
      // When onSetColor is provided, tapping a color sends it to the TV.
      return _ColorPickerRow(onSelect: onSetColor);
    }
    return null;
  }
}

/// Horizontal color preset picker for FOLLOW_COLOR mode.
class _ColorPickerRow extends StatelessWidget {
  /// Null when not connected to a Philips TV — presets are shown but disabled.
  final Future<void> Function(int r, int g, int b)? onSelect;
  const _ColorPickerRow({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _ambilightPresets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = _ambilightPresets[i];
          return GestureDetector(
            onTap: onSelect != null ? () => onSelect!(p.r, p.g, p.b) : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: p.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                boxShadow: [
                  BoxShadow(color: p.color.withValues(alpha: 0.5), blurRadius: 8),
                ],
              ),
              child: Tooltip(
                message: p.name,
                child: const SizedBox.expand(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AmbiStyleDef {
  final String styleName;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  const _AmbiStyleDef({
    required this.styleName,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _PowerRow extends StatelessWidget {
  final bool on;
  final String mode;
  final String? sub;
  final Future<void> Function() onToggle;
  const _PowerRow({required this.on, required this.mode, required this.sub, required this.onToggle});

  String _statusText() {
    if (!on) return 'Off';
    final base = switch (mode) {
      AmbiStyle.followVideo => 'Follow Video',
      AmbiStyle.followAudio => 'Follow Audio',
      AmbiStyle.followColor => 'Fixed Color',
      AmbiStyle.lounge      => 'Lounge Mode',
      _                     => mode,
    };
    final subLabel = sub != null
        ? ' · ${AmbiStyle.videoLabel(sub!) != sub ? AmbiStyle.videoLabel(sub!) : AmbiStyle.audioLabel(sub!)}'
        : '';
    return '$base$subLabel';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: on
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
              : const Color(0xFF1E1E26),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: on
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: on
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
                    : const Color(0xFF22222A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.light_mode_rounded,
                color: on ? const Color(0xFF8B5CF6) : const Color(0xFF8A8A93),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ambilight',
                      style: TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _statusText(),
                      key: ValueKey(_statusText()),
                      style: TextStyle(
                        color: on ? const Color(0xFF8B5CF6) : const Color(0xFF8A8A93),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: on,
              activeColor: const Color(0xFF8B5CF6),
              onChanged: (_) => onToggle(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbiStyleCard extends StatelessWidget {
  final _AmbiStyleDef def;
  final bool isActive;
  final VoidCallback onTap;
  final Widget? subWidget;

  const _AmbiStyleCard({
    required this.def,
    required this.isActive,
    required this.onTap,
    this.subWidget,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive ? def.color.withValues(alpha: 0.10) : const Color(0xFF1E1E26),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? def.color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: isActive
                          ? def.color.withValues(alpha: 0.2)
                          : def.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(def.icon, color: def.color, size: 21),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(def.label,
                            style: TextStyle(
                                color: isActive ? def.color : Colors.white,
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(def.description,
                            style: const TextStyle(
                                color: Color(0xFF8A8A93), fontSize: 12)),
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                          color: def.color, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14),
                    ),
                ],
              ),
            ),
            if (subWidget != null) ...[
              Divider(height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                  indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: subWidget!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrollable sub-option chips (menuSetting or algorithm sub-modes)
class _SubOptionRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final String Function(String) labelOf;
  final void Function(String) onSelect;

  const _SubOptionRow({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final opt   = options[i];
          final isSel = opt == selected;
          return GestureDetector(
            onTap: () => onSelect(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSel
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
                    : const Color(0xFF22222A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSel
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Center(
                child: Text(labelOf(opt),
                    style: TextStyle(
                        color: isSel ? const Color(0xFF8B5CF6) : const Color(0xFF8A8A93),
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF8A8A93),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Apps Tab
// ─────────────────────────────────────────────────────────────────────────────