import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:petdemo/authentication/login_step/login_phone_screen.dart';
import 'package:petdemo/common/const/address.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final ip = androidEmulatorIP;
  final dio = Dio();

  late final BuildContext? context;

  ApiService({
    this.context,
  });

  /* ===================== basic login& signin request ==================== */
  Future<Response?> postRequest(String toUrl, dynamic data) async {
    try {
      final Response<dynamic> response = await dio.post(
        ip + toUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
        data: data,
      );

      return response;
    } on DioException catch (e) {
      debugPrint(e.message);
      return null;
    }
  }

  Future<Response?> getRequest(String toUrl, dynamic data) async {
    try {
      final Response<dynamic> response = await dio.get(
        ip + toUrl,
        data: data,
      );
      return response;
    } on DioException catch (e) {
      debugPrint(e.message);
      return null;
    }
  }

  /* ===================== token request ==================== */

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access');
    return accessToken;
  }

  void saveToken(
      {required String accessToken, required String refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("access", accessToken);
    prefs.setString("refresh", refreshToken);
    print("accessToken : $accessToken");
    print("refreshToken $refreshToken");
  }

  Future<Dio> _authDio({required RequestOptions requestOpitions}) async {
    dio.interceptors.clear();
    final prefs = await SharedPreferences.getInstance();

    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      final accessToken = prefs.getString('accesss');

      // 모든 요청 헤더에 액세스 포함
      options.headers['Authorization'] = '$accessToken';
      options.headers['Content-Type'] = 'application/json';
      return handler.next(options);
    }, onError: (error, handler) async {
      // if 인증 에러 :  액세스 토큰 만료
      if (error.response?.statusCode == 402) {
        final refreshToken = prefs.getString('refresh');

        var refreshDio = Dio(); // 재발급용 디오 인스턴스

        refreshDio.interceptors.clear(); // 초기화

        refreshDio.interceptors.add(
          InterceptorsWrapper(
            onError: (error, handler) async {
              // if 인증 에러 :  재발급 토큰 만료 -> 이경우 둘다 만료
              if (error.response?.statusCode == 402) {
                // 토큰 지우기
                prefs.remove('accesss');
                prefs.remove('refresh');
                print("hihihihi this is for refreshing token");
                // . . .
                // 토큰이 만료됐다는 팝업 -> 로그인 페이지로 redirect 시켜야 함.
                if (context == null) {
                  print("redirect 주소가 없습니다.");
                } else {
                  Navigator.of(context!).pushAndRemoveUntil(MaterialPageRoute(
                    builder: (context) {
                      return LoginPhoneScreen();
                    },
                  ), (route) => false);
                }
                // . . .
              }
              return handler.next(error);
            },
          ),
        );

        // refresh 토큰으로 access 토큰 발급받기
        final refreshResponse = await refreshDio.post(
          '/refresh',
          options: Options(
            headers: {},
          ),
          data: {"refreshToken": refreshToken},
        );

        final newAccessToken =
            refreshResponse.headers['Authorization']![0]; // 새로운 액세스토큰 파싱.

        prefs.setString('accesss', newAccessToken); // 새로운 토큰 저장.

        // 액세스 토큰 만료로 인해 요청하지 못했던 대기 요청의 헤더 업데이트
        error.requestOptions.headers['Authorization'] = newAccessToken;

        // 대기 요청 복사
        final clonedRequest = await dio.request(error.requestOptions.path,
            options: Options(
                method: error.requestOptions.method,
                headers: error.requestOptions.headers),
            data: error.requestOptions.data,
            queryParameters: error.requestOptions.queryParameters);

        return handler.resolve(clonedRequest); // 복사된 요청으로 재요청
      }

      return handler.next(error);
    }));

    return dio;
  }

  Future<Response?> getRequestWithToken(
      {required String toUrl, required dynamic data}) async {
    try {
      final Response<dynamic> response = await dio.get(
        ip + toUrl,
        data: data,
      );
      return response;
    } on DioException catch (e) {
      debugPrint(e.message);
      return null;
    }
  }

  Future<Response?> postRequestWithToken({
    required String toUrl,
    required dynamic data,
    String? contentType,
  }) async {
    try {
      final option = Options(headers: {
        'Content-Type': contentType,
        'Authorization': await readToken(),
      }, method: 'POST');
      final dio = Dio();
      final Response<dynamic> response = await dio.post(
        ip + toUrl,
        options: option,
        data: data,
      );
      return response;
    } on DioException catch (e) {
      debugPrint(e.message);
      return null;
    }
  }

/* ============================ error Check =========================== */
  // Method to check response message errors
  Future<dynamic> reponseMessageCheck(Response? response) async {
    if (response == null) {
      return null;
    }
    if (response.statusCode == 200) {
      print(response.data);
      return response.data;
    } else {
      print('=====>>>>> Request failed with status: ${response.statusCode}');
    }
    return null;
  }
/* ============================ error Check =========================== */
}
