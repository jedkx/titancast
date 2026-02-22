// ...existing code...
import 'package:flutter/material.dart';
import '../../discovery/discovery_model.dart';
import '../../discovery/discovery_manager.dart';

/// Full-screen IP address input.
/// Resolves the entered IP, then pops with the discovered [DiscoveredDevice].
class IpInputScreen extends StatefulWidget {
  const IpInputScreen({super.key});

  @override
  State<IpInputScreen> createState() => _IpInputScreenState();
}

class _IpInputScreenState extends State<IpInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final _manager = DiscoveryManager();

  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    _manager.stopDiscovery();
    super.dispose();
  }

  String? _validateIp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an IP address';
    }
    final parts = value.trim().split('.');
    if (parts.length != 4) {
      return 'Enter a valid IPv4 address (e.g. 192.168.1.100)';
    }
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) {
        return 'Each segment must be between 0 and 255';
      }
    }
    return null;
  }

  Future<void> _connect() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    final ip = _controller.text.trim();
    DiscoveredDevice? found;
    String? error;

    await _manager
        .startDiscovery(mode: DiscoveryMode.manualIp, targetIp: ip)
        .listen(
          (device) => found = device,
      onError: (e) => error = e.toString(),
    )
        .asFuture<void>();

    if (!mounted) return;

    if (found != null) {
      Navigator.pop(context, found);
    } else {
      setState(() {
        _isConnecting = false;
        _errorMessage = error ??
            'Could not identify device at $ip. '
                'Check the address and make sure the TV is on.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Enter IP Address'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero icon
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lan_rounded,
                    size: 48,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Connect directly',
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Use this method if your TV did not appear during network scan. '
                    'Enter the IP address shown in your TV\'s network settings.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 32),

              // How to find IP instructions card
              _HowToFindIpCard(
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),

              const SizedBox(height: 32),

              // Input form
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _controller,
                  validator: _validateIp,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _connect(),
                  style: textTheme.bodyLarge?.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 1,
                  ),
                  decoration: InputDecoration(
                    labelText: 'IP Address',
                    hintText: '192.168.1.100',
                    prefixIcon: const Icon(Icons.device_hub_rounded),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    errorText: null, // we show our own error below
                  ),
                ),
              ),

              // Custom error message (more descriptive than validator)
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Connect button
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(180, 48),
                  ),
                  onPressed: _isConnecting ? null : _connect,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isConnecting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.link_rounded),
                      const SizedBox(width: 8),
                      Text(_isConnecting ? 'Connecting...' : 'Connect'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowToFindIpCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _HowToFindIpCard({
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'How to find your TV\'s IP address',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _BrandStep(
              brand: 'Samsung',
              path: 'Settings > General > Network > Network Status',
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            _BrandStep(
              brand: 'LG',
              path: 'Settings > Network > Wi-Fi Connection > Advanced',
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            _BrandStep(
              brand: 'Sony',
              path: 'Settings > Network > Network Setup > View Network Status',
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            _BrandStep(
              brand: 'Philips',
              path: 'Settings > Network Settings > View Network Settings',
              colorScheme: colorScheme,
              textTheme: textTheme,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandStep extends StatelessWidget {
  final String brand;
  final String path;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isLast;

  const _BrandStep({
    required this.brand,
    required this.path,
    required this.colorScheme,
    required this.textTheme,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              brand,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              path,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}