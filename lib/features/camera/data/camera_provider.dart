import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider to get the list of available cameras
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  return await availableCameras();
});

// Provider to manage the camera controller state
class CameraControllerState {
  final CameraController? controller;
  final bool isInitialized;
  final String? error;

  CameraControllerState({
    this.controller,
    this.isInitialized = false,
    this.error,
  });

  CameraControllerState copyWith({
    CameraController? controller,
    bool? isInitialized,
    String? error,
  }) {
    return CameraControllerState(
      controller: controller ?? this.controller,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
    );
  }
}
