import 'package:flutter/foundation.dart';
import 'package:titancast/discovery/discovery_model.dart';

/// Global ValueNotifier that holds the currently selected device.
///
/// DevicesScreen sets this when the user taps "Connect".
/// RemoteScreen listens to it and builds the RemoteController.
final activeDeviceNotifier = ValueNotifier<DiscoveredDevice?>(null);