import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/language_controller.dart';
import '../../models/language_model.dart';
import '../../themes/app_colors.dart';
import '../../themes/typography.dart';

/// Widget for testing language switching performance
/// Only available in debug mode
class LanguagePerformanceTest extends StatefulWidget {
  const LanguagePerformanceTest({super.key});

  @override
  State<LanguagePerformanceTest> createState() => _LanguagePerformanceTestState();
}

class _LanguagePerformanceTestState extends State<LanguagePerformanceTest> {
  final List<Map<String, dynamic>> _testResults = [];
  bool _isRunningTest = false;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return GetBuilder<LanguageController>(
      builder: (languageController) {
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language Performance Test',
                  style: AppTypography.headers(context),
                ),
                const SizedBox(height: 16),
                
                // Current performance metrics
                _buildCurrentMetrics(languageController),
                
                const SizedBox(height: 16),
                
                // Test buttons
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _isRunningTest ? null : _runSingleTest,
                      child: Text(_isRunningTest ? 'Testing...' : 'Test Single Switch'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isRunningTest ? null : _runBatchTest,
                      child: Text('Batch Test'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _testResults.isEmpty ? null : _clearResults,
                      child: Text('Clear'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Test results
                if (_testResults.isNotEmpty) _buildTestResults(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentMetrics(LanguageController controller) {
    final metrics = controller.getPerformanceMetrics();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Metrics',
            style: AppTypography.boldLabel(context),
          ),
          const SizedBox(height: 8),
          Text('Language: ${metrics['current_language']}'),
          Text('RTL: ${metrics['is_rtl']}'),
          Text('Initialized: ${metrics['is_initialized']}'),
          Text('Last Switch: ${metrics['last_switch_duration_ms']}ms'),
          Text(
            'Within Requirement: ${metrics['is_within_requirement'] ? '✅' : '❌'}',
            style: TextStyle(
              color: metrics['is_within_requirement'] ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Test Results',
          style: AppTypography.boldLabel(context),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.grey300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            itemCount: _testResults.length,
            itemBuilder: (context, index) {
              final result = _testResults[index];
              final isWithinRequirement = result['duration'] <= 2000;
              
              return ListTile(
                dense: true,
                title: Text(
                  '${result['from']} → ${result['to']}: ${result['duration']}ms',
                  style: TextStyle(
                    color: isWithinRequirement ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
                subtitle: Text(
                  'Success: ${result['success']} | ${result['timestamp']}',
                  style: const TextStyle(fontSize: 10),
                ),
                trailing: Icon(
                  isWithinRequirement ? Icons.check_circle : Icons.error,
                  color: isWithinRequirement ? Colors.green : Colors.red,
                  size: 16,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildTestSummary(),
      ],
    );
  }

  Widget _buildTestSummary() {
    if (_testResults.isEmpty) return const SizedBox.shrink();
    
    final totalTests = _testResults.length;
    final successfulTests = _testResults.where((r) => r['success']).length;
    final withinRequirement = _testResults.where((r) => r['duration'] <= 2000).length;
    final averageDuration = _testResults
        .map((r) => r['duration'] as int)
        .reduce((a, b) => a + b) / totalTests;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: AppTypography.boldLabel(context),
          ),
          Text('Total Tests: $totalTests'),
          Text('Successful: $successfulTests/$totalTests'),
          Text('Within 2s: $withinRequirement/$totalTests'),
          Text('Average Duration: ${averageDuration.toStringAsFixed(1)}ms'),
          Text(
            'Pass Rate: ${((withinRequirement / totalTests) * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: withinRequirement == totalTests ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runSingleTest() async {
    if (_isRunningTest) return;
    
    setState(() {
      _isRunningTest = true;
    });

    try {
      final controller = Get.find<LanguageController>();
      final currentLang = controller.currentLanguageCode;
      final targetLang = currentLang == 'en' ? 'ur' : 'en';
      
      final stopwatch = Stopwatch()..start();
      final success = await controller.changeLanguage(targetLang);
      stopwatch.stop();
      
      _testResults.add({
        'from': currentLang,
        'to': targetLang,
        'duration': stopwatch.elapsedMilliseconds,
        'success': success,
        'timestamp': DateTime.now().toString().substring(11, 19),
      });
      
      debugPrint('Language switch test: $currentLang → $targetLang in ${stopwatch.elapsedMilliseconds}ms (Success: $success)');
    } catch (e) {
      debugPrint('Language switch test failed: $e');
    } finally {
      setState(() {
        _isRunningTest = false;
      });
    }
  }

  Future<void> _runBatchTest() async {
    if (_isRunningTest) return;
    
    setState(() {
      _isRunningTest = true;
    });

    try {
      final languages = ['en', 'ur'];
      
      for (int i = 0; i < 5; i++) {
        for (int j = 0; j < languages.length; j++) {
          final targetLang = languages[j];
          final controller = Get.find<LanguageController>();
          final currentLang = controller.currentLanguageCode;
          
          if (currentLang != targetLang) {
            final stopwatch = Stopwatch()..start();
            final success = await controller.changeLanguage(targetLang);
            stopwatch.stop();
            
            _testResults.add({
              'from': currentLang,
              'to': targetLang,
              'duration': stopwatch.elapsedMilliseconds,
              'success': success,
              'timestamp': DateTime.now().toString().substring(11, 19),
            });
            
            // Small delay between tests
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      }
      
      debugPrint('Batch language switch test completed. ${_testResults.length} tests performed.');
    } catch (e) {
      debugPrint('Batch language switch test failed: $e');
    } finally {
      setState(() {
        _isRunningTest = false;
      });
    }
  }

  void _clearResults() {
    setState(() {
      _testResults.clear();
    });
  }
}