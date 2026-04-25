import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  final Connectivity _connectivity = Connectivity();

  factory NetworkService() {
    return _instance;
  }

  NetworkService._internal();

  /// Check if device has internet connectivity
  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      
      // Check if any connection type is active
      if (result.isEmpty) {
        return false;
      }

      // If connected to WiFi or mobile, we assume internet is available
      // (This is a basic check - could be enhanced with actual ping)
      return result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.ethernet);
    } catch (e) {
      // If we can't determine connectivity, assume we have internet
      // (optimistic approach to avoid blocking the user unnecessarily)
      return true;
    }
  }

  /// Get a user-friendly error message for network-related exceptions
  String getNetworkErrorMessage(dynamic exception) {
    final errorString = exception.toString().toLowerCase();

    if (errorString.contains('sockexception') || 
        errorString.contains('failed host lookup') ||
        errorString.contains('network unreachable')) {
      return 'Network connection failed. Please check your internet connection and try again.';
    }

    if (errorString.contains('timeout')) {
      return 'Request timed out. Please check your internet connection and try again.';
    }

    if (errorString.contains('certificate') || 
        errorString.contains('ssl')) {
      return 'Security error. Your device may need to update its certificate bundle.';
    }

    if (errorString.contains('connection refused')) {
      return 'Connection refused. The server may be temporarily unavailable.';
    }

    return 'An error occurred. Please try again.';
  }

  /// Determines if an exception is network-related
  bool isNetworkError(dynamic exception) {
    final errorString = exception.toString().toLowerCase();
    return errorString.contains('sockexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('network');
  }
}
