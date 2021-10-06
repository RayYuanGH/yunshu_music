import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:yunshu_music/net/http_helper.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/provider/cache_model.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

/// 播放状态
class PlayStatusModel extends ChangeNotifier {
  static PlayStatusModel? _instance;

  static PlayStatusModel get() {
    _instance ??= PlayStatusModel();
    return _instance!;
  }

  final AudioPlayer _player;

  /// 播放进度，实时
  Duration _position = const Duration();

  /// 音频持续时间
  Duration _duration = const Duration();

  /// 缓冲时间
  Duration _bufferedPosition = const Duration();

  /// 当前播放进度
  Duration get position => _position;

  /// 当前音频时长
  Duration get duration => _duration;

  /// 缓冲时间
  Duration get bufferedPosition => _bufferedPosition;

  /// 播放器状态
  ProcessingState get processingState => _player.processingState;

  /// 现在正在播放吗？
  bool get isPlayNow =>
      _player.playing &&
      _player.processingState != ProcessingState.completed &&
      _player.processingState != ProcessingState.idle &&
      _player.processingState != ProcessingState.loading;

  PlayStatusModel() : _player = AudioPlayer(userAgent: 'YunShuMusic') {
    // 缓冲进度
    _player.bufferedPositionStream.listen((event) {
      _bufferedPosition = event;
      notifyListeners();
    });
    _player.durationStream.listen((event) {
      LogHelper.get().debug('音频持续时间 $event');
      _duration = event ?? const Duration();
    });
    _player.volumeStream.listen((event) {
      LogHelper.get().debug('音量 $event');
    });
    _player.speedStream.listen((event) {
      LogHelper.get().debug('速度 $event');
    });
    // 播放位置
    _player.positionStream.listen((event) {
      _position = event;
      notifyListeners();
    });
    _player.playingStream.listen((event) {
      LogHelper.get().debug('正在播放状态 $event');
      notifyListeners();
    });
    _player.playerStateStream.listen((event) {
      LogHelper.get().debug('播放状态 $event');
      notifyListeners();
    });
    _player.processingStateStream.listen((event) {
      LogHelper.get().debug('状态改变 $event');
      notifyListeners();
    });
    _player.currentIndexStream.listen((event) {
      LogHelper.get().debug('索引改变 $event');
      MusicDataModel.get().onIndexChange(event);
    });
    _player.loopModeStream.listen((event) {
      LogHelper.get().debug('loopModeStream $event');
    });
    _player.shuffleModeEnabledStream.listen((event) {
      LogHelper.get().debug('shuffleModeEnabledStream $event');
    });
  }

  @override
  void dispose() {
    LogHelper.get().debug('PlayStatusModel dispose');
    _player.dispose();
    super.dispose();
  }

  /// 手动更新播放进度
  Future<void> seek(Duration? position, {int? index}) async {
    _player.seek(position, index: index);
  }

  Future<void> seekToPrevious() async {
    if (MusicDataModel.get().playMode == 'loop') {
      int index = MusicDataModel.get().nowMusicIndex;
      if (index - 1 < 0) {
        index = MusicDataModel.get().musicList.length - 1;
      } else {
        index -= 1;
      }
      _player.seek(null, index: index);
      return;
    }
    await _player.seekToPrevious();
    if (!isPlayNow) {
      _player.play();
    }
  }

  Future<void> seekToNext() async {
    if (MusicDataModel.get().playMode == 'loop') {
      int index = MusicDataModel.get().nowMusicIndex;
      List<MusicDataContent> musicList = MusicDataModel.get().musicList;
      if (index + 1 >= musicList.length) {
        index = 0;
      } else {
        index += 1;
      }
      _player.seek(null, index: index);
      return;
    }
    await _player.seekToNext();
    if (!isPlayNow) {
      _player.play();
    }
  }

  Future<void> setPlayMode(String playMode) async {
    switch (playMode) {
      case 'sequence':
        _player.setLoopMode(LoopMode.all);
        break;
      case 'randomly':
        _player.setShuffleModeEnabled(true);
        break;
      case 'loop':
        _player.setLoopMode(LoopMode.one);
        break;
      default:
        _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  final ConcatenatingAudioSource _concatenatingAudioSource =
      ConcatenatingAudioSource(children: []);

  Future<void> clearAll() async {
    _concatenatingAudioSource.clear();
  }

  /// 设置音频源
  Future<void> setSource(List<MusicDataContent> musics, int initIndex) async {
    bool enableMusicCache = CacheModel.get().enableMusicCache;
    List<AudioSource> children = [];
    for (var music in musics) {
      String musicUrl = HttpHelper.get().getMusicUrl(music.musicId!);
      Uri coverUri = Uri.parse(HttpHelper.get().getCoverUrl(music.musicId!));
      MediaItem mediaItem = MediaItem(
        id: music.musicId!,
        artist: music.singer ?? '',
        title: music.name ?? '',
        artUri: coverUri,
      );
      AudioSource audioSource;
      if (enableMusicCache) {
        audioSource =
            LockCachingAudioSource(Uri.parse(musicUrl), tag: mediaItem);
      } else {
        audioSource = AudioSource.uri(
          Uri.parse(musicUrl),
          tag: mediaItem,
        );
      }
      children.add(audioSource);
    }
    _concatenatingAudioSource.addAll(children);
    try {
      _player.setAudioSource(_concatenatingAudioSource,
          initialIndex: initIndex);
    } on PlayerException catch (e) {
      Fluttertoast.showToast(msg: "播放失败", toastLength: Toast.LENGTH_LONG);
      LogHelper.get().error('设置音频源失败', e);
    } on PlayerInterruptedException catch (e) {
      // This call was interrupted since another audio source was loaded or the
      // player was stopped or disposed before this audio source could complete
      // loading.
      LogHelper.get().warn('设置音频源失败', e);
    } catch (e) {
      Fluttertoast.showToast(msg: "播放失败，未知错误", toastLength: Toast.LENGTH_LONG);
      LogHelper.get().error('设置音频源失败', e);
    }
  }

  /// 设置播放状态
  Future<void> setPlay(bool needPlay) async {
    needPlay ? _player.play() : _player.pause();
  }

  /// 停止播放
  Future<void> stopPlay() async {
    _player.stop();
  }
}
