class Music {
  String? musicId;
  String? name;
  String? singer;
  String? lyricId;
  int? type;
  String? musicUri;
  String? lyricUri;
  String? coverUri;

  static Music fromMap(dynamic item) {
    Music music = Music();
    music.musicId = item['musicId'];
    music.name = item['name'];
    music.singer = item['singer'];
    music.lyricId = item['lyricId'];
    music.type = item['type'];
    music.musicUri = item['musicUri'];
    music.lyricUri = item['lyricUri'];
    music.coverUri = item['coverUri'];
    return music;
  }

  Map<String, String> toMetaDataMap() {
    return {
      'title': name ?? '',
      'subTitle': singer ?? '',
      'mediaId': musicId ?? ''
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Music &&
          runtimeType == other.runtimeType &&
          musicId == other.musicId;

  @override
  int get hashCode => musicId.hashCode;
}

class MetaData {
  final Map<String, dynamic> _map = {
    'duration': 0,
    'title': '',
    'subTitle': '',
    'mediaId': '',
    'musicUri': '',
    'lyricUri': ''
  };

  int duration = 0;
  String title = '';
  String subTitle = '';
  String mediaId = '';
  String coverUri = '';
  String musicUri = '';
  String lyricUri = '';

  Map<String, dynamic> toMap() {
    _map['duration'] = duration;
    _map['title'] = title;
    _map['subTitle'] = subTitle;
    _map['mediaId'] = mediaId;
    _map['coverUri'] = coverUri;
    _map['musicUri'] = musicUri;
    _map['lyricUri'] = lyricUri;
    return _map;
  }
}

class PlaybackState {
  final Map<String, dynamic> _map = {
    'bufferedPosition': 0,
    'position': 0,
    'state': -1
  };
  int bufferedPosition = 0;
  int position = 0;
  int state = -1;

  Map<String, dynamic> toMap() {
    _map['bufferedPosition'] = bufferedPosition;
    _map['position'] = position;
    _map['state'] = state;
    return _map;
  }
}
