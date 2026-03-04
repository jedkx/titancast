/// Validation utilities for TitanCast application
/// Provides comprehensive input validation, data sanitization, and business rule validation

import 'dart:convert';
import 'package:titancast/discovery/discovery_model.dart';
import 'package:titancast/remote/tv_brand.dart';
import 'app_logger.dart';

/// Result of a validation operation
class ValidationResult {
  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
  
  /// Create a successful validation result
  const ValidationResult.success() : this(isValid: true);
  
  /// Create a failed validation result
  const ValidationResult.failure(List<String> errors) : this(isValid: false, errors: errors);
  
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  
  /// Check if there are any issues (errors or warnings)
  bool get hasIssues => errors.isNotEmpty || warnings.isNotEmpty;
  
  /// Get formatted error message
  String get errorMessage => errors.join(', ');
  
  /// Combine multiple validation results
  ValidationResult combine(ValidationResult other) {
    return ValidationResult(
      isValid: isValid && other.isValid,
      errors: [...errors, ...other.errors],
      warnings: [...warnings, ...other.warnings],
    );
  }
}

/// Device validation utilities
class DeviceValidator {
  DeviceValidator._();
  
  /// Validate discovered device data
  static ValidationResult validateDiscoveredDevice(DiscoveredDevice device) {
    final errors = <String>[];
    final warnings = <String>[];
    
    // Validate IP address
    if (!NetworkValidator.isValidIpAddress(device.ip)) {
      errors.add('Invalid IP address: ${device.ip}');
    }
    
    // Validate friendly name
    if (device.friendlyName.isEmpty) {
      errors.add('Device name cannot be empty');
    } else if (device.friendlyName.length > 100) {
      errors.add('Device name too long (max 100 characters)');
    }
    
    // Check for suspicious characters in name
    if (!TextValidator.isSafeText(device.friendlyName)) {
      warnings.add('Device name contains potentially unsafe characters');
    }
    
    // Validate port if present
    if (device.port != null && !NetworkValidator.isValidPort(device.port!)) {
      errors.add('Invalid port number: ${device.port}');
    }
    
    // Validate manufacturer if present
    if (device.manufacturer != null && device.manufacturer!.length > 100) {
      warnings.add('Manufacturer name unusually long');
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
  
  /// Validate device connection parameters
  static ValidationResult validateConnectionParams({
    required String ip,
    required int port,
    TvBrand? brand,
  }) {
    final errors = <String>[];
    
    if (!NetworkValidator.isValidIpAddress(ip)) {
      errors.add('Invalid IP address format');
    }
    
    if (!NetworkValidator.isValidPort(port)) {
      errors.add('Invalid port number (must be 1-65535)');
    }
    
    // Brand-specific port validation
    if (brand != null) {
      final expectedPort = _getExpectedPortForBrand(brand);
      if (expectedPort != null && port != expectedPort) {
        errors.add('Unexpected port $port for ${brand.name} (expected $expectedPort)');
      }
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
  
  static int? _getExpectedPortForBrand(TvBrand brand) {
    return switch (brand) {
      TvBrand.samsung => 8001,
      TvBrand.lg => 3000,
      TvBrand.sony => 80,
      TvBrand.philips => null, // Can be 1925 or 1926
      TvBrand.androidTv => 5555,
      TvBrand.torima => 5555,
      _ => null,
    };
  }
}

/// Network validation utilities
class NetworkValidator {
  NetworkValidator._();
  
  /// Validate IP address format (IPv4)
  static bool isValidIpAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    
    return true;
  }
  
  /// Validate IPv6 address format
  static bool isValidIpV6Address(String ip) {
    try {
      final uri = Uri.parse('http://[$ip]');
      return uri.host == ip;
    } catch (_) {
      return false;
    }
  }
  
  /// Check if IP is in private range
  static bool isPrivateIpAddress(String ip) {
    if (!isValidIpAddress(ip)) return false;
    
    final parts = ip.split('.').map(int.parse).toList();
    final firstOctet = parts[0];
    final secondOctet = parts[1];
    
    // 10.x.x.x
    if (firstOctet == 10) return true;
    
    // 172.16.x.x - 172.31.x.x  
    if (firstOctet == 172 && secondOctet >= 16 && secondOctet <= 31) return true;
    
    // 192.168.x.x
    if (firstOctet == 192 && secondOctet == 168) return true;
    
    // 169.254.x.x (link-local)
    if (firstOctet == 169 && secondOctet == 254) return true;
    
    return false;
  }
  
  /// Validate port number
  static bool isValidPort(int port) {
    return port > 0 && port <= 65535;
  }
  
  /// Validate hostname
  static bool isValidHostname(String hostname) {
    if (hostname.isEmpty || hostname.length > 253) return false;
    
    // Split into labels
    final labels = hostname.split('.');
    if (labels.isEmpty) return false;
    
    for (final label in labels) {
      if (label.isEmpty || label.length > 63) return false;
      if (!RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?$').hasMatch(label)) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Validate URL format
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.hasAuthority;
    } catch (_) {
      return false;
    }
  }
  
  /// Check if URL uses secure scheme (https/wss)
  static bool isSecureUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return ['https', 'wss'].contains(uri.scheme);
    } catch (_) {
      return false;
    }
  }
}

/// Text and input validation utilities  
class TextValidator {
  TextValidator._();
  
  /// Check if text contains only safe characters (no scripts/injection)
  static bool isSafeText(String text) {
    // Check for potentially dangerous characters
    final dangerousPatterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'vbscript:', caseSensitive: false),
      RegExp(r'on\w+\s*=', caseSensitive: false),
      RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F-\x9F]'), // Control chars
    ];
    
    for (final pattern in dangerousPatterns) {
      if (pattern.hasMatch(text)) return false;
    }
    
    return true;
  }
  
  /// Sanitize text for safe display
  static String sanitize(String text) {
    return text
        .replaceAll(RegExp(r'<'), '&lt;')
        .replaceAll(RegExp(r'>'), '&gt;')
        .replaceAll(RegExp(r'"'), '&quot;')
        .replaceAll(RegExp(r"'"), '&#x27;')
        .replaceAll(RegExp(r'&'), '&amp;')
        .trim();
  }
  
  /// Validate device name format
  static ValidationResult validateDeviceName(String name) {
    final errors = <String>[];
    final warnings = <String>[];
    
    if (name.isEmpty) {
      errors.add('Device name cannot be empty');
    }
    
    if (name.length > 100) {
      errors.add('Device name too long (max 100 characters)');
    }
    
    if (!RegExp(r'^[a-zA-Z0-9\s\-_\.]+$').hasMatch(name)) {
      errors.add('Device name contains invalid characters');
    }
    
    if (!isSafeText(name)) {
      warnings.add('Device name contains potentially unsafe characters');
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
  
  /// Validate PIN format (typically 4-8 digits)
  static ValidationResult validatePin(String pin) {
    final errors = <String>[];
    
    if (pin.isEmpty) {
      errors.add('PIN cannot be empty');
    }
    
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      errors.add('PIN must be 4-8 digits only');
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
  
  /// Check for common weak PINs
  static bool isWeakPin(String pin) {
    const weakPins = [
      '0000', '1111', '2222', '3333', '4444', 
      '5555', '6666', '7777', '8888', '9999',
      '1234', '4321', '1122', '2211',
    ];
    
    return weakPins.contains(pin);
  }
}

/// JSON validation utilities
class JsonValidator {
  JsonValidator._();
  
  /// Validate JSON string format
  static ValidationResult validateJsonString(String jsonString) {
    try {
      jsonDecode(jsonString);
      return const ValidationResult.success();
    } catch (e) {
      return ValidationResult.failure(['Invalid JSON format: $e']);
    }
  }
  
  /// Validate required fields in JSON object
  static ValidationResult validateRequiredFields(
    Map<String, dynamic> json, 
    List<String> requiredFields,
  ) {
    final errors = <String>[];
    
    for (final field in requiredFields) {
      if (!json.containsKey(field)) {
        errors.add('Missing required field: $field');
      } else if (json[field] == null) {
        errors.add('Required field $field cannot be null');
      }
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
  
  /// Validate JSON object schema
  static ValidationResult validateSchema(
    Map<String, dynamic> json,
    Map<String, Type> schema,
  ) {
    final errors = <String>[];
    
    for (final entry in schema.entries) {
      final fieldName = entry.key;
      final expectedType = entry.value;
      
      if (json.containsKey(fieldName)) {
        final value = json[fieldName];
        if (value != null && value.runtimeType != expectedType) {
          errors.add('Field $fieldName has wrong type: expected $expectedType, got ${value.runtimeType}');
        }
      }
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

/// Business rule validation
class BusinessValidator {
  BusinessValidator._();
  
  /// Validate TV connection business rules
  static ValidationResult validateTvConnection({
    required String ip,
    required TvBrand brand,
    String? psk,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    
    // Sony TVs require PSK for authentication
    if (brand == TvBrand.sony && (psk == null || psk.isEmpty)) {
      warnings.add('Sony TVs typically require a Pre-Shared Key (PSK)');
    }
    
    // Check if IP is in expected private range for TVs
    if (!NetworkValidator.isPrivateIpAddress(ip)) {
      warnings.add('TV IP address is not in private range - this may not be a local device');
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
  
  /// Validate discovery method appropriateness
  static ValidationResult validateDiscoveryMethod(DiscoveryMethod method, String targetIp) {
    final errors = <String>[];
    
    if (method == DiscoveryMethod.manualIp) {
      if (!NetworkValidator.isValidIpAddress(targetIp)) {
        errors.add('Manual IP discovery requires valid IP address');
      }
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

/// Validation utility extensions
extension ValidationExtensions on String {
  /// Quick validation methods for strings
  bool get isValidIp => NetworkValidator.isValidIpAddress(this);
  bool get isValidHostname => NetworkValidator.isValidHostname(this);
  bool get isSafeText => TextValidator.isSafeText(this);
  String get sanitized => TextValidator.sanitize(this);
}

extension ValidationResultExtensions on ValidationResult {
  /// Log validation results
  void logResults(String tag, {String context = ''}) {
    if (hasIssues) {
      if (errors.isNotEmpty) {
        AppLogger.w(tag, 'Validation errors${context.isNotEmpty ? ' in $context' : ''}: ${errors.join(', ')}');
      }
      if (warnings.isNotEmpty) {
        AppLogger.d(tag, 'Validation warnings${context.isNotEmpty ? ' in $context' : ''}: ${warnings.join(', ')}');
      }
    } else {
      AppLogger.v(tag, 'Validation passed${context.isNotEmpty ? ' for $context' : ''}');
    }
  }
}