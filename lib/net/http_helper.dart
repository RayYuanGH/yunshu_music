import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_rest_template/flutter_rest_template.dart';
import 'package:flutter_rest_template/impl/dio_client_http_request_factory.dart';
import 'package:flutter_rest_template/response_entity.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:tuple/tuple.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/net/model/music_meta_info_entity.dart';
import 'package:yunshu_music/util/common_utils.dart';

class HttpHelper {
  static HttpHelper? _instance;

  static HttpHelper get() {
    _instance ??= HttpHelper._();
    return _instance!;
  }

  late final RestTemplate _restTemplate;

  late final Dio _dio;

  final String baseUrl = "https://music.itning.top";

  HttpHelper._() {
    _dio = Dio();
    _restTemplate = RestTemplate(DioClientHttpRequestFactory(_dio));
  }

  CancelToken? _cancelToken;
  String? _lastUrl;

  Future<File?> download(String url, String savePath) async {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      LogHelper.get().info('开始取消下载 $_lastUrl');
      _cancelToken!.cancel();
    }
    _lastUrl = url;
    _cancelToken = CancelToken();
    LogHelper.get().debug('开始下载 $url $savePath');
    try {
      int lastDownload = 0;
      Response<List<int>> response = await _dio.get(
        url,
        cancelToken: _cancelToken,
        onReceiveProgress: (int received, int total) {
          if (total != -1) {
            if (received - lastDownload > 2097152) {
              lastDownload = received;
              LogHelper.get().debug(
                  "下载进度: $url $received/$total ${(received / total * 100).toStringAsFixed(0)}%");
            }
          }
        },
        options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) {
              if (status == 200) {
                return true;
              } else {
                LogHelper.get().error('下载文件失败,服务器响应码非200 $status');
                return false;
              }
            }),
      );
      if (response.data == null) {
        LogHelper.get().error('下载文件失败,response.data == null');
        return null;
      }
      File file = File(savePath);
      return await file.writeAsBytes(response.data!);
    } catch (e) {
      LogHelper.get().error('下载文件失败 $url $savePath', e);
    } finally {
      LogHelper.get().debug('下载结束 $url $savePath');
      _cancelToken = null;
      _lastUrl = null;
    }
  }

  Future<ResponseEntity<MusicEntity>> getMusic() async {
    ResponseEntity<Map<String, dynamic>> responseEntity =
        await _restTemplate.getForMapEntry("$baseUrl/music?size=5000");
    Map<String, dynamic>? body = responseEntity.body;
    if (null != body) {
      MusicEntity musicEntity = MusicEntity().fromJson(body);
      return ResponseEntity(responseEntity.status,
          body: musicEntity, headers: responseEntity.headers);
    } else {
      return ResponseEntity(responseEntity.status,
          headers: responseEntity.headers);
    }
  }

  Future<ResponseEntity<MusicMetaInfoEntity>> getMetaInfo(
      String musicId) async {
    ResponseEntity<Map<String, dynamic>> responseEntity = await _restTemplate
        .getForMapEntry("$baseUrl/music/metaInfo?id=$musicId");
    Map<String, dynamic>? body = responseEntity.body;
    if (null != body) {
      MusicMetaInfoEntity musicEntity = MusicMetaInfoEntity().fromJson(body);
      return ResponseEntity(responseEntity.status,
          body: musicEntity, headers: responseEntity.headers);
    } else {
      return ResponseEntity(responseEntity.status,
          headers: responseEntity.headers);
    }
  }

  Future<String?> getLyric(String lyricId) async {
    LogHelper.get().info('获取歌词：$baseUrl/file/lyric?id=$lyricId');
    try {
      Response<String> response =
          await _dio.get<String>('$baseUrl/file/lyric?id=$lyricId');
      return response.data;
    } on DioError catch (e) {
      Fluttertoast.showToast(msg: '获取歌词网络异常');
      LogHelper.get().warn('获取歌词网络异常', e);
    } catch (e) {
      Fluttertoast.showToast(msg: '获取歌词失败');
      LogHelper.get().error('获取歌词失败', e);
    }
    return null;
  }

  Future<Tuple2<String?, List<int>?>> getCover(String musicId) async {
    LogHelper.get().info('获取歌词：$baseUrl/file/cover?id=$musicId');
    try {
      Response<List<int>> response = await _dio.get<List<int>>(
          '$baseUrl/file/cover?id=$musicId',
          options: Options(responseType: ResponseType.bytes));
      List<String>? contentTypes = response.headers[Headers.contentTypeHeader];
      String? contentType;
      if (contentTypes != null && contentTypes.isNotEmpty) {
        contentType = contentTypes[0];
      }
      return Tuple2(contentType, response.data);
    } on DioError catch (e) {
      Fluttertoast.showToast(msg: '获取封面网络异常');
      LogHelper.get().warn('获取封面网络异常', e);
    } catch (e) {
      Fluttertoast.showToast(msg: '获取封面失败');
      LogHelper.get().error('获取封面失败', e);
    }
    return const Tuple2(null, null);
  }

  String getMusicUrl(String musicId) {
    return "$baseUrl/file?id=$musicId";
  }
}
