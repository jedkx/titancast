/// Security utilities for TitanCast application
/// Provides secure HTTP clients, certificate validation, and encryption utilities

import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'app_logger.dart';

/// Security configuration and policies
class SecurityConfig {
  SecurityConfig._();
  
  /// Whether to allow self-signed certificates in development
  static bool allowSelfSignedCerts = kDebugMode;
  
  /// Maximum HTTP request timeout for security
  static const Duration maxRequestTimeout = Duration(seconds: 30);
  
  /// Allowed certificate authorities (empty means allow any in debug)
  static final Set<String> allowedCAs = <String>{};
  
  /// Enable certificate pinning (disable in debug for easier testing)
  static bool enableCertificatePinning = kReleaseMode;
}

/// Secure HTTP client factory
class SecureHttpClient {
  SecureHttpClient._();
  
  /// Create a secure HTTP client with proper certificate validation
  static http.Client create({
    Duration timeout = const Duration(seconds: 10),
    bool allowSelfSignedInDebug = true,
  }) {
    if (kIsWeb) {
      return http.Client();
    }
    
    final httpClient = HttpClient();
    
    // Configure timeouts
    httpClient.connectionTimeout = timeout;
    httpClient.idleTimeout = timeout;
    
    // Configure certificate validation
    httpClient.badCertificateCallback = (cert, host, port) {
      AppLogger.w('HTTP', 'Certificate validation for $host:$port');
      
      // In production, always validate certificates
      if (kReleaseMode) {
        AppLogger.e('HTTP', 'Invalid certificate for $host:$port in production');
        return false;
      }
      
      // In debug mode, allow self-signed if configured
      if (kDebugMode && allowSelfSignedInDebug) {
        AppLogger.w('HTTP', 'Allowing self-signed certificate for $host:$port in debug mode');
        return true;
      }
      
      return false;
    };
    
    return IOClient(httpClient);
  }
  
  /// Create a client specifically for local TV communication
  /// TVs often use self-signed certificates
  static http.Client createForTv({
    required String tvHost,
    Duration timeout = const Duration(seconds: 10),
  }) {
    if (kIsWeb) {
      return http.Client();
    }
    
    final httpClient = HttpClient();
    httpClient.connectionTimeout = timeout;
    httpClient.idleTimeout = timeout;
    
    // Special handling for TV certificates
    httpClient.badCertificateCallback = (cert, host, port) {
      // Only allow for the specific TV host
      if (host == tvHost) {
        AppLogger.d('HTTP', 'Allowing certificate for TV at $host:$port');
        return true;
      }
      
      AppLogger.w('HTTP', 'Rejecting certificate for non-TV host $host:$port');
      return false;
    };
    
    return IOClient(httpClient);
  }
}

/// Encryption utilities for authentication and secure storage
class EncryptionUtils {
  EncryptionUtils._();
  
  /// Generate secure random string
  static String generateSecureRandom(int length) {
    final random = secureRandom();
    final bytes = List.generate(length, (_) => random.nextInt(256));
    return base64.encode(bytes);
  }
  
  /// Generate secure random bytes
  static Uint8List generateSecureRandomBytes(int length) {
    final random = secureRandom();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }
  
  /// Secure random number generator
  static Random secureRandom() {
    return Random.secure();
  }
  
  /// Hash a string using SHA-256
  static String hashSha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Hash bytes using SHA-256
  static String hashBytesSha256(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Generate HMAC-SHA256
  static String generateHmac(String message, String key) {
    final keyBytes = utf8.encode(key);
    final messageBytes = utf8.encode(message);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(messageBytes);
    return digest.toString();
  }
  
  /// Validate HMAC-SHA256
  static bool validateHmac(String message, String key, String expectedHmac) {
    final actualHmac = generateHmac(message, key);
    return actualHmac == expectedHmac;
  }
  
  /// Generate UUID v4 (random)
  static String generateUuid() {
    final random = secureRandom();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    
    // Set version (4) and variant bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    
    final uuid = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${uuid.substring(0, 8)}-${uuid.substring(8, 12)}-${uuid.substring(12, 16)}-${uuid.substring(16, 20)}-${uuid.substring(20, 32)}';
  }
}

/// Input validation and sanitization
class InputValidator {
  InputValidator._();
  
  /// Validate IP address format
  static bool isValidIpAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    
    return true;
  }
  
  /// Validate port number
  static bool isValidPort(int port) {
    return port > 0 && port <= 65535;
  }
  
  /// Validate hostname
  static bool isValidHostname(String hostname) {
    if (hostname.isEmpty || hostname.length > 255) return false;
    
    final regex = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9\-\.]*[a-zA-Z0-9]$');
    return regex.hasMatch(hostname);
  }
  
  /// Sanitize user input to prevent injection attacks
  static String sanitizeInput(String input) {
    return input
        .replaceAll(RegExp(r'[<>"\&]'), '') // Remove potentially dangerous characters
        .trim()
        .substring(0, input.length > 1000 ? 1000 : input.length); // Limit length
  }
  
  /// Validate TV device name (alphanumeric, spaces, hyphens only)
  static bool isValidDeviceName(String name) {
    if (name.isEmpty || name.length > 100) return false;
    final regex = RegExp(r'^[a-zA-Z0-9 \-_\.]+$');
    return regex.hasMatch(name);
  }
  
  /// Validate PIN codes (4-8 digits)
  static bool isValidPin(String pin) {
    if (pin.length < 4 || pin.length > 8) return false;
    final regex = RegExp(r'^\d+$');
    return regex.hasMatch(pin);
  }
}

/// Secure storage for sensitive data
/// Note: This is a basic implementation. In production, consider using
/// flutter_secure_storage or similar packages for platform-specific secure storage.
class SecureStorage {
  SecureStorage._();
  
  static const String _keyPrefix = 'secure_';
  
  /// Encode sensitive data before storage
  static String encodeForStorage(String data) {
    // In a real implementation, you might encrypt the data here
    // For now, we'll just base64 encode to prevent casual inspection
    return base64.encode(utf8.encode(data));
  }
  
  /// Decode sensitive data from storage
  static String decodeFromStorage(String encodedData) {
    try {
      return utf8.decode(base64.decode(encodedData));
    } catch (e) {
      AppLogger.e('SecureStorage', 'Failed to decode stored data: $e');
      return '';
    }
  }
  
  /// Generate storage key
  static String generateStorageKey(String identifier) {
    return '$_keyPrefix${hashIdentifier(identifier)}';
  }
  
  /// Hash identifier for consistent storage keys
  static String hashIdentifier(String identifier) {
    return EncryptionUtils.hashSha256(identifier).substring(0, 16);
  }
  
  /// Validate stored data integrity
  static bool validateStoredData(String data, String expectedHash) {
    final actualHash = EncryptionUtils.hashSha256(data);
    return actualHash == expectedHash;
  }
}

/// Rate limiting for network requests
class RateLimiter {
  RateLimiter._();
  
  static final Map<String, DateTime> _lastRequest = {};
  static final Map<String, int> _requestCount = {};
  
  /// Check if request is allowed (simple rate limiting)
  static bool allowRequest(String identifier, {
    Duration minInterval = const Duration(milliseconds: 100),
    int maxRequestsPerMinute = 60,
  }) {
    final now = DateTime.now();
    final lastRequest = _lastRequest[identifier];
    
    // Check minimum interval
    if (lastRequest != null && now.difference(lastRequest) < minInterval) {
      AppLogger.w('RateLimit', 'Request too soon for $identifier');
      return false;
    }
    
    // Check requests per minute
    final count = _requestCount[identifier] ?? 0;
    if (count >= maxRequestsPerMinute) {
      AppLogger.w('RateLimit', 'Too many requests for $identifier');
      return false;
    }
    
    // Update counters
    _lastRequest[identifier] = now;
    _requestCount[identifier] = count + 1;
    
    // Reset counter every minute
    Future.delayed(const Duration(minutes: 1), () {
      _requestCount.remove(identifier);
    });
    
    return true;
  }
  
  /// Clear rate limit data
  static void clear() {
    _lastRequest.clear();
    _requestCount.clear();
  }
}