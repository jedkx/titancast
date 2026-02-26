import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:titancast/discovery/discovery_model.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/tv_brand.dart';
import 'package:titancast/ui/remote/brands/philips/ambilight_tab.dart';

/// Philips Ambilight API style constants (from /ambilight/supportedstyles).
/// Style names must be sent verbatim to the API.
// AmbiStyle is defined in brands/philips/ambilight_tab.dart

class BrandMenuSheet extends StatefulWidget {
  final DiscoveredDevice device;
  final bool ambilightOn;
  final String ambilightMode;
  final String? ambilightSub;
  final List<Map<String, dynamic>> philipsApps;
  final bool philipsAppsLoaded;
  final void Function(RemoteCommand) onSendCommand;
  final Future<void> Function()? onRetryApps;
  final Future<void> Function()? onAmbilightToggle;
  final Future<void> Function(String styleName, {String? menuSetting, String? algorithm})?
      onAmbilightModeChanged;
  // Called with (r, g, b) for fixed color mode
  final Future<void> Function(int r, int g, int b)? onAmbilightSetColor;
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
    this.onRetryApps,
    this.onAmbilightToggle,
    this.onAmbilightModeChanged,
    this.onAmbilightSetColor,
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
    Future<void> Function()? onRetryApps,
    Future<void> Function()? onAmbilightToggle,
    Future<void> Function(String styleName, {String? menuSetting, String? algorithm})?
        onAmbilightModeChanged,
    Future<void> Function(int r, int g, int b)? onAmbilightSetColor,
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
        onRetryApps: onRetryApps,
        onAmbilightToggle: onAmbilightToggle,
        onAmbilightModeChanged: onAmbilightModeChanged,
        onAmbilightSetColor: onAmbilightSetColor,
        onLaunchPhilipsApp: onLaunchPhilipsApp,
        onOpenKeyboard: onOpenKeyboard,
      ),
    );
  }

  static String brandLabel(TvBrand b) => switch (b) {
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
    _tabController = TabController(length: _isPhilips ? 2 : 1, vsync: this);
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
        initialChildSize: _isPhilips ? 0.75 : 0.60,
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
                          onRetryApps: widget.onRetryApps,
                          onSendCommand: widget.onSendCommand,
                        ),
                        AmbilightTab(
                          scrollController: scrollController,
                          ambilightOn:   _ambilightOn,
                          ambilightMode: _ambilightMode,
                          ambilightSub:  _ambilightSub,
                          onToggle: () async {
                            // Toggle local state optimistically, then call parent.
                            // Parent (_toggleAmbilight) also flips its own state;
                            // keep both in sync by reading the new value here.
                            setState(() => _ambilightOn = !_ambilightOn);
                            await widget.onAmbilightToggle?.call();
                          },
                          onModeChanged: (style, {menuSetting, algorithm}) async {
                            setState(() {
                              _ambilightOn   = true;
                              _ambilightMode = style;
                              _ambilightSub  = menuSetting ?? algorithm;
                            });
                            await widget.onAmbilightModeChanged?.call(style,
                                menuSetting: menuSetting, algorithm: algorithm);
                          },
                          onSetColor: widget.onAmbilightSetColor,
                        )
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
                        onSendCommand: widget.onSendCommand,
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
// Ambilight Tab
// ─────────────────────────────────────────────────────────────────────────────

class _AppsTab extends StatelessWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> philipsApps;
  final bool philipsAppsLoaded;
  final void Function(RemoteCommand) onCommonApp;
  final Future<void> Function(Map<String, dynamic>)? onLaunchPhilipsApp;
  final Future<void> Function()? onRetryApps;
  final bool showKeyboardButton;
  final VoidCallback? onKeyboard;
  // Used to send color keys and info from the menu
  final void Function(RemoteCommand) onSendCommand;

  const _AppsTab({
    required this.scrollController,
    required this.philipsApps,
    required this.philipsAppsLoaded,
    required this.onCommonApp,
    required this.onLaunchPhilipsApp,
    required this.onSendCommand,
    this.onRetryApps,
    this.showKeyboardButton = false,
    this.onKeyboard,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        // Streaming shortcuts
        _SectionLabel('Streaming'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _AppChip(
              label: 'Netflix',
              color: const Color(0xFFE50914),
              icon: Icons.play_circle_fill_rounded,
              onTap: () => onCommonApp(RemoteCommand.netflix),
            ),
            _AppChip(
              label: 'YouTube',
              color: const Color(0xFFFF0000),
              icon: Icons.smart_display_rounded,
              onTap: () => onCommonApp(RemoteCommand.youtube),
            ),
            _AppChip(
              label: 'Spotify',
              color: const Color(0xFF1DB954),
              icon: Icons.music_note_rounded,
              onTap: () => onCommonApp(RemoteCommand.spotify),
            ),
            _AppChip(
              label: 'Prime',
              color: const Color(0xFF00A8E0),
              icon: Icons.local_shipping_rounded,
              onTap: () => onCommonApp(RemoteCommand.prime),
            ),
            _AppChip(
              label: 'Disney+',
              color: const Color(0xFF113CCF),
              icon: Icons.auto_awesome_rounded,
              onTap: () => onCommonApp(RemoteCommand.disney),
            ),
            _AppChip(
              label: 'Twitch',
              color: const Color(0xFF9146FF),
              icon: Icons.live_tv_rounded,
              onTap: () => onCommonApp(RemoteCommand.twitch),
            ),
          ],
        ),

        // Color keys — moved from main remote screen (Philips / Android TV)
        const SizedBox(height: 20),
        _SectionLabel('Color Keys'),
        const SizedBox(height: 12),
        Row(children: [
          _ColorKeyChip(color: const Color(0xFFEF4444),
              label: 'Red',    onTap: () => onSendCommand(RemoteCommand.colorRed)),
          const SizedBox(width: 8),
          _ColorKeyChip(color: const Color(0xFF10B981),
              label: 'Green',  onTap: () => onSendCommand(RemoteCommand.colorGreen)),
          const SizedBox(width: 8),
          _ColorKeyChip(color: const Color(0xFFF59E0B),
              label: 'Yellow', onTap: () => onSendCommand(RemoteCommand.colorYellow)),
          const SizedBox(width: 8),
          _ColorKeyChip(color: const Color(0xFF3B82F6),
              label: 'Blue',   onTap: () => onSendCommand(RemoteCommand.colorBlue)),
        ]),

        // Info button (moved from main remote screen bottom row)
        const SizedBox(height: 20),
        _SectionLabel('TV Controls'),
        const SizedBox(height: 12),
        Row(children: [
          _AppChip(
            label: 'Info',
            color: const Color(0xFF8B5CF6),
            icon: Icons.info_outline_rounded,
            onTap: () => onSendCommand(RemoteCommand.info),
          ),
          const SizedBox(width: 12),
          _AppChip(
            label: 'Guide',
            color: const Color(0xFF22222A),
            icon: Icons.calendar_view_week_rounded,
            onTap: () => onSendCommand(RemoteCommand.guide),
          ),
        ]),

        if (showKeyboardButton) ...[
          const SizedBox(height: 20),
          _SectionLabel('Tools'),
          const SizedBox(height: 12),
          _AppChip(
            label: 'Keyboard',
            color: const Color(0xFF22222A),
            icon: Icons.keyboard_outlined,
            onTap: onKeyboard ?? () {},
          ),
        ],

        if (onLaunchPhilipsApp != null) ...[
          const SizedBox(height: 24),
          _SectionLabel('TV Applications'),
          const SizedBox(height: 12),
          if (!philipsAppsLoaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF8B5CF6))),
                    SizedBox(width: 12),
                    Text('Loading apps...', style: TextStyle(color: Color(0xFF8A8A93))),
                  ],
                ),
              ),
            )
          else if (philipsApps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const Text(
                    'App list unavailable.\n(Requires API v6 or active connection)',
                    style: TextStyle(color: Color(0xFF8A8A93), fontSize: 13, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  if (onRetryApps != null) ...
                    [
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: onRetryApps,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8B5CF6),
                          side: const BorderSide(color: Color(0xFF8B5CF6)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Retry', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: philipsApps.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.25),
              itemBuilder: (_, i) {
                final app   = philipsApps[i];
                final label = app['label'] as String? ??
                    (app['intent']?['component']?['packageName'] as String?)
                        ?.split('.').last ?? 'App';
                return GestureDetector(
                  onTap: () { HapticFeedback.lightImpact(); onLaunchPhilipsApp!(app); },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF22222A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.apps_rounded, color: Color(0xFF8B5CF6), size: 24),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(label,
                            style: const TextStyle(color: Colors.white, fontSize: 10,
                                fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center),
                      ),
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
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.keyboard_outlined, color: Color(0xFF8B5CF6), size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Send text to TV',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
                'Open keyboard to type text that will be\nsent directly to the TV screen.',
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
          textAlign: TextAlign.center,
        ),
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
              color: const Color(0xFF22222A),
              borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.tv_rounded, color: Color(0xFF8B5CF6), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(device.displayName,
                style: const TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (hasBrand)
              Text(BrandMenuSheet.brandLabel(brand!),
                  style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 12,
                      fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
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
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.3),
          tabs: const [
            Tab(text: 'APPS'),
            Tab(text: 'AMBILIGHT'),
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
  const _AppChip(
      {required this.label, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _ColorKeyChip extends StatelessWidget {
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ColorKeyChip(
      {required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)],
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
