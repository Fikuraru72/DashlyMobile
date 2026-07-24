class AppConstants {
  AppConstants._();

  // ─── Google Auth (MUST be Web Client ID from Google Cloud Console) ────
  static const String googleWebClientId = 'CHANGE_ME_TO_WEB_CLIENT_ID';

  // API & Backend
  static const String apiBaseUrl = 'https://apiv2.dashlytrack.cloud';

  // MQTT Broker
  static const String mqttHost = 'apiv2.dashlytrack.cloud';
  static const int mqttPort = 1883;

  // ─── FORCE RENDER: All filters disabled for debugging ──────
  // TODO: Restore original values after debugging
  // RUNNING: Original was 5s / 10m
  static const int runningIntervalSeconds = 5;
  static const double runningDistanceFilter = 0.0; // meters
  static const double maxRunnerSpeedKph = 45.0;

  // CYCLING: Original was 2s / 2m
  static const int cyclingIntervalSeconds = 2;
  static const double cyclingDistanceFilter = 0.0; // meters
  static const double maxCyclingSpeedKph = 100.0;

  // Legacy/default values (used as fallback)
  static const int locationIntervalSeconds = 5;
  static const double minDistanceFilter = 0.0;

  // Storage Keys
  static const String keyOfflineBuffer = 'dashly_offline_buffer';

  // Race Interlock Polling
  static const int interlockPollIntervalSeconds = 5;
}
