/// Result type for better error handling
/// Inspired by Rust's Result<T, E> and Dart's Result pattern
/// Enables functional error handling without exceptions

/// A result that can either contain a success value [T] or a failure value [E]
sealed class Result<T, E> {
  const Result();
  
  /// Create a successful result
  const factory Result.success(T value) = Success<T, E>;
  
  /// Create a failure result  
  const factory Result.failure(E error) = Failure<T, E>;
  
  /// Whether this result represents a success
  bool get isSuccess => this is Success<T, E>;
  
  /// Whether this result represents a failure
  bool get isFailure => this is Failure<T, E>;
  
  /// Get the success value or null
  T? get successValue => switch (this) {
    Success(value: final value) => value,
    Failure() => null,
  };
  
  /// Get the failure value or null
  E? get failureValue => switch (this) {
    Success() => null,
    Failure(error: final error) => error,
  };
  
  /// Transform the success value
  Result<U, E> map<U>(U Function(T) transform) {
    return switch (this) {
      Success(value: final value) => Result.success(transform(value)),
      Failure(error: final error) => Result.failure(error),
    };
  }
  
  /// Transform the failure value
  Result<T, U> mapError<U>(U Function(E) transform) {
    return switch (this) {
      Success(value: final value) => Result.success(value),
      Failure(error: final error) => Result.failure(transform(error)),
    };
  }
  
  /// Chain operations that return Results
  Result<U, E> flatMap<U>(Result<U, E> Function(T) transform) {
    return switch (this) {
      Success(value: final value) => transform(value),
      Failure(error: final error) => Result.failure(error),
    };
  }
  
  /// Get the value or a default
  T getOrElse(T defaultValue) {
    return switch (this) {
      Success(value: final value) => value,
      Failure() => defaultValue,
    };
  }
  
  /// Get the value or compute it from the error
  T getOrElseGet(T Function(E) onFailure) {
    return switch (this) {
      Success(value: final value) => value,
      Failure(error: final error) => onFailure(error),
    };
  }
  
  /// Execute a side effect based on the result
  Result<T, E> peek({
    void Function(T)? onSuccess,
    void Function(E)? onFailure,
  }) {
    switch (this) {
      case Success(value: final value):
        onSuccess?.call(value);
      case Failure(error: final error):
        onFailure?.call(error);
    }
    return this;
  }
}

/// Successful result containing a value
final class Success<T, E> extends Result<T, E> {
  const Success(this.value);
  final T value;
  
  @override
  String toString() => 'Success($value)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> && value == other.value;
  
  @override
  int get hashCode => value.hashCode;
}

/// Failed result containing an error
final class Failure<T, E> extends Result<T, E> {
  const Failure(this.error);
  final E error;
  
  @override
  String toString() => 'Failure($error)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T, E> && error == other.error;
  
  @override
  int get hashCode => error.hashCode;
}

/// Convenience methods for common Result operations
extension ResultExtensions on Result<dynamic, dynamic> {
  /// Convert a Result to a Future
  Future<T> toFuture<T>() async {
    return switch (this) {
      Success(value: final value) => value as T,
      Failure(error: final error) => throw error,
    };
  }
}

/// Utility functions for creating Results from common operations
class ResultUtils {
  ResultUtils._();
  
  /// Wrap a function that might throw in a Result
  static Result<T, Exception> tryCall<T>(T Function() fn) {
    try {
      return Result.success(fn());
    } catch (e) {
      return Result.failure(e as Exception);
    }
  }
  
  /// Wrap an async function that might throw in a Result
  static Future<Result<T, Exception>> tryCallAsync<T>(Future<T> Function() fn) async {
    try {
      final value = await fn();
      return Result.success(value);
    } catch (e) {
      return Result.failure(e as Exception);
    }
  }
  
  /// Combine multiple Results into one
  static Result<List<T>, E> combine<T, E>(List<Result<T, E>> results) {
    final values = <T>[];
    for (final result in results) {
      switch (result) {
        case Success(value: final value):
          values.add(value);
        case Failure(error: final error):
          return Result.failure(error);
      }
    }
    return Result.success(values);
  }
}