/// Application-wide constants for TitanCast
/// Centralized configuration values to avoid magic numbers and strings

/// Network configuration constants
class NetworkConstants {
  NetworkConstants._();
  
  // Common TV ports by brand
  static const int samsungTvPort = 8001;
  static const int lgTvPort = 3000; 
  static const int sonyTvPort = 80;
  static const int philipsOldPort = 1925;
  static const int philipsNewPort = 1926;
  static const int androidTvPort = 5555;
  static const int torimaPort = 5555;
  static const int dialPort = 8008;
  static const int chromecastPort = 8008;
  static const int pjLinkPort = 4352;
  
  // Timeout values
  static const Duration defaultTimeout = Duration(seconds: 10);
  static const Duration tcpTimeout = Duration(seconds: 4);
  static const Duration httpTimeout = Duration(seconds: 8);
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration discoveryTimeout = Duration(seconds: 15);
  
  // Discovery intervals
  static const Duration discoveryProbeDelay = Duration(milliseconds: 200);
  static const Duration keyboardPollInterval = Duration(seconds: 2);
  
  // Retry configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}

/// UI Constants and themes
class UIConstants {
  UIConstants._();
  
  // Colors
  static const int primaryPurple = 0xFF8B5CF6;
  static const int deepBackground = 0xFF0A0A0E;
  static const int panelColor = 0xFF15151A;
  static const int successGreen = 0xFF10B981;
  static const int warningOrange = 0xFFF97316;
  static const int errorRed = 0xFFEF4444;
  
  // Dimensions
  static const double defaultPadding = 16.0;
  static const double compactPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double largeBorderRadius = 32.0;
  
  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 500);
  static const Duration longAnimation = Duration(seconds: 2);
}

/// Logging and debugging constants
class LoggingConstants {
  LoggingConstants._();
  
  static const int maxLogEntries = 1000;
  static const int maxLogLineLength = 200;
  
  // Log levels
  static const String verbose = 'V';
  static const String debug = 'D';
  static const String info = 'I';
  static const String warning = 'W';
  static const String error = 'E';
}

/// Storage and preferences keys
class StorageConstants {
  StorageConstants._();
  
  // SharedPreferences keys
  static const String keyActiveDeviceIp = 'active_device_ip';
  static const String keyDeviceCache = 'device_cache';
  static const String keyLgClientKeyPrefix = 'lg_client_key_';
  static const String keyPhilipsUserPrefix = 'philips_user_';
  static const String keyPhilipsPassPrefix = 'philips_pass_';
  static const String keyPhilipsDevIdPrefix = 'philips_devid_';
  static const String keyAndroidAdbKeyPrefix = 'android_adb_key_';
  
  // File paths and extensions
  static const String logFileName = 'titancast_logs.txt';
  static const String configFileName = 'titancast_config.json';
}

/// API and protocol constants
class ProtocolConstants {
  ProtocolConstants._();
  
  // Common headers
  static const String contentTypeJson = 'application/json';
  static const String contentTypeXml = 'text/xml; charset=utf-8';
  static const String userAgentHeader = 'TitanCast/1.0';
  
  // Samsung specific
  static const String samsungRemoteControlPath = '/api/v2/channels/samsung.remote.control';
  
  // LG WebOS specific
  static const String lgWebOsRegisterType = 'register';
  
  // Sony specific  
  static const String sonyIrccPath = '/sony/IRCC';
  static const String sonySoapAction = '"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC"';
  
  // Philips specific
  static const String philipsInputKeyPath = '/input/key';
  static const String philipsSystemPath = '/system';
  
  // ADB specific  
  static const String adbShellPrefix = 'shell:';
  static const String adbInputKeyEvent = 'input keyevent';
  static const String adbInputText = 'input text';
}