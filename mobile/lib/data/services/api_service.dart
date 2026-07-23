import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get baseUrl {
    // 10.0.2.2 is the special IP address to reach the host's localhost from Android emulator
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000/api';
  }

  static String get serverBaseUrl {
    final base = baseUrl;
    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    return base;
  }

  static const String tokenKey = 'access_token';

  late final Dio _dio;
  final Ref? ref;

  ApiService({this.ref}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _clearToken();
        }
        return handler.next(error);
      },
    ));
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, [dynamic data]) async {
    return await _dio.post(path, data: data);
  }

  Future<Response> put(String path, [dynamic data]) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> patch(String path, [dynamic data]) async {
    return await _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }

  Future<Response> upload(String path, FormData formData) async {
    return await _dio.post(path, data: formData);
  }

  Future<Response> uploadProfilePicture(XFile file) async {
    final fileName = file.path.split('/').last.split(r'\').last;
    MultipartFile multipartFile;
    if (kIsWeb) {
      multipartFile = MultipartFile.fromBytes(
        await file.readAsBytes(),
        filename: fileName,
      );
    } else {
      multipartFile = await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      );
    }
    final formData = FormData.fromMap({
      'profile_picture': multipartFile,
    });
    return await _dio.post('/users/profile-picture/', data: formData);
  }

  Future<Response> deleteProfilePicture() async {
    return await _dio.delete('/users/remove-profile-picture/');
  }
}
