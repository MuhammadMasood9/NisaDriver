// Data Compression Utilities for Driver App
// This file contains utilities for compressing location data for network optimization

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:developer' as dev;

/// Compression algorithms available
enum CompressionAlgorithm {
  gzip,
  deflate,
  none;

  String get value {
    switch (this) {
      case CompressionAlgorithm.gzip:
        return 'gzip';
      case CompressionAlgorithm.deflate:
        return 'deflate';
      case CompressionAlgorithm.none:
        return 'none';
    }
  }
}

/// Compression result with metadata
class CompressionResult {
  final Uint8List data;
  final CompressionAlgorithm algorithm;
  final int originalSize;
  final int compressedSize;
  final Duration compressionTime;
  final bool success;
  final String? error;

  const CompressionResult({
    required this.data,
    required this.algorithm,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionTime,
    required this.success,
    this.error,
  });

  /// Compression ratio (compressed size / original size)
  double get compressionRatio => originalSize > 0 ? compressedSize / originalSize : 1.0;

  /// Bytes saved through compression
  int get bytesSaved => originalSize - compressedSize;

  /// Compression efficiency as percentage
  double get compressionEfficiency => originalSize > 0 ? (bytesSaved / originalSize) * 100 : 0.0;

  @override
  String toString() {
    return 'CompressionResult(algorithm: ${algorithm.value}, ratio: ${compressionRatio.toStringAsFixed(3)}, efficiency: ${compressionEfficiency.toStringAsFixed(1)}%, time: ${compressionTime.inMilliseconds}ms)';
  }
}

/// Decompression result with metadata
class DecompressionResult {
  final Uint8List data;
  final CompressionAlgorithm algorithm;
  final int originalSize;
  final int decompressedSize;
  final Duration decompressionTime;
  final bool success;
  final String? error;

  const DecompressionResult({
    required this.data,
    required this.algorithm,
    required this.originalSize,
    required this.decompressedSize,
    required this.decompressionTime,
    required this.success,
    this.error,
  });

  @override
  String toString() {
    return 'DecompressionResult(algorithm: ${algorithm.value}, size: ${decompressedSize} bytes, time: ${decompressionTime.inMilliseconds}ms)';
  }
}

/// Utility class for data compression operations
class DataCompressionUtils {
  /// Compress data using the specified algorithm
  static CompressionResult compress(
    Uint8List data, {
    CompressionAlgorithm algorithm = CompressionAlgorithm.gzip,
    int level = 6, // Compression level (1-9, where 9 is best compression)
  }) {
    final stopwatch = Stopwatch()..start();
    final originalSize = data.length;

    try {
      Uint8List compressedData;

      switch (algorithm) {
        case CompressionAlgorithm.gzip:
          compressedData = Uint8List.fromList(gzip.encode(data));
          break;
        case CompressionAlgorithm.deflate:
          compressedData = Uint8List.fromList(zlib.encode(data));
          break;
        case CompressionAlgorithm.none:
          compressedData = data;
          break;
      }

      stopwatch.stop();

      return CompressionResult(
        data: compressedData,
        algorithm: algorithm,
        originalSize: originalSize,
        compressedSize: compressedData.length,
        compressionTime: stopwatch.elapsed,
        success: true,
      );
    } catch (e) {
      stopwatch.stop();
      dev.log('DataCompressionUtils: Compression failed: $e');

      return CompressionResult(
        data: data, // Return original data on failure
        algorithm: CompressionAlgorithm.none,
        originalSize: originalSize,
        compressedSize: originalSize,
        compressionTime: stopwatch.elapsed,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Decompress data using the specified algorithm
  static DecompressionResult decompress(
    Uint8List data,
    CompressionAlgorithm algorithm,
  ) {
    final stopwatch = Stopwatch()..start();
    final originalSize = data.length;

    try {
      Uint8List decompressedData;

      switch (algorithm) {
        case CompressionAlgorithm.gzip:
          decompressedData = Uint8List.fromList(gzip.decode(data));
          break;
        case CompressionAlgorithm.deflate:
          decompressedData = Uint8List.fromList(zlib.decode(data));
          break;
        case CompressionAlgorithm.none:
          decompressedData = data;
          break;
      }

      stopwatch.stop();

      return DecompressionResult(
        data: decompressedData,
        algorithm: algorithm,
        originalSize: originalSize,
        decompressedSize: decompressedData.length,
        decompressionTime: stopwatch.elapsed,
        success: true,
      );
    } catch (e) {
      stopwatch.stop();
      dev.log('DataCompressionUtils: Decompression failed: $e');

      return DecompressionResult(
        data: data, // Return original data on failure
        algorithm: CompressionAlgorithm.none,
        originalSize: originalSize,
        decompressedSize: originalSize,
        decompressionTime: stopwatch.elapsed,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Compress JSON string
  static CompressionResult compressJson(
    String jsonString, {
    CompressionAlgorithm algorithm = CompressionAlgorithm.gzip,
    int level = 6,
  }) {
    final data = Uint8List.fromList(utf8.encode(jsonString));
    return compress(data, algorithm: algorithm, level: level);
  }

  /// Decompress to JSON string
  static String? decompressToJson(
    Uint8List data,
    CompressionAlgorithm algorithm,
  ) {
    final result = decompress(data, algorithm);
    if (result.success) {
      try {
        return utf8.decode(result.data);
      } catch (e) {
        dev.log('DataCompressionUtils: Failed to decode UTF-8: $e');
        return null;
      }
    }
    return null;
  }

  /// Compress object to JSON and then compress the JSON
  static CompressionResult compressObject(
    dynamic object, {
    CompressionAlgorithm algorithm = CompressionAlgorithm.gzip,
    int level = 6,
  }) {
    try {
      final jsonString = jsonEncode(object);
      return compressJson(jsonString, algorithm: algorithm, level: level);
    } catch (e) {
      dev.log('DataCompressionUtils: Failed to encode object to JSON: $e');
      return CompressionResult(
        data: Uint8List(0),
        algorithm: CompressionAlgorithm.none,
        originalSize: 0,
        compressedSize: 0,
        compressionTime: Duration.zero,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Decompress and decode to object
  static dynamic decompressToObject(
    Uint8List data,
    CompressionAlgorithm algorithm,
  ) {
    final jsonString = decompressToJson(data, algorithm);
    if (jsonString != null) {
      try {
        return jsonDecode(jsonString);
      } catch (e) {
        dev.log('DataCompressionUtils: Failed to decode JSON: $e');
        return null;
      }
    }
    return null;
  }

  /// Test compression efficiency for given data
  static Map<CompressionAlgorithm, CompressionResult> testCompressionEfficiency(
    Uint8List data, {
    List<int> levels = const [6], // Levels parameter kept for API compatibility but not used
  }) {
    final results = <CompressionAlgorithm, CompressionResult>{};

    for (final algorithm in [CompressionAlgorithm.gzip, CompressionAlgorithm.deflate]) {
      final result = compress(data, algorithm: algorithm);
      if (result.success) {
        results[algorithm] = result;
      }
    }

    return results;
  }

  /// Determine best compression algorithm for given data
  static CompressionAlgorithm determineBestAlgorithm(
    Uint8List data, {
    double minCompressionRatio = 0.8, // Only compress if we save at least 20%
    Duration maxCompressionTime = const Duration(milliseconds: 100),
  }) {
    final results = testCompressionEfficiency(data);
    
    CompressionAlgorithm bestAlgorithm = CompressionAlgorithm.none;
    double bestRatio = 1.0;
    
    for (final entry in results.entries) {
      final result = entry.value;
      
      // Check if compression meets criteria
      if (result.success &&
          result.compressionRatio < minCompressionRatio &&
          result.compressionTime <= maxCompressionTime &&
          result.compressionRatio < bestRatio) {
        bestAlgorithm = entry.key;
        bestRatio = result.compressionRatio;
      }
    }
    
    return bestAlgorithm;
  }

  /// Estimate compression benefit without actually compressing
  static double estimateCompressionRatio(Uint8List data) {
    // Simple heuristic based on data characteristics
    final length = data.length;
    if (length < 100) return 1.0; // Too small to benefit from compression
    
    // Count unique bytes
    final uniqueBytes = data.toSet().length;
    final entropy = uniqueBytes / 256.0;
    
    // Estimate compression ratio based on entropy
    // Lower entropy (more repetitive data) compresses better
    if (entropy < 0.3) {
      return 0.3; // Very good compression
    } else if (entropy < 0.5) {
      return 0.5; // Good compression
    } else if (entropy < 0.7) {
      return 0.7; // Moderate compression
    } else {
      return 0.9; // Poor compression
    }
  }

  /// Check if data is worth compressing
  static bool isCompressionWorthwhile(
    Uint8List data, {
    int minSize = 1024, // Minimum size to consider compression
    double maxEstimatedRatio = 0.8, // Maximum estimated ratio to compress
  }) {
    if (data.length < minSize) return false;
    
    final estimatedRatio = estimateCompressionRatio(data);
    return estimatedRatio <= maxEstimatedRatio;
  }

  /// Create compression metadata for Firebase storage
  static Map<String, dynamic> createCompressionMetadata(CompressionResult result) {
    return {
      'compressed': result.success && result.algorithm != CompressionAlgorithm.none,
      'algorithm': result.algorithm.value,
      'originalSize': result.originalSize,
      'compressedSize': result.compressedSize,
      'compressionRatio': result.compressionRatio,
      'compressionTime': result.compressionTime.inMilliseconds,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Parse compression metadata from Firebase
  static Map<String, dynamic>? parseCompressionMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    
    try {
      return {
        'compressed': metadata['compressed'] as bool? ?? false,
        'algorithm': CompressionAlgorithm.values.firstWhere(
          (a) => a.value == metadata['algorithm'],
          orElse: () => CompressionAlgorithm.none,
        ),
        'originalSize': metadata['originalSize'] as int? ?? 0,
        'compressedSize': metadata['compressedSize'] as int? ?? 0,
        'compressionRatio': (metadata['compressionRatio'] as num?)?.toDouble() ?? 1.0,
        'compressionTime': metadata['compressionTime'] as int? ?? 0,
        'timestamp': metadata['timestamp'] as int? ?? 0,
      };
    } catch (e) {
      dev.log('DataCompressionUtils: Failed to parse compression metadata: $e');
      return null;
    }
  }
}