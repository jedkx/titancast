import 'package:flutter/material.dart';
import '../../discovery/discovery_model.dart';
import '../../discovery/discovery_manager.dart';

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

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isConnecting = true; _errorMessage = null; });

    final ip = _controller.text.trim();
    DiscoveredDevice? found;

    try {
      // Corrected DiscoveryManager usage
      await _manager
          .startDiscovery(mode: DiscoveryMode.manualIp, targetIp: ip)
          .listen((device) { found = device; })
          .asFuture()
          .timeout(const Duration(seconds: 5));
    } catch (_) {}

    if (!mounted) return;

    if (found != null) {
      Navigator.pop(context, found);
    } else {
      setState(() {
        _isConnecting = false;
        _errorMessage = 'Could not find device at $ip';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Enter TV IP Address', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF15151A),
                hintText: '192.168.1.XX',
                hintStyle: const TextStyle(color: Colors.white24),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                errorText: _errorMessage,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                onPressed: _isConnecting ? null : _connect,
                child: _isConnecting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}