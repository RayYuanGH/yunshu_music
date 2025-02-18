import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/component/image_fade.dart';
import 'package:yunshu_music/page/music_play/component/cover_page.dart';
import 'package:yunshu_music/page/music_play/component/lyric_page.dart';
import 'package:yunshu_music/page/music_play/component/player_page_bottom_navigation_bar.dart';
import 'package:yunshu_music/page/music_play/component/title_music_info.dart';
import 'package:yunshu_music/provider/music_data_model.dart';

/// 音乐播放页面
class MusicPlayPage extends StatelessWidget {
  const MusicPlayPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.modulate),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: const BackgroundPicture(),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            centerTitle: true,
            title: const TitleMusicInfo(),
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: PageView.builder(
            scrollBehavior:
                ScrollConfiguration.of(context).copyWith(dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
            }),
            itemCount: 2,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return const CoverPage();
              } else {
                return const LyricPage();
              }
            },
            onPageChanged: (index) {
              if (!kIsWeb && Platform.isAndroid) {
                if (index == 0) {
                  FlutterWindowManager.clearFlags(
                      FlutterWindowManager.FLAG_KEEP_SCREEN_ON);
                } else {
                  FlutterWindowManager.addFlags(
                      FlutterWindowManager.FLAG_KEEP_SCREEN_ON);
                }
              }
            },
          ),
          bottomNavigationBar: const PlayerPageBottomNavigationBar(),
        )
      ],
    );
  }
}

class BackgroundPicture extends StatelessWidget {
  const BackgroundPicture({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Uint8List? coverBase64 = context
        .select<MusicDataModel, Uint8List?>((value) => value.coverBase64);
    return ImageFade(
      excludeFromSemantics: true,
      fit: BoxFit.cover,
      image: coverBase64 == null
          ? Image.asset('asserts/images/default_cover.jpg').image
          : Image.memory(coverBase64).image,
    );
  }
}
