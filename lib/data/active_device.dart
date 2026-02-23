import 'package:flutter/foundation.dart';
import 'package:titancast/discovery/discovery_model.dart';
import 'package:titancast/remote/remote_controller.dart';

/// Global notifier holding the currently selected device.
/// DevicesScreen sets this when the user taps a device.
/// RemoteScreen listens and builds its RemoteController.
final activeDeviceNotifier = ValueNotifier<DiscoveredDevice?>(null);

/// Global notifier for the *actual* TCP connection state.
/// Updated by RemoteScreen as the RemoteController transitions states.
/// DevicesScreen listens to show an accurate indicator (not just "selected").
final activeConnectionStateNotifier =
    ValueNotifier<RemoteConnectionState>(RemoteConnectionState.disconnected);
