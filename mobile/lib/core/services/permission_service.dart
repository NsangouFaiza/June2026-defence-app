import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request Camera Permission
  static Future<bool> requestCameraPermission(BuildContext context) async {
    return _handlePermission(
      context: context,
      permission: Permission.camera,
      title: 'Camera Permission Required',
      message: 'LifeLink needs camera access so you can take a profile photo or scan QR codes.',
    );
  }

  /// Request Photos/Storage Permission for picking images
  static Future<bool> requestPhotosPermission(BuildContext context) async {
    final photosStatus = await Permission.photos.status;
    if (photosStatus.isGranted || photosStatus.isLimited) return true;

    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted || storageStatus.isLimited) return true;

    // Request photos first
    final reqPhotos = await Permission.photos.request();
    if (reqPhotos.isGranted || reqPhotos.isLimited) return true;

    // Fallback to storage request
    final reqStorage = await Permission.storage.request();
    if (reqStorage.isGranted || reqStorage.isLimited) return true;

    if (reqPhotos.isPermanentlyDenied || reqStorage.isPermanentlyDenied) {
      if (context.mounted) {
        _showPermissionDialog(
          context: context,
          title: 'Photo Library Permission Required',
          message: 'LifeLink needs access to your photos to let you choose a profile picture. Please enable it in Settings.',
        );
      }
      return false;
    }
    // Return true so image_picker can fallback to system SAF photo picker if OS permits
    return true;
  }

  /// Request Location Permission
  static Future<bool> requestLocationPermission(BuildContext context) async {
    return _handlePermission(
      context: context,
      permission: Permission.locationWhenInUse,
      title: 'Location Permission Required',
      message: 'LifeLink needs location access to find nearby hospitals, donors, and blood banks.',
    );
  }

  /// Request Microphone Permission
  static Future<bool> requestMicrophonePermission(BuildContext context) async {
    return _handlePermission(
      context: context,
      permission: Permission.microphone,
      title: 'Microphone Permission Required',
      message: 'LifeLink needs microphone access for voice messages in chat.',
    );
  }

  /// Request Notification Permission
  static Future<bool> requestNotificationPermission(BuildContext context) async {
    return _handlePermission(
      context: context,
      permission: Permission.notification,
      title: 'Notification Permission Required',
      message: 'LifeLink needs notification permission to alert you about urgent blood requests and updates.',
    );
  }

  /// Internal generic permission handler following best practices
  static Future<bool> _handlePermission({
    required BuildContext context,
    required Permission permission,
    required String title,
    required String message,
  }) async {
    final status = await permission.status;

    if (status.isGranted || status.isLimited) {
      return true;
    }

    // Request permission if not granted
    final result = await permission.request();

    if (result.isGranted || result.isLimited) {
      return true;
    }

    // If denied or permanently denied, explain and offer settings link
    if (context.mounted) {
      _showPermissionDialog(
        context: context,
        title: title,
        message: message,
      );
    }
    return false;
  }

  /// Display clear explanation dialog with "Open Settings" button
  static void _showPermissionDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Open Settings'),
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }
}
