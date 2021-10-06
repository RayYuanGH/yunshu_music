import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_rest_template/response_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/component/lyric/lyric_util.dart';
import 'package:yunshu_music/net/http_helper.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/net/model/music_meta_info_entity.dart';
import 'package:yunshu_music/provider/cache_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

/// 音乐数据模型
class MusicDataModel extends ChangeNotifier {
  static const String _playModeKey = "PLAY_MODE";
  static const String _nowPlayMusicIdKey = "NOW_PLAY_MUSIC_ID";

  static MusicDataModel? _instance;

  static MusicDataModel get() {
    _instance ??= MusicDataModel();
    return _instance!;
  }

  bool _isInit = false;

  late SharedPreferences _sharedPreferences;

  /// 所有音乐列表
  List<MusicDataContent> _musicList = [];

  /// 正在播放的音乐在_musicList里的索引
  int _nowPlayMusicIndex = 0;

  /// 当前歌曲的歌词信息
  List<Lyric>? _lyricList;

  /// 音乐封面
  Uint8List? _coverBase64;

  /// 播放模式
  String _playMode = 'sequence';

  /// 现在正在播放的音乐ID
  String? _nowPlayMusicId;

  /// 获取音乐列表
  List<MusicDataContent> get musicList => _musicList;

  /// 获取当前歌词信息
  List<Lyric>? get lyricList => _lyricList;

  /// 获取音乐封面
  Uint8List? get coverBase64 => _coverBase64;

  /// 获取正在播放的音乐在_musicList里的索引
  int get nowMusicIndex => _nowPlayMusicIndex;

  /// 获取播放模式
  String get playMode => _playMode;

  Future<void> init(SharedPreferences sharedPreferences) async {
    _sharedPreferences = sharedPreferences;
    _playMode = sharedPreferences.getString(_playModeKey) ?? 'sequence';
    _nowPlayMusicId = sharedPreferences.getString(_nowPlayMusicIdKey);
  }

  Future<String?> refreshMusicList({bool needInit = false}) async {
    if (needInit) {
      List<MusicDataContent> list = await CacheModel.get().getMusicList();
      if (list.isNotEmpty) {
        _musicList = list;
        _initPlay();
        notifyListeners();
        return null;
      }
    }
    ResponseEntity<MusicEntity> responseEntity =
        await HttpHelper.get().getMusic();
    if (responseEntity.body == null) {
      return '服务器<${responseEntity.status.value}> BODY NULL';
    }
    if (responseEntity.body!.code != 200 || responseEntity.body!.data == null) {
      return responseEntity.body!.msg ?? '服务器错误';
    }
    if (responseEntity.body!.data!.content == null) {
      return null;
    }
    _musicList = responseEntity.body!.data!.content!;
    CacheModel.get().cacheMusicList(_musicList);
    if (needInit) {
      _initPlay();
    }
    notifyListeners();
  }

  Future<void> _initPlay() async {
    if (_isInit) {
      return;
    }
    _isInit = false;
    if (_nowPlayMusicId == null) {
      _nowPlayMusicId ??= _musicList[0].musicId;
      _nowPlayMusicIndex = 0;
    } else {
      int index = _musicList
          .indexWhere((element) => element.musicId == _nowPlayMusicId);
      _nowPlayMusicIndex = index;
      if (_nowPlayMusicIndex == -1) {
        _nowPlayMusicId ??= _musicList[0].musicId;
        _nowPlayMusicIndex = 0;
      }
    }
    PlayStatusModel.get().setSource(_musicList, _nowPlayMusicIndex);
    PlayStatusModel.get().setPlayMode(_playMode);
  }

  Future<void> onIndexChange(int? index) async {
    if (null == index) {
      return;
    }
    _nowPlayMusicIndex = index;
    MusicDataContent music = _musicList[_nowPlayMusicIndex];
    _nowPlayMusicId = music.musicId;
    _sharedPreferences.setString(_nowPlayMusicIdKey, _nowPlayMusicId!);
    if (null != music.musicId) {
      await _initCover(_nowPlayMusicId!);
    }
    if (null != music.lyricId) {
      await _initLyric(music.lyricId!);
    }
    notifyListeners();
  }

  Future<void> nextPlayMode() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    switch (_playMode) {
      case 'sequence':
        _playMode = 'randomly';
        sharedPreferences.setString(_playModeKey, _playMode);
        PlayStatusModel.get().setPlayMode(_playMode);
        notifyListeners();
        break;
      case 'randomly':
        _playMode = 'loop';
        sharedPreferences.setString(_playModeKey, _playMode);
        PlayStatusModel.get().setPlayMode(_playMode);
        notifyListeners();
        break;
      case 'loop':
        _playMode = 'sequence';
        sharedPreferences.setString(_playModeKey, _playMode);
        PlayStatusModel.get().setPlayMode(_playMode);
        notifyListeners();
        break;
      default:
        _playMode = 'sequence';
        sharedPreferences.setString(_playModeKey, _playMode);
        PlayStatusModel.get().setPlayMode(_playMode);
        notifyListeners();
        break;
    }
  }

  /// 搜索音乐和歌手
  List<MusicDataContent> search(String keyword) {
    if (keyword.trim() == '') {
      return [];
    }
    String lowerCaseKeyword = keyword.toLowerCase();
    List<MusicDataContent> searchResultList = _musicList.where((musicItem) {
      bool containsName = false;
      bool containsSinger = false;
      if (musicItem.name != null) {
        containsName = musicItem.name!.toLowerCase().contains(lowerCaseKeyword);
      }
      if (musicItem.singer != null) {
        containsSinger =
            musicItem.singer!.toLowerCase().contains(lowerCaseKeyword);
      }
      return containsName || containsSinger;
    }).toList();
    return searchResultList;
  }

  /// 获取现在正在播放的音乐信息
  MusicDataContent? getNowPlayMusic() {
    if (_musicList.isEmpty) {
      return null;
    } else {
      return _musicList[_nowPlayMusicIndex];
    }
  }

  /// 设置现在正在播放的音乐信息
  Future<void> setNowPlayMusicUseMusicId(String? musicId) async {
    if (null == musicId) {
      return;
    }
    int index = _musicList.indexWhere((element) => musicId == element.musicId);
    if (-1 == index) {
      return;
    }
    setNowPlayMusic(index);
  }

  /// 设置现在正在播放的音乐信息
  Future<void> setNowPlayMusic(int index) async {
    if (index > _musicList.length - 1) {
      return;
    }
    if (_nowPlayMusicIndex == index) {
      if (!PlayStatusModel.get().isPlayNow) {
        PlayStatusModel.get().setPlay(true);
      }
      return;
    }
    await PlayStatusModel.get().setPlay(false);
    await PlayStatusModel.get().stopPlay();
    _nowPlayMusicIndex = index;
    MusicDataContent music = _musicList[_nowPlayMusicIndex];
    _nowPlayMusicId = music.musicId;
    _sharedPreferences.setString(_nowPlayMusicIdKey, _nowPlayMusicId!);
    PlayStatusModel.get().seek(null, index: index);
    PlayStatusModel.get().setPlay(true);
    notifyListeners();
  }

  Future<void> _initLyric(String lyricId) async {
    String? lyric = await CacheModel.get().getLyric(lyricId);
    if (lyric == null) {
      lyric = await HttpHelper.get().getLyric(lyricId);
      CacheModel.get().cacheLyric(lyricId, lyric);
    }
    List<Lyric>? list = LyricUtil.formatLyric(lyric);
    _lyricList = list;
    notifyListeners();
  }

  Future<void> _initCover(String musicId) async {
    File coverFromCache = await CacheModel.get().getCover(musicId);
    if (coverFromCache.existsSync()) {
      _coverBase64 = await coverFromCache.readAsBytes();
      notifyListeners();
      return;
    }
    ResponseEntity<MusicMetaInfoEntity> responseEntity =
        await HttpHelper.get().getMetaInfo(musicId);
    if (responseEntity.status.value != 200) {
      File defaultCoverFile = await CacheModel.get().getDefaultCover();
      _coverBase64 = await defaultCoverFile.readAsBytes();
      notifyListeners();
      return;
    }

    if (responseEntity.body == null || responseEntity.body!.data == null) {
      File defaultCoverFile = await CacheModel.get().getDefaultCover();
      _coverBase64 = await defaultCoverFile.readAsBytes();
      notifyListeners();
      return;
    }

    if (responseEntity.body!.data!.coverPictures == null) {
      File defaultCoverFile = await CacheModel.get().getDefaultCover();
      _coverBase64 = await defaultCoverFile.readAsBytes();
      notifyListeners();
      return;
    }

    if (responseEntity.body!.data!.coverPictures!.isEmpty) {
      File defaultCoverFile = await CacheModel.get().getDefaultCover();
      _coverBase64 = await defaultCoverFile.readAsBytes();
      notifyListeners();
      return;
    }

    MusicMetaInfoDataCoverPictures pictures =
        responseEntity.body!.data!.coverPictures![0];
    File? coverFile = await CacheModel.get()
        .cacheCover(musicId, pictures.base64, pictures.mimeType);
    File defaultCoverFile = await CacheModel.get().getDefaultCover();
    _coverBase64 = coverFile == null
        ? await defaultCoverFile.readAsBytes()
        : await coverFile.readAsBytes();
    notifyListeners();
  }
}
