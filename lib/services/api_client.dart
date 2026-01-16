import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../utils/api_config.dart';

class ApiClient {
  late final Dio _dio;
  late final Dio _refreshDio; // Separate Dio instance for refresh calls to avoid interceptor loop
  bool _isRefreshing = false; // Flag to prevent concurrent refresh attempts

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );
    
    // Create a separate Dio instance for refresh calls without interceptors
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );
    
    // Add logging interceptor for debugging (remove in production)
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        requestHeader: true,
        responseHeader: false,
      ));
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add access token to request headers
          final storage = StorageService.instance;
          final token = await storage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 Unauthorized - try to refresh token
          if (error.response?.statusCode == 401) {
            // Don't try to refresh if the failed request is already a refresh request
            // This prevents infinite loops when refresh token is expired
            final requestPath = error.requestOptions.path;
            if (requestPath.contains('/api/v1/auth/refresh')) {
              // Refresh token is expired, clear tokens and reject
              final storage = StorageService.instance;
              await storage.clearAll();
              return handler.reject(error);
            }
            
            // Prevent concurrent refresh attempts
            if (_isRefreshing) {
              // If already refreshing, wait a bit and reject
              return handler.reject(error);
            }
            
            final storage = StorageService.instance;
            final refreshToken = await storage.getRefreshToken();
            if (refreshToken != null) {
              _isRefreshing = true;
              try {
                // Try to refresh the access token
                final newToken = await _refreshAccessToken(refreshToken);
                if (newToken != null) {
                  await storage.saveAccessToken(newToken);
                  
                  // Retry the original request with new token
                  final opts = error.requestOptions;
                  opts.headers['Authorization'] = 'Bearer $newToken';
                  
                  final response = await _dio.request(
                    opts.path,
                    options: Options(
                      method: opts.method,
                      headers: opts.headers,
                    ),
                    data: opts.data,
                    queryParameters: opts.queryParameters,
                  );
                  
                  _isRefreshing = false;
                  return handler.resolve(response);
                } else {
                  // Refresh failed, clear tokens and logout
                  await storage.clearAll();
                  _isRefreshing = false;
                  return handler.reject(error);
                }
              } catch (e) {
                // Refresh failed, clear tokens and logout
                await storage.clearAll();
                _isRefreshing = false;
                return handler.reject(error);
              }
            } else {
              // No refresh token available, clear storage
              final storage = StorageService.instance;
              await storage.clearAll();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<String?> _refreshAccessToken(String refreshToken) async {
    try {
      // Use separate Dio instance to avoid interceptor loop
      final response = await _refreshDio.post(
        '/api/v1/auth/refresh',
        options: Options(
          headers: {
            'Authorization': 'Bearer $refreshToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return data['data']['access_token'] as String?;
        }
      }
    } catch (e) {
      // Refresh failed
      return null;
    }
    return null;
  }

  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // Get the underlying Dio instance if needed
  Dio get dio => _dio;
}
