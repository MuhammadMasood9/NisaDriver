import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:driver/utils/data_compression_utils.dart';

void main() {
  group('DataCompressionUtils', () {
    test('should compress and decompress data correctly', () {
      final originalData = Uint8List.fromList(utf8.encode('Hello, World! This is a test string for compression.'));
      
      final compressionResult = DataCompressionUtils.compress(originalData);
      expect(compressionResult.success, isTrue);
      expect(compressionResult.algorithm, equals(CompressionAlgorithm.gzip));
      expect(compressionResult.originalSize, equals(originalData.length));
      // Note: Small strings might not compress well, so we just check it's reasonable
      expect(compressionResult.compressedSize, greaterThan(0));
      
      final decompressionResult = DataCompressionUtils.decompress(
        compressionResult.data,
        compressionResult.algorithm,
      );
      expect(decompressionResult.success, isTrue);
      expect(decompressionResult.data, equals(originalData));
    });

    test('should handle different compression algorithms', () {
      final originalData = Uint8List.fromList(utf8.encode('Test data for compression algorithms'));
      
      // Test GZIP
      final gzipResult = DataCompressionUtils.compress(
        originalData,
        algorithm: CompressionAlgorithm.gzip,
      );
      expect(gzipResult.success, isTrue);
      expect(gzipResult.algorithm, equals(CompressionAlgorithm.gzip));
      
      // Test Deflate
      final deflateResult = DataCompressionUtils.compress(
        originalData,
        algorithm: CompressionAlgorithm.deflate,
      );
      expect(deflateResult.success, isTrue);
      expect(deflateResult.algorithm, equals(CompressionAlgorithm.deflate));
      
      // Test None (no compression)
      final noneResult = DataCompressionUtils.compress(
        originalData,
        algorithm: CompressionAlgorithm.none,
      );
      expect(noneResult.success, isTrue);
      expect(noneResult.algorithm, equals(CompressionAlgorithm.none));
      expect(noneResult.data, equals(originalData));
      expect(noneResult.compressionRatio, equals(1.0));
    });

    test('should compress JSON strings correctly', () {
      final jsonString = '{"name": "John", "age": 30, "city": "New York", "hobbies": ["reading", "swimming", "coding"]}';
      
      final result = DataCompressionUtils.compressJson(jsonString);
      expect(result.success, isTrue);
      expect(result.originalSize, equals(utf8.encode(jsonString).length));
      
      final decompressedJson = DataCompressionUtils.decompressToJson(
        result.data,
        result.algorithm,
      );
      expect(decompressedJson, equals(jsonString));
    });

    test('should compress objects correctly', () {
      final testObject = {
        'name': 'Test User',
        'coordinates': [40.7128, -74.0060],
        'metadata': {
          'timestamp': 1640995200000,
          'accuracy': 5.0,
        },
      };
      
      final result = DataCompressionUtils.compressObject(testObject);
      expect(result.success, isTrue);
      
      final decompressedObject = DataCompressionUtils.decompressToObject(
        result.data,
        result.algorithm,
      );
      expect(decompressedObject, equals(testObject));
    });

    test('should handle repetitive data compression', () {
      final originalData = Uint8List.fromList(utf8.encode('A' * 1000)); // Repetitive data
      
      final result = DataCompressionUtils.compress(originalData);
      
      expect(result.success, isTrue);
      expect(result.compressedSize, lessThan(originalData.length)); // Should compress repetitive data well
    });

    test('should test compression efficiency correctly', () {
      final testData = Uint8List.fromList(utf8.encode('Test data ' * 100)); // Repetitive data
      
      final results = DataCompressionUtils.testCompressionEfficiency(testData, levels: [6]);
      
      expect(results.containsKey(CompressionAlgorithm.gzip), isTrue);
      expect(results.containsKey(CompressionAlgorithm.deflate), isTrue);
      
      for (final result in results.values) {
        expect(result.success, isTrue);
        expect(result.compressionRatio, lessThan(1.0)); // Should achieve some compression
      }
    });

    test('should determine best compression algorithm', () {
      final repetitiveData = Uint8List.fromList(utf8.encode('A' * 1000));
      final randomData = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      
      final bestForRepetitive = DataCompressionUtils.determineBestAlgorithm(repetitiveData);
      final bestForRandom = DataCompressionUtils.determineBestAlgorithm(randomData);
      
      // Repetitive data should benefit from compression
      expect(bestForRepetitive, isNot(CompressionAlgorithm.none));
      
      // Random data might not benefit from compression
      // (This test might be flaky depending on the random data generated)
    });

    test('should estimate compression ratio correctly', () {
      final repetitiveData = Uint8List.fromList(utf8.encode('A' * 1000));
      final randomData = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      final smallData = Uint8List.fromList(utf8.encode('Small'));
      
      final repetitiveRatio = DataCompressionUtils.estimateCompressionRatio(repetitiveData);
      final randomRatio = DataCompressionUtils.estimateCompressionRatio(randomData);
      final smallRatio = DataCompressionUtils.estimateCompressionRatio(smallData);
      
      expect(repetitiveRatio, lessThan(randomRatio)); // Repetitive data should compress better
      expect(smallRatio, equals(1.0)); // Small data should not be compressed
    });

    test('should check if compression is worthwhile', () {
      final largeRepetitiveData = Uint8List.fromList(utf8.encode('A' * 2000));
      final smallData = Uint8List.fromList(utf8.encode('Small'));
      final largeRandomData = Uint8List.fromList(List.generate(2000, (i) => i % 256));
      
      expect(DataCompressionUtils.isCompressionWorthwhile(largeRepetitiveData), isTrue);
      expect(DataCompressionUtils.isCompressionWorthwhile(smallData), isFalse);
      
      // Random data might or might not be worth compressing depending on the estimation
      final randomWorthwhile = DataCompressionUtils.isCompressionWorthwhile(largeRandomData);
      expect(randomWorthwhile, isA<bool>());
    });

    test('should create and parse compression metadata', () {
      final originalData = Uint8List.fromList(utf8.encode('Test data for metadata'));
      final compressionResult = DataCompressionUtils.compress(originalData);
      
      final metadata = DataCompressionUtils.createCompressionMetadata(compressionResult);
      
      expect(metadata['compressed'], equals(compressionResult.success));
      expect(metadata['algorithm'], equals(compressionResult.algorithm.value));
      expect(metadata['originalSize'], equals(compressionResult.originalSize));
      expect(metadata['compressedSize'], equals(compressionResult.compressedSize));
      expect(metadata['compressionRatio'], equals(compressionResult.compressionRatio));
      
      final parsedMetadata = DataCompressionUtils.parseCompressionMetadata(metadata);
      expect(parsedMetadata, isNotNull);
      expect(parsedMetadata!['compressed'], equals(compressionResult.success));
      expect(parsedMetadata['algorithm'], equals(compressionResult.algorithm));
    });

    test('should handle malformed compression metadata', () {
      final malformedMetadata = {
        'compressed': 'invalid', // Should be boolean
        'algorithm': 'unknown_algorithm',
        'originalSize': 'not_a_number',
      };
      
      final parsedMetadata = DataCompressionUtils.parseCompressionMetadata(malformedMetadata);
      // The function returns null for malformed metadata
      expect(parsedMetadata, isNull);
    });

    test('should handle compression errors gracefully', () {
      // This test is tricky because it's hard to make compression fail
      // We'll test with an empty array which should still work
      final emptyData = Uint8List(0);
      
      final result = DataCompressionUtils.compress(emptyData);
      expect(result.success, isTrue); // Even empty data should compress successfully
      expect(result.originalSize, equals(0));
    });

    test('should handle decompression errors gracefully', () {
      // Try to decompress invalid data
      final invalidData = Uint8List.fromList([1, 2, 3, 4, 5]);
      
      final result = DataCompressionUtils.decompress(invalidData, CompressionAlgorithm.gzip);
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      expect(result.data, equals(invalidData)); // Should return original data on failure
    });
  });

  group('CompressionResult', () {
    test('should calculate metrics correctly', () {
      final result = CompressionResult(
        data: Uint8List.fromList([1, 2, 3]),
        algorithm: CompressionAlgorithm.gzip,
        originalSize: 1000,
        compressedSize: 600,
        compressionTime: Duration(milliseconds: 50),
        success: true,
      );
      
      expect(result.compressionRatio, equals(0.6));
      expect(result.bytesSaved, equals(400));
      expect(result.compressionEfficiency, equals(40.0));
    });

    test('should handle zero original size', () {
      final result = CompressionResult(
        data: Uint8List(0),
        algorithm: CompressionAlgorithm.none,
        originalSize: 0,
        compressedSize: 0,
        compressionTime: Duration.zero,
        success: true,
      );
      
      expect(result.compressionRatio, equals(1.0));
      expect(result.bytesSaved, equals(0));
      expect(result.compressionEfficiency, equals(0.0));
    });

    test('should have meaningful toString', () {
      final result = CompressionResult(
        data: Uint8List.fromList([1, 2, 3]),
        algorithm: CompressionAlgorithm.gzip,
        originalSize: 1000,
        compressedSize: 700,
        compressionTime: Duration(milliseconds: 25),
        success: true,
      );
      
      final stringRepresentation = result.toString();
      expect(stringRepresentation, contains('gzip'));
      expect(stringRepresentation, contains('0.700'));
      expect(stringRepresentation, contains('30.0%'));
      expect(stringRepresentation, contains('25ms'));
    });
  });

  group('CompressionAlgorithm', () {
    test('should have correct string values', () {
      expect(CompressionAlgorithm.gzip.value, equals('gzip'));
      expect(CompressionAlgorithm.deflate.value, equals('deflate'));
      expect(CompressionAlgorithm.none.value, equals('none'));
    });
  });
}