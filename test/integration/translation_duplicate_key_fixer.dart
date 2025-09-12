import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Translation Duplicate Key Fixer', () {
    test('should identify and fix duplicate keys in English translation file', () async {
      final file = File('lib/lang/app_en.dart');
      final content = await file.readAsString();
      
      // Parse the content to find duplicate keys
      final lines = content.split('\n');
      final Map<String, List<int>> keyOccurrences = {};
      final List<String> fixedLines = [];
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        
        // Skip non-key lines
        if (!line.contains(':') || line.startsWith('//') || line.startsWith('const') || line.startsWith('}')) {
          fixedLines.add(lines[i]);
          continue;
        }
        
        // Extract key from line
        final keyMatch = RegExp(r'["\']([^"\']+)["\']').firstMatch(line);
        if (keyMatch != null) {
          final key = keyMatch.group(1)!;
          
          if (keyOccurrences.containsKey(key)) {
            // This is a duplicate key, modify it
            keyOccurrences[key]!.add(i);
            final newKey = '${key}_${keyOccurrences[key]!.length}';
            final newLine = line.replaceFirst('"$key"', '"$newKey"').replaceFirst("'$key'", "'$newKey'");
            fixedLines.add(newLine);
            print('Fixed duplicate key: "$key" -> "$newKey" at line ${i + 1}');
          } else {
            keyOccurrences[key] = [i];
            fixedLines.add(lines[i]);
          }
        } else {
          fixedLines.add(lines[i]);
        }
      }
      
      // Write the fixed content back to file
      final fixedContent = fixedLines.join('\n');
      await file.writeAsString(fixedContent);
      
      print('Fixed ${keyOccurrences.values.where((list) => list.length > 1).length} duplicate keys in English file');
    });

    test('should identify and fix duplicate keys in Urdu translation file', () async {
      final file = File('lib/lang/app_ur.dart');
      final content = await file.readAsString();
      
      // Parse the content to find duplicate keys
      final lines = content.split('\n');
      final Map<String, List<int>> keyOccurrences = {};
      final List<String> fixedLines = [];
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        
        // Skip non-key lines
        if (!line.contains(':') || line.startsWith('//') || line.startsWith('const') || line.startsWith('}')) {
          fixedLines.add(lines[i]);
          continue;
        }
        
        // Extract key from line
        final keyMatch = RegExp(r'["\']([^"\']+)["\']').firstMatch(line);
        if (keyMatch != null) {
          final key = keyMatch.group(1)!;
          
          if (keyOccurrences.containsKey(key)) {
            // This is a duplicate key, modify it
            keyOccurrences[key]!.add(i);
            final newKey = '${key}_${keyOccurrences[key]!.length}';
            final newLine = line.replaceFirst('"$key"', '"$newKey"').replaceFirst("'$key'", "'$newKey'");
            fixedLines.add(newLine);
            print('Fixed duplicate key: "$key" -> "$newKey" at line ${i + 1}');
          } else {
            keyOccurrences[key] = [i];
            fixedLines.add(lines[i]);
          }
        } else {
          fixedLines.add(lines[i]);
        }
      }
      
      // Write the fixed content back to file
      final fixedContent = fixedLines.join('\n');
      await file.writeAsString(fixedContent);
      
      print('Fixed ${keyOccurrences.values.where((list) => list.length > 1).length} duplicate keys in Urdu file');
    });
  });
}