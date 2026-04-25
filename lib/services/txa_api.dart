import 'dart:io';
import 'package:dio/dio.dart';
import '../services/txa_settings.dart';
import '../utils/txa_logger.dart';

class TxaApi {
  static const String baseUrl = 'https://film.nrotxa.online';
  static const String apiPrefix = '/api/app';
  static const String apiKey = 'tphimx-mobile-2026-secure';
  static const String apiVersion = '4.0.1';
  static const String buildNumber = '401';

  // Community Links
  static const String facebookFanpage =
      'https://www.facebook.com/profile.php?id=61573302085316';
  static const String facebookGroup =
      'https://www.facebook.com/groups/1819522938713878';
  static const String telegramChannel = 'https://t.me/tphimx';
  static const String telegramGroup = 'https://t.me/+uptNAkShrJFjMjc1';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'X-TXC-Client': 'TPhimX-App',
        'X-TXC-Platform': Platform.isIOS ? 'iOS' : 'Android',
        'X-TXA-API-KEY': apiKey,
        'X-TXA-UDID': TxaSettings.udid,
        'User-Agent':
            'TPhimX-App/$apiVersion (${Platform.isIOS ? 'iPhone' : 'Android'})',
      },
    ),
  );

  TxaApi() {
    final token = TxaSettings.authToken;
    if (token.isNotEmpty) {
      setToken(token);
    }
  }

  // Endpoints
  static const String home = '$apiPrefix/home';
  static String movieDetail(String slug) => '$apiPrefix/movie/$slug';
  static const String search = '$apiPrefix/search';
  static String category(String slug) => '$apiPrefix/category/$slug';
  static String type(String type) => '$apiPrefix/type/$type';
  static const String schedule = '$apiPrefix/schedule';
  static const String filters = '$apiPrefix/filters';
  static const String watchHistory = '$apiPrefix/watch-history';
  static const String report = '$apiPrefix/report';
  static const String checkUpdate = '$apiPrefix/check-update';
  static const String notifications = '$apiPrefix/notifications';
  static const String readNotification = '$apiPrefix/notifications/read';
  static const String clientError = '$apiPrefix/client-error';
  static const String changelog = '$apiPrefix/changelog';
  static const String hotSearch = '$apiPrefix/hot-search';
  static const String searchClick = '$apiPrefix/search-click';
  static const String favorites = '$apiPrefix/favorites';
  static const String toggleFavoriteUrl = '$apiPrefix/favorites/toggle';
  static const String clearNotificationsUrl = '$apiPrefix/notifications/clear';
  static const String readAllNotificationsUrl =
      '$apiPrefix/notifications/read-all';
  static const String clearWatchHistoryUrl = '$apiPrefix/watch-history/clear';
  static const String updateWatchHistoryUrl = '$apiPrefix/watch-history/update';

  // Auth
  static const String authLogin = '/api/auth/login';
  static const String authRegister = '/api/auth/register';
  static const String authMe = '/api/auth/me';

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final startTime = DateTime.now();
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      TxaLogger.logApi(
        method: 'GET',
        path: path,
        statusCode: response.statusCode,
        response: response.data,
        duration: DateTime.now().difference(startTime),
      );
      return response;
    } on DioException catch (e) {
      TxaLogger.logApi(
        method: 'GET',
        path: path,
        statusCode: e.response?.statusCode,
        response: e.response?.data,
        duration: DateTime.now().difference(startTime),
      );
      rethrow;
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    final startTime = DateTime.now();
    try {
      final response = await _dio.post(path, data: data);
      TxaLogger.logApi(
        method: 'POST',
        path: path,
        statusCode: response.statusCode,
        body: data,
        response: response.data,
        duration: DateTime.now().difference(startTime),
      );
      return response;
    } on DioException catch (e) {
      TxaLogger.logApi(
        method: 'POST',
        path: path,
        statusCode: e.response?.statusCode,
        body: data,
        response: e.response?.data,
        duration: DateTime.now().difference(startTime),
      );
      rethrow;
    }
  }

  // ============ Implementation methods ============

  /// Lấy dữ liệu trang chủ (featured, latest, hot, anime, series, single, categories)
  Future<Map<String, dynamic>> getHome() async {
    final response = await get(home);
    return response.data;
  }

  /// Lấy chi tiết phim
  Future<Map<String, dynamic>> getMovie(String slug) async {
    final response = await get(movieDetail(slug));
    return response.data;
  }

  /// Lấy link tập phim
  Future<Map<String, dynamic>?> getEpisodeLink(String episodeId) async {
    try {
      final response = await get('$apiPrefix/episode/$episodeId/link');
      return response.data['data'];
    } catch (e) {
      TxaLogger.log('Get Episode Link Error: $e', isError: true);
      return null;
    }
  }

  /// Tìm kiếm phim
  Future<Map<String, dynamic>> searchMovies(
    String query, {
    int page = 1,
    String? categorySlug,
    String? region,
    String? year,
    String? movieType,
  }) async {
    final params = <String, dynamic>{'q': query, 'page': page};
    if (categorySlug != null) params['category'] = categorySlug;
    if (region != null) params['region'] = region;
    if (year != null) params['year'] = year;
    if (movieType != null) params['type'] = movieType;
    final response = await get(search, queryParameters: params);
    return response.data;
  }

  /// Lấy phim theo thể loại
  Future<Map<String, dynamic>> getCategory(String slug, {int page = 1}) async {
    final response = await get(category(slug), queryParameters: {'page': page});
    return response.data;
  }

  /// Lấy phim theo loại (series/single)
  Future<Map<String, dynamic>> getType(String movieType, {int page = 1}) async {
    final response = await get(
      type(movieType),
      queryParameters: {'page': page},
    );
    return response.data;
  }

  /// Lấy lịch chiếu
  Future<Map<String, dynamic>> getSchedule() async {
    final response = await get(schedule);
    return response.data;
  }

  /// Lấy bộ lọc (thể loại, quốc gia, năm)
  Future<Map<String, dynamic>> getFilters() async {
    final response = await get(filters);
    return response.data;
  }

  /// Lấy hot search (phim được tìm nhiều nhất)
  Future<Map<String, dynamic>> getHotSearch({int limit = 10}) async {
    final response = await get(hotSearch, queryParameters: {'limit': limit});
    return response.data;
  }

  /// Kiểm tra cập nhật
  Future<Map<String, dynamic>> getCheckUpdate() async {
    final response = await get(checkUpdate);
    return response.data;
  }

  /// Lấy lịch sử cập nhật
  Future<List<dynamic>> getChangelog() async {
    final response = await get(changelog);
    return response.data as List<dynamic>;
  }

  /// Track search click
  Future<Map<String, dynamic>> trackSearchClick(
    int movieId,
    String keyword,
  ) async {
    final response = await post(
      searchClick,
      data: {'movie_id': movieId, 'keyword': keyword, 'platform': 'app'},
    );
    return response.data;
  }

  // Auth Methods
  Future<Response> login(String login, String password) async {
    return await post(authLogin, data: {'login': login, 'password': password});
  }

  Future<Response> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required String confirmPw,
    required String gender,
  }) async {
    return await post(
      authRegister,
      data: {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
        'password_confirmation': confirmPw,
        'gender': gender,
        'device_name': Platform.isIOS ? 'iPhone' : 'Android',
        'agree': 1,
      },
    );
  }

  Future<Map<String, dynamic>> getAuthMe() async {
    final response = await get(authMe);
    return response.data;
  }

  Future<Map<String, dynamic>> verifyEmail(String token) async {
    final response = await post(
      '/api/auth/verify-email',
      data: {'token': token},
    );
    return response.data;
  }

  // Notification Methods
  Future<Map<String, dynamic>> getNotifications() async {
    final response = await get(notifications);
    return response.data;
  }

  Future<Map<String, dynamic>> markNotificationRead(String id) async {
    final response = await post(readNotification, data: {'id': id});
    return response.data;
  }

  Future<Map<String, dynamic>> clearNotifications() async {
    final response = await post(clearNotificationsUrl);
    return response.data;
  }

  Future<Map<String, dynamic>> markAllRead() async {
    final response = await post(readAllNotificationsUrl);
    return response.data;
  }

  Future<Map<String, dynamic>> getFavorites() async {
    final response = await get(favorites);
    return response.data;
  }

  Future<Map<String, dynamic>> toggleFavorite(int movieId) async {
    final response = await post(toggleFavoriteUrl, data: {'movie_id': movieId});
    return response.data;
  }

  Future<Map<String, dynamic>> getWatchHistory() async {
    final response = await get(watchHistory);
    return response.data;
  }

  Future<Map<String, dynamic>> clearWatchHistory() async {
    final response = await post(clearWatchHistoryUrl);
    return response.data;
  }

  Future<Map<String, dynamic>> updateWatchHistory({
    required int movieId,
    required int episodeId,
    required double currentTime,
    required double duration,
  }) async {
    final response = await post(
      updateWatchHistoryUrl,
      data: {
        'movie_id': movieId,
        'episode_id': episodeId,
        'current_time': currentTime,
        'duration': duration,
      },
    );
    return response.data;
  }

  /// Ghi log lỗi từ client về server
  Future<void> logError(
    String type,
    String message, {
    Map<String, dynamic>? extra,
  }) async {
    try {
      await post(
        clientError,
        data: {
          'type': type,
          'message': message,
          'extra': extra,
          'device_info': 'TPhimX-App-V4.0',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {
      // Ignore logger errors to avoid infinite loops
    }
  }
}
