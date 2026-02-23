import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:titancast/discovery/discovery_model.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/tv_brand.dart';

/// Philips Ambilight API style constants (from /ambilight/supportedstyles).
/// These must be sent verbatim — display labels are separate.
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

/// Bottom sheet for brand-specific TV features.
/// Philips: 3 tabs — Apps, Ambilight, Keyboard
/// Others:  1 tab  — Apps + keyboard button
class BrandMenuSheet extends StatefulWidget {
  final DiscoveredDevice device;
  final bool ambilightOn;
  final String ambilightMode;       // FOLLOW_VIDEO, FOLLOW_AUDIO, etc.
  final String? ambilightSub;       // menuSetting or algorithm (sub-mode)
  final List<Map<String, dynamic>> philipsApps;
  final bool philipsAppsLoaded;
  final void Function(RemoteCommand) onSendCommand;
  final Future<void> Function()? onAmbilightToggle;
  // onAmbilightModeChanged receives (styleName, {menuSetting?, algorithm?})
  final Future<void> Function(String styleName, {String? menuSetting, String? algorithm})? onAmbilightModeChanged;
  final Future<void> Function(Map<String, dynamic> app)? onLaunchPhilipsApp;
  final Future<void> Function() onOpenKeyboard;

  const BrandMenuSheet({
    super.key,
    required this.device,
    required this.ambilightOn,
    required this.ambilightMode,
    this.ambilightSub,
    required this.philipsApps,
    required this.philipsAppsLoaded,
    required this.onSendCommand,
    this.onAmbilightToggle,
    this.onAmbilightModeChanged,
    this.onLaunchPhilipsApp,
    required this.onOpenKeyboard,
  });

  static Future<void> show({
    required BuildContext context,
    required DiscoveredDevice device,
    required bool ambilightOn,
    required String ambilightMode,
    String? ambilightSub,
    required List<Map<String, dynamic>> philipsApps,
    required bool philipsAppsLoaded,
    required void Function(RemoteCommand) onSendCommand,
    Future<void> Function()? onAmbilightToggle,
    Future<void> Function(String styleName, {String? menuSetting, String? algorithm})? onAmbilightModeChanged,
    Future<void> Function(Map<String, dynamic> app)? onLaunchPhilipsApp,
    required Future<void> Function() onOpenKeyboard,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12121A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => BrandMenuSheet(
        device: device,
        ambilightOn: ambilightOn,
        ambilightMode: ambilightMode,
        ambilightSub: ambilightSub,
        philipsApps: philipsApps,
        philipsAppsLoaded: philipsAppsLoaded,
        onSendCommand: onSendCommand,
        onAmbilightToggle: onAmbilightToggle,
        onAmbilightModeChanged: onAmbilightModeChanged,
        onLaunchPhilipsApp: onLaunchPhilipsApp,
        onOpenKeyboard: onOpenKeyboard,
      ),
    );
  }

  @override
  State<BrandMenuSheet> createState() => _BrandMenuSheetState();
}

class _BrandMenuSheetState extends State<BrandMenuSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool   _ambilightOn;
  late String _ambilightMode;
  String? _ambilightSub;

  bool get _isPhilips => widget.device.detectedBrand == TvBrand.philips;

  @override
  void initState() {
    super.initState();
    _ambilightOn   = widget.ambilightOn;
    _ambilightMode = widget.ambilightMode;
    _ambilightSub  = widget.ambilightSub;
    _tabController = TabController(length: _isPhilips ? 3 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: _isPhilips ? 0.75 : 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            _Handle(),
            const SizedBox(height: 16),
            _SheetHeader(device: widget.device),
            if (_isPhilips) ...[
              const SizedBox(height: 8),
              _PhilipsTabBar(controller: _tabController),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _isPhilips
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _AppsTab(
                          scrollController: scrollController,
                          philipsApps: widget.philipsApps,
                          philipsAppsLoaded: widget.philipsAppsLoaded,
                          onCommonApp: (cmd) {
                            Navigator.pop(context);
                            widget.onSendCommand(cmd);
                          },
                          onLaunchPhilipsApp: widget.onLaunchPhilipsApp,
                        ),
                        _AmbilightTab(
                          scrollController: scrollController,
                          ambilightOn:   _ambilightOn,
                          ambilightMode: _ambilightMode,
                          ambilightSub:  _ambilightSub,
                          onToggle: () async {
                            final newVal = !_ambilightOn;
                            setState(() => _ambilightOn = newVal);
                            await widget.onAmbilightToggle?.call();
                          },
                          onModeChanged: (style, {menuSetting, algorithm}) async {
                            setState(() {
                              _ambilightOn   = true;
                              _ambilightMode = style;
                              _ambilightSub  = menuSetting ?? algorithm;
                            });
                            await widget.onAmbilightModeChanged?.call(
                              style,
                              menuSetting: menuSetting,
                              algorithm: algorithm,
                            );
                          },
                        ),
                        _KeyboardTab(
                          scrollController: scrollController,
                          onOpen: () {
                            Navigator.pop(context);
                            widget.onOpenKeyboard();
                          },
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      controller: scrollController,
                      child: _AppsTab(
                        scrollController: scrollController,
                        philipsApps: const [],
                        philipsAppsLoaded: true,
                        onCommonApp: (cmd) {
                          Navigator.pop(context);
                          widget.onSendCommand(cmd);
                        },
                        onLaunchPhilipsApp: null,
                        showKeyboardButton: true,
                        onKeyboard: () {
                          Navigator.pop(context);
                          widget.onOpenKeyboard();
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ambilight Tab — full Philips Smart TV experience
// ─────────────────────────────────────────────────────────────────────────────

class _AmbilightTab extends StatelessWidget {
  final ScrollController scrollController;
  final bool ambilightOn;
  final String ambilightMode;
  final String? ambilightSub;
  final Future<void> Function() onToggle;
  final Future<void> Function(String styleName, {String? menuSetting, String? algorithm}) onModeChanged;

  const _AmbilightTab({
    required this.scrollController,
    required this.ambilightOn,
    required this.ambilightMode,
    required this.ambilightSub,
    required this.onToggle,
    required this.onModeChanged,
  });

  // Top-level styles (shown as large cards, matching Philips app layout)
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
      label:       'Lounge Light',
      description: 'Fixed color ambiance',
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
    final activeStyle = ambilightMode;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        // ── Power Toggle ────────────────────────────────────────────────────
        _PowerRow(
          on: ambilightOn,
          mode: ambilightMode,
          sub: ambilightSub,
          onToggle: onToggle,
        ),
        const SizedBox(height: 20),

        // ── Style Cards ─────────────────────────────────────────────────────
        _SectionLabel('Style'),
        const SizedBox(height: 12),
        ...List.generate(_topStyles.length, (i) {
          final def       = _topStyles[i];
          final isActive  = ambilightOn && activeStyle == def.styleName;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AmbiStyleCard(
              def:      def,
              isActive: isActive,
              onTap:    () => onModeChanged(def.styleName),
              // Sub-options are shown inline when card is active
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
        options: AmbiStyle.videoMenuSettings,
        selected: ambilightSub ?? 'STANDARD',
        labelOf: AmbiStyle.videoLabel,
        onSelect: (s) => onModeChanged(styleName, menuSetting: s),
      );
    }
    if (styleName == AmbiStyle.followAudio) {
      return _SubOptionRow(
        options: AmbiStyle.audioAlgorithms,
        selected: ambilightSub ?? AmbiStyle.audioAlgorithms.first,
        labelOf: AmbiStyle.audioLabel,
        onSelect: (s) => onModeChanged(styleName, algorithm: s),
      );
    }
    return null;
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
      AmbiStyle.followColor => 'Lounge Light',
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
      onTap: () {
        HapticFeedback.lightImpact();
        onToggle();
      },
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
                    child: Text(_statusText(),
                        key: ValueKey(_statusText()),
                        style: TextStyle(
                          color: on ? const Color(0xFF8B5CF6) : const Color(0xFF8A8A93),
                          fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            Switch(
              value: on,
              activeColor: const Color(0xFF8B5CF6),
              onChanged: (_) {
                HapticFeedback.lightImpact();
                onToggle();
              },
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
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive
              ? def.color.withValues(alpha: 0.10)
              : const Color(0xFF1E1E26),
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
            // Sub-options expand below when active
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

/// Horizontal scrollable sub-option chips (menuSetting / algorithm)
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
          final opt  = options[i];
          final isSel = opt == selected;
          return GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); onSelect(opt); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
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
// Apps Tab
// ─────────────────────────────────────────────────────────────────────────────

class _AppsTab extends StatelessWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> philipsApps;
  final bool philipsAppsLoaded;
  final void Function(RemoteCommand) onCommonApp;
  final Future<void> Function(Map<String, dynamic>)? onLaunchPhilipsApp;
  final bool showKeyboardButton;
  final VoidCallback? onKeyboard;

  const _AppsTab({
    required this.scrollController,
    required this.philipsApps,
    required this.philipsAppsLoaded,
    required this.onCommonApp,
    required this.onLaunchPhilipsApp,
    this.showKeyboardButton = false,
    this.onKeyboard,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        _SectionLabel('Streaming'),
        const SizedBox(height: 12),
        Row(children: [
          _AppChip(label: 'Netflix', color: const Color(0xFFE50914),
              icon: Icons.play_circle_fill_rounded,
              onTap: () => onCommonApp(RemoteCommand.netflix)),
          const SizedBox(width: 12),
          _AppChip(label: 'YouTube', color: const Color(0xFFFF0000),
              icon: Icons.smart_display_rounded,
              onTap: () => onCommonApp(RemoteCommand.youtube)),
        ]),

        if (showKeyboardButton) ...[
          const SizedBox(height: 20),
          _SectionLabel('Tools'),
          const SizedBox(height: 12),
          _AppChip(label: 'Keyboard', color: const Color(0xFF22222A),
              icon: Icons.keyboard_outlined,
              onTap: onKeyboard ?? () {}),
        ],

        if (onLaunchPhilipsApp != null) ...[
          const SizedBox(height: 24),
          _SectionLabel('TV Applications'),
          const SizedBox(height: 12),
          if (!philipsAppsLoaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF8B5CF6))),
                  SizedBox(width: 12),
                  Text('Loading apps...', style: TextStyle(color: Color(0xFF8A8A93))),
                ],
              )),
            )
          else if (philipsApps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('App list unavailable.\n(Requires API v6 or active connection)',
                  style: TextStyle(color: Color(0xFF8A8A93), fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: philipsApps.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 10,
                  mainAxisSpacing: 10, childAspectRatio: 1.25),
              itemBuilder: (_, i) {
                final app   = philipsApps[i];
                final label = app['label'] as String? ??
                    (app['intent']?['component']?['packageName'] as String?)
                        ?.split('.').last ?? 'App';
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onLaunchPhilipsApp!(app);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF22222A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.apps_rounded, color: Color(0xFF8B5CF6), size: 24),
                      const SizedBox(height: 6),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(label, style: const TextStyle(color: Colors.white,
                            fontSize: 10, fontWeight: FontWeight.w600),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center)),
                    ]),
                  ),
                );
              },
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Keyboard Tab
// ─────────────────────────────────────────────────────────────────────────────

class _KeyboardTab extends StatelessWidget {
  final ScrollController scrollController;
  final VoidCallback onOpen;
  const _KeyboardTab({required this.scrollController, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E26),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.keyboard_outlined, color: Color(0xFF8B5CF6), size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Send text to TV',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Open keyboard to type text that will be\nsent directly to the TV screen.',
                style: TextStyle(color: Color(0xFF8A8A93), fontSize: 13, height: 1.6),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: onOpen,
                icon: const Icon(Icons.keyboard_outlined, size: 20),
                label: const Text('Open Keyboard',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        const Text(
          'Keyboard also opens automatically when the TV\nshows a text input field.',
          style: TextStyle(color: Color(0xFF5A5A6A), fontSize: 12, height: 1.5),
          textAlign: TextAlign.center),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared micro-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 36, height: 4,
    decoration: BoxDecoration(
        color: Colors.white24, borderRadius: BorderRadius.circular(2)));
}

class _SheetHeader extends StatelessWidget {
  final DiscoveredDevice device;
  const _SheetHeader({required this.device});

  @override
  Widget build(BuildContext context) {
    final brand    = device.detectedBrand;
    final hasBrand = brand != null && brand != TvBrand.unknown;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: const Color(0xFF22222A), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.tv_rounded, color: Color(0xFF8B5CF6), size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(device.displayName, style: const TextStyle(color: Colors.white,
              fontSize: 17, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (hasBrand) Text(_brandName(brand!), style: const TextStyle(
              color: Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }

  String _brandName(TvBrand b) => switch (b) {
    TvBrand.philips   => 'Philips',
    TvBrand.samsung   => 'Samsung',
    TvBrand.lg        => 'LG',
    TvBrand.sony      => 'Sony',
    TvBrand.androidTv => 'Android TV',
    TvBrand.google    => 'Google TV',
    TvBrand.amazon    => 'Amazon Fire TV',
    TvBrand.apple     => 'Apple TV',
    TvBrand.roku      => 'Roku',
    _                 => b.name,
  };
}

class _PhilipsTabBar extends StatelessWidget {
  final TabController controller;
  const _PhilipsTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
            color: const Color(0xFF1E1E26),
            borderRadius: BorderRadius.circular(21)),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(21)),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF8A8A93),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.3),
          tabs: const [
            Tab(text: 'APPS'),
            Tab(text: 'AMBILIGHT'),
            Tab(text: 'KEYBOARD'),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Color(0xFF8A8A93), fontSize: 11,
        fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
}

class _AppChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _AppChip({required this.label, required this.color,
      required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color,
              fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
