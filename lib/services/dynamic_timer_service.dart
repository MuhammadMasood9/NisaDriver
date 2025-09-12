import 'dart:async';
import 'package:get/get.dart';

/// A comprehensive timer service that provides dynamic, synchronized timers
/// for both customer and driver apps with real-time updates
class DynamicTimerService extends GetxService {
  static DynamicTimerService get instance => Get.find<DynamicTimerService>();
  
  // Timer state management
  final Map<String, TimerData> _timers = {};
  final Map<String, StreamController<TimerUpdate>> _streamControllers = {};
  
  // Global timer for periodic updates
  Timer? _globalTimer;
  
  @override
  void onInit() {
    super.onInit();
    _startGlobalTimer();
  }
  
  @override
  void onClose() {
    _globalTimer?.cancel();
    _cleanupAllTimers();
    super.onClose();
  }
  
  /// Start a dynamic timer with real-time updates
  void startTimer({
    required String timerId,
    required int initialDurationSeconds,
    required Function(TimerUpdate) onUpdate,
    Function()? onExpired,
    bool isCountdown = true,
    int updateIntervalMs = 1000,
  }) {
    // Cancel existing timer if any
    stopTimer(timerId);
    
    final now = DateTime.now();
    final endTime = now.add(Duration(seconds: initialDurationSeconds));
    
    final timerData = TimerData(
      id: timerId,
      startTime: now,
      endTime: endTime,
      duration: initialDurationSeconds,
      isCountdown: isCountdown,
      updateInterval: updateIntervalMs,
      onUpdate: onUpdate,
      onExpired: onExpired,
    );
    
    _timers[timerId] = timerData;
    
    // Create stream controller for real-time updates
    _streamControllers[timerId] = StreamController<TimerUpdate>.broadcast();
    
    // Start the timer
    _startTimerInternal(timerData);
  }
  
  /// Start a synchronized timer that updates in real-time
  void startSynchronizedTimer({
    required String timerId,
    required DateTime startTime,
    required int durationSeconds,
    required Function(TimerUpdate) onUpdate,
    Function()? onExpired,
    bool isCountdown = true,
  }) {
    stopTimer(timerId);
    
    final endTime = startTime.add(Duration(seconds: durationSeconds));
    
    final timerData = TimerData(
      id: timerId,
      startTime: startTime,
      endTime: endTime,
      duration: durationSeconds,
      isCountdown: isCountdown,
      updateInterval: 1000,
      onUpdate: onUpdate,
      onExpired: onExpired,
    );
    
    _timers[timerId] = timerData;
    _streamControllers[timerId] = StreamController<TimerUpdate>.broadcast();
    
    _startTimerInternal(timerData);
  }
  
  void _startTimerInternal(TimerData timerData) {
    timerData.timer = Timer.periodic(
      Duration(milliseconds: timerData.updateInterval),
      (timer) {
        final now = DateTime.now();
        final remaining = timerData.endTime.difference(now);
        final elapsed = now.difference(timerData.startTime);
        
        int remainingSeconds = remaining.inSeconds;
        int elapsedSeconds = elapsed.inSeconds;
        
        // Ensure we don't go negative
        if (remainingSeconds < 0) remainingSeconds = 0;
        if (elapsedSeconds > timerData.duration) elapsedSeconds = timerData.duration;
        
        final update = TimerUpdate(
          timerId: timerData.id,
          remainingSeconds: remainingSeconds,
          elapsedSeconds: elapsedSeconds,
          totalDuration: timerData.duration,
          isExpired: remainingSeconds <= 0,
          progress: timerData.isCountdown 
              ? (elapsedSeconds / timerData.duration).clamp(0.0, 1.0)
              : (remainingSeconds / timerData.duration).clamp(0.0, 1.0),
        );
        
        // Update the timer data
        timerData.lastUpdate = update;
        
        // Notify listeners
        timerData.onUpdate(update);
        _streamControllers[timerData.id]?.add(update);
        
        // Check if expired
        if (remainingSeconds <= 0) {
          timer.cancel();
          timerData.timer = null;
          timerData.onExpired?.call();
          _streamControllers[timerData.id]?.close();
          _streamControllers.remove(timerData.id);
        }
      },
    );
  }
  
  /// Stop a specific timer
  void stopTimer(String timerId) {
    final timerData = _timers[timerId];
    if (timerData != null) {
      timerData.timer?.cancel();
      timerData.timer = null;
      _timers.remove(timerId);
      _streamControllers[timerId]?.close();
      _streamControllers.remove(timerId);
    }
  }
  
  /// Pause a timer
  void pauseTimer(String timerId) {
    final timerData = _timers[timerId];
    if (timerData != null && timerData.timer != null) {
      timerData.timer?.cancel();
      timerData.timer = null;
      timerData.isPaused = true;
      timerData.pausedAt = DateTime.now();
    }
  }
  
  /// Resume a paused timer
  void resumeTimer(String timerId) {
    final timerData = _timers[timerId];
    if (timerData != null && timerData.isPaused) {
      // Adjust the end time based on pause duration
      final pauseDuration = DateTime.now().difference(timerData.pausedAt!);
      timerData.endTime = timerData.endTime.add(pauseDuration);
      timerData.isPaused = false;
      timerData.pausedAt = null;
      
      _startTimerInternal(timerData);
    }
  }
  
  /// Get current timer state
  TimerUpdate? getTimerState(String timerId) {
    return _timers[timerId]?.lastUpdate;
  }
  
  /// Get stream for real-time updates
  Stream<TimerUpdate>? getTimerStream(String timerId) {
    return _streamControllers[timerId]?.stream;
  }
  
  /// Check if timer is running
  bool isTimerRunning(String timerId) {
    final timerData = _timers[timerId];
    return timerData != null && timerData.timer != null && !timerData.isPaused;
  }
  
  /// Check if timer is paused
  bool isTimerPaused(String timerId) {
    return _timers[timerId]?.isPaused ?? false;
  }
  
  /// Get all active timers
  List<String> getActiveTimers() {
    return _timers.keys.where((id) => isTimerRunning(id)).toList();
  }
  
  /// Start global timer for periodic updates
  void _startGlobalTimer() {
    _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Update all active timers
      for (final timerData in _timers.values) {
        if (timerData.timer != null && !timerData.isPaused) {
          _updateTimer(timerData);
        }
      }
    });
  }
  
  void _updateTimer(TimerData timerData) {
    final now = DateTime.now();
    final remaining = timerData.endTime.difference(now);
    final elapsed = now.difference(timerData.startTime);
    
    int remainingSeconds = remaining.inSeconds;
    int elapsedSeconds = elapsed.inSeconds;
    
    if (remainingSeconds < 0) remainingSeconds = 0;
    if (elapsedSeconds > timerData.duration) elapsedSeconds = timerData.duration;
    
    final update = TimerUpdate(
      timerId: timerData.id,
      remainingSeconds: remainingSeconds,
      elapsedSeconds: elapsedSeconds,
      totalDuration: timerData.duration,
      isExpired: remainingSeconds <= 0,
      progress: timerData.isCountdown 
          ? (elapsedSeconds / timerData.duration).clamp(0.0, 1.0)
          : (remainingSeconds / timerData.duration).clamp(0.0, 1.0),
    );
    
    timerData.lastUpdate = update;
    timerData.onUpdate(update);
    _streamControllers[timerData.id]?.add(update);
    
    if (remainingSeconds <= 0) {
      timerData.timer?.cancel();
      timerData.timer = null;
      timerData.onExpired?.call();
    }
  }
  
  void _cleanupAllTimers() {
    for (final timerData in _timers.values) {
      timerData.timer?.cancel();
    }
    _timers.clear();
    
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
  }
}

/// Data class for timer information
class TimerData {
  final String id;
  final DateTime startTime;
  DateTime endTime;
  final int duration;
  final bool isCountdown;
  final int updateInterval;
  final Function(TimerUpdate) onUpdate;
  final Function()? onExpired;
  
  Timer? timer;
  TimerUpdate? lastUpdate;
  bool isPaused = false;
  DateTime? pausedAt;
  
  TimerData({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.isCountdown,
    required this.updateInterval,
    onUpdate,
    this.onExpired,
  }) : onUpdate = onUpdate;
}

/// Data class for timer updates
class TimerUpdate {
  final String timerId;
  final int remainingSeconds;
  final int elapsedSeconds;
  final int totalDuration;
  final bool isExpired;
  final double progress; // 0.0 to 1.0
  
  TimerUpdate({
    required this.timerId,
    required this.remainingSeconds,
    required this.elapsedSeconds,
    required this.totalDuration,
    required this.isExpired,
    required this.progress,
  });
  
  /// Format remaining time as MM:SS
  String get formattedTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Format elapsed time as MM:SS
  String get formattedElapsedTime {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Get progress percentage (0-100)
  int get progressPercentage => (progress * 100).round();
}
