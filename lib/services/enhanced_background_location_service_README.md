# Enhanced Background Location Service

## Overview

The Enhanced Background Location Service provides intelligent location tracking with ride phase awareness, GPS noise reduction, context-aware update frequency, and robust error handling for the NisaDriver app.

## Key Features

### 1. Ride Phase Awareness
- **En Route to Pickup**: Moderate frequency updates (3-4 seconds)
- **At Pickup Location**: High frequency updates (2 seconds) for precise positioning
- **Ride in Progress**: Standard frequency updates (3 seconds)
- **At Dropoff Location**: High frequency updates (2 seconds) for precise positioning
- **Ride Completed**: Low frequency updates (10+ seconds) to conserve resources

### 2. GPS Noise Reduction
- **Accuracy Filtering**: Filters out location updates with poor accuracy (>50m)
- **Movement Validation**: Prevents GPS noise when stationary by checking minimum movement threshold
- **Weighted Smoothing**: Applies weighted average smoothing based on accuracy scores
- **Position Buffer**: Maintains recent position history for intelligent smoothing

### 3. Context-Aware Update Frequency
- **Network Quality Adaptation**: Adjusts frequency based on network conditions
- **Battery Level Optimization**: Reduces frequency when battery is low
- **Speed-Based Adjustment**: Increases frequency for high-speed travel, reduces for stationary periods
- **Accuracy-Based Tuning**: Adjusts frequency based on GPS accuracy to get better readings

### 4. Robust Error Handling
- **Automatic Retry**: Implements exponential backoff for failed operations
- **Connection Monitoring**: Continuously monitors Firebase connection status
- **Graceful Degradation**: Continues operation even with network issues
- **Recovery Mechanisms**: Automatically restarts location streams on errors

## Implementation Details

### Core Components

1. **EnhancedBackgroundLocationService**: Main service class
2. **AdaptiveUpdateFrequencyManager**: Manages dynamic frequency adjustments
3. **EnhancedRealtimeLocationService**: Handles Firebase operations with retry logic
4. **EnhancedLocationData**: Comprehensive location data model

### Usage Example

```dart
final service = EnhancedBackgroundLocationService();

// Start tracking
await service.startTracking(
  orderId: 'order_123',
  driverId: 'driver_456',
  phase: RidePhase.enRouteToPickup,
);

// Update ride phase
service.updateRidePhase(RidePhase.atPickupLocation);

// Update network conditions
service.updateNetworkConditions(NetworkQuality.poor);

// Update battery level
service.updateBatteryLevel(25.0);

// Monitor status
service.trackingStatus.listen((status) {
  print('Tracking status: ${status.status}');
  print('Accuracy: ${status.accuracy}m');
  print('Issues: ${status.issues}');
});

// Get metrics
final metrics = service.metrics;
print('Total updates: ${metrics.totalUpdates}');
print('Success rate: ${metrics.successRate}%');
print('Average accuracy: ${metrics.averageAccuracy}m');

// Stop tracking
await service.stopTracking();
```

### Configuration

The service automatically configures itself based on:
- Current ride phase
- Network quality
- Battery level
- Driver speed
- Location accuracy

### Frequency Calculation Logic

```dart
// Base interval starts at 3 seconds
int baseSeconds = 3;

// Adjust for ride phase
switch (phase) {
  case RidePhase.atPickupLocation:
  case RidePhase.atDropoffLocation:
    baseSeconds = 2; // More frequent for critical phases
    break;
  case RidePhase.enRouteToPickup:
    baseSeconds = 4; // Less frequent en route
    break;
  case RidePhase.rideCompleted:
    baseSeconds = 10; // Much less frequent when completed
    break;
}

// Adjust for network quality
if (networkQuality == NetworkQuality.poor) {
  baseSeconds = (baseSeconds * 1.6).round();
}

// Adjust for battery level
if (batteryLevel < 20.0) {
  baseSeconds = (baseSeconds * 1.6).round();
}

// Apply bounds (2-30 seconds)
baseSeconds = baseSeconds.clamp(2, 30);
```

### GPS Noise Reduction Algorithm

```dart
bool isLocationValid(Position position) {
  // Check accuracy threshold
  if (position.accuracy > 50.0) return false;
  
  // Check for reasonable coordinates
  if (position.latitude.abs() > 90 || position.longitude.abs() > 180) {
    return false;
  }
  
  // Check for significant movement to avoid GPS noise
  if (lastPosition != null) {
    final distance = calculateDistance(lastPosition, position);
    if (distance < 3.0 && position.accuracy > 10.0) {
      return false; // Likely GPS noise
    }
  }
  
  return true;
}
```

### Error Handling Strategy

1. **Connection Errors**: Retry with exponential backoff
2. **Location Errors**: Restart location stream after delay
3. **Permission Errors**: Request permissions and show user-friendly messages
4. **Firebase Errors**: Queue updates for retry when connection is restored

## Testing

The service includes comprehensive tests covering:
- Ride phase management
- Network quality adaptation
- Battery level optimization
- GPS noise reduction
- Error handling scenarios
- Metrics calculation
- Status tracking

## Requirements Compliance

This implementation addresses the following requirements:

### Requirement 1.1: Enhanced Location Publishing
✅ Publishes location updates every 2-3 seconds during active ride
✅ Includes speed and bearing data in updates
✅ Continues publishing in background

### Requirement 1.2: Location Change Detection
✅ Publishes when location changes by >5 meters OR 3 seconds elapsed
✅ Includes accuracy and timestamp information

### Requirement 3.1: Adaptive Update Frequency
✅ Updates every 3-4 seconds en route to pickup
✅ Updates every 2-3 seconds during ride
✅ Reduces frequency when stationary (>30 seconds)

### Requirement 3.2: Context-Aware Optimization
✅ Adjusts frequency based on network conditions
✅ Reduces frequency when battery is low
✅ Maintains high frequency during critical phases

## Performance Characteristics

- **Battery Usage**: Optimized based on battery level and ride phase
- **Network Usage**: Approximately 0.5KB per location update
- **Memory Usage**: Bounded buffers prevent memory leaks
- **CPU Usage**: Minimal processing with efficient algorithms

## Future Enhancements

1. **Machine Learning**: Predict optimal update frequencies based on historical data
2. **Route Integration**: Snap locations to known routes for better accuracy
3. **Sensor Fusion**: Combine GPS with accelerometer/gyroscope data
4. **Predictive Caching**: Pre-cache location updates during poor connectivity