package top.itning.yunshu_music.service;

import android.support.v4.media.MediaBrowserCompat;

import com.tencent.mmkv.MMKV;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * @author itning
 * @since 2021/10/12 14:52
 */
public class MusicPlayDataService {
    private static final String NOW_PLAY_MEDIA_ID_KEY = "NOW_PLAY_MEDIA_ID_KEY";
    private static final String PLAY_MODE_KEY = "PLAY_MODE";
    private static final String PLAY_LIST_KEY = "PLAY_LIST";
    private final List<MediaBrowserCompat.MediaItem> MUSIC_LIST = new ArrayList<>();
    private final List<MediaBrowserCompat.MediaItem> PLAY_LIST = new ArrayList<>();
    private final Set<MediaBrowserCompat.MediaItem> RANDOM_SET = new HashSet<>();
    private int nowPlayIndex;
    private MediaBrowserCompat.MediaItem nowPlayMusic;
    private MusicPlayMode playMode;
    private final MMKV kv;

    public MusicPlayDataService() {
        this.nowPlayIndex = -1;
        kv = MMKV.defaultMMKV();
        try {
            String mode = kv.decodeString(PLAY_MODE_KEY, MusicPlayMode.SEQUENCE.name());
            this.playMode = MusicPlayMode.valueOf(mode);
        } catch (Exception e) {
            kv.encode(PLAY_MODE_KEY, MusicPlayMode.SEQUENCE.name());
            this.playMode = MusicPlayMode.SEQUENCE;
        }
    }

    public int getNowPlayIndex() {
        return nowPlayIndex;
    }

    public MediaBrowserCompat.MediaItem getNowPlayMusic() {
        return nowPlayMusic;
    }

    public MusicPlayMode getPlayMode() {
        return playMode;
    }

    public List<MediaBrowserCompat.MediaItem> getPlayList() {
        return PLAY_LIST;
    }

    public void delPlayListByMediaId(String mediaId) {
        PLAY_LIST.removeIf(it -> mediaId.equals(it.getMediaId()));
        String playListString = PLAY_LIST.stream().map(MediaBrowserCompat.MediaItem::getMediaId).collect(Collectors.joining("@"));
        kv.encode(PLAY_LIST_KEY, playListString);
    }

    public void clearPlayList() {
        PLAY_LIST.clear();
        nowPlayIndex = -1;
        kv.removeValueForKey(PLAY_LIST_KEY);
    }

    public void setPlayMode(MusicPlayMode playMode) {
        this.playMode = playMode;
        kv.encode(PLAY_MODE_KEY, playMode.name());
    }

    public void addMusic(List<MediaBrowserCompat.MediaItem> musicList) {
        MUSIC_LIST.addAll(musicList);
        String playListString = kv.decodeString(PLAY_LIST_KEY, "");

        List<String> playListMusicIdList = Arrays.asList(playListString.split("@"));
        List<MediaBrowserCompat.MediaItem> playList = new ArrayList<>(playListMusicIdList.size());
        for (String mediaId : playListMusicIdList) {
            MUSIC_LIST.stream().filter(it -> mediaId.equals(it.getMediaId())).findFirst().ifPresent(playList::add);
        }
        PLAY_LIST.addAll(playList);

        String nowPlayMediaId = kv.decodeString(NOW_PLAY_MEDIA_ID_KEY);
        if (null != nowPlayMediaId) {
            for (int i = 0; i < PLAY_LIST.size(); i++) {
                if (nowPlayMediaId.equals(PLAY_LIST.get(i).getMediaId())) {
                    nowPlayIndex = i;
                    nowPlayMusic = PLAY_LIST.get(i);
                    break;
                }
            }
        }
        if (-1 == nowPlayIndex) {
            this.next(false);
        }
    }

    public void removeMusic(MediaBrowserCompat.MediaItem music) {
        MUSIC_LIST.remove(music);
    }

    public void playFromMediaId(String mediaId) {
        nowPlayIndex = -1;
        nowPlayMusic = null;
        for (int i = 0; i < MUSIC_LIST.size(); i++) {
            MediaBrowserCompat.MediaItem item = MUSIC_LIST.get(i);
            if (mediaId.equals(item.getMediaId())) {
                nowPlayMusic = item;
                break;
            }
        }
        if (null == nowPlayMusic) {
            return;
        }
        int playListIndex = PLAY_LIST.indexOf(nowPlayMusic);
        if (-1 == playListIndex) {
            PLAY_LIST.add(nowPlayMusic);
            nowPlayIndex = PLAY_LIST.size() - 1;
        } else {
            nowPlayIndex = playListIndex;
        }
        String playListString = PLAY_LIST.stream().map(MediaBrowserCompat.MediaItem::getMediaId).collect(Collectors.joining("@"));
        kv.encode(PLAY_LIST_KEY, playListString);
        kv.encode(NOW_PLAY_MEDIA_ID_KEY, nowPlayMusic.getMediaId());
    }

    public void previous(boolean userTrigger) {
        if (nowPlayIndex - 1 < 0) {
            // 需要新增
            switch (playMode) {
                case RANDOMLY:
                    int randomMusicListIndex = getRandom();
                    nowPlayMusic = MUSIC_LIST.get(randomMusicListIndex);
                    PLAY_LIST.remove(nowPlayMusic);
                    PLAY_LIST.add(0, nowPlayMusic);
                    nowPlayIndex = 0;
                    break;
                case SEQUENCE:
                    int sequenceMusicListIndex = toSequencePrevious();
                    nowPlayMusic = MUSIC_LIST.get(sequenceMusicListIndex);
                    PLAY_LIST.remove(nowPlayMusic);
                    PLAY_LIST.add(0, nowPlayMusic);
                    nowPlayIndex = 0;
                    break;
                case LOOP:
                    if (userTrigger) {
                        int loopMusicListIndex = toSequencePrevious();
                        nowPlayMusic = MUSIC_LIST.get(loopMusicListIndex);
                        PLAY_LIST.remove(nowPlayMusic);
                        PLAY_LIST.add(0, nowPlayMusic);
                        nowPlayIndex = 0;
                    }
                    break;
            }
        } else if (userTrigger || playMode != MusicPlayMode.LOOP) {
            nowPlayIndex--;
            nowPlayMusic = PLAY_LIST.get(nowPlayIndex);
        }
        String playListString = PLAY_LIST.stream().map(MediaBrowserCompat.MediaItem::getMediaId).collect(Collectors.joining("@"));
        kv.encode(PLAY_LIST_KEY, playListString);
        kv.encode(NOW_PLAY_MEDIA_ID_KEY, nowPlayMusic.getMediaId());
    }

    public void next(boolean userTrigger) {
        if (nowPlayIndex + 1 >= PLAY_LIST.size()) {
            // 需要新增
            switch (playMode) {
                case RANDOMLY:
                    int randomMusicListIndex = getRandom();
                    nowPlayMusic = MUSIC_LIST.get(randomMusicListIndex);
                    PLAY_LIST.remove(nowPlayMusic);
                    PLAY_LIST.add(nowPlayMusic);
                    nowPlayIndex++;
                    break;
                case SEQUENCE:
                    int sequenceMusicListIndex = toSequenceNext();
                    nowPlayMusic = MUSIC_LIST.get(sequenceMusicListIndex);
                    PLAY_LIST.remove(nowPlayMusic);
                    PLAY_LIST.add(nowPlayMusic);
                    nowPlayIndex++;
                    break;
                case LOOP:
                    if (userTrigger) {
                        int loopMusicListIndex = toSequenceNext();
                        nowPlayMusic = MUSIC_LIST.get(loopMusicListIndex);
                        PLAY_LIST.remove(nowPlayMusic);
                        PLAY_LIST.add(nowPlayMusic);
                        nowPlayIndex++;
                    }
                    break;
            }
        } else if (userTrigger || playMode != MusicPlayMode.LOOP) {
            nowPlayIndex++;
            nowPlayMusic = PLAY_LIST.get(nowPlayIndex);
        }
        String playListString = PLAY_LIST.stream().map(MediaBrowserCompat.MediaItem::getMediaId).collect(Collectors.joining("@"));
        kv.encode(PLAY_LIST_KEY, playListString);
        kv.encode(NOW_PLAY_MEDIA_ID_KEY, nowPlayMusic.getMediaId());
    }

    /**
     * 随机获取一首
     *
     * @return 在音乐列表中的索引
     */
    private int getRandom() {
        List<MediaBrowserCompat.MediaItem> canPlayList = MUSIC_LIST.stream()
                .filter(item -> !RANDOM_SET.contains(item))
                .filter(item -> !PLAY_LIST.contains(item))
                .collect(Collectors.toList());
        if (canPlayList.isEmpty()) {
            RANDOM_SET.clear();
            canPlayList = MUSIC_LIST;
        }
        Random random = new Random();
        int canPlayListIndex = random.nextInt(canPlayList.size());
        MediaBrowserCompat.MediaItem mediaItem = canPlayList.get(canPlayListIndex);
        RANDOM_SET.add(mediaItem);
        return MUSIC_LIST.indexOf(mediaItem);
    }

    /**
     * 顺序下一曲
     *
     * @return 在音乐列表中的索引
     */
    private int toSequenceNext() {
        if (nowPlayIndex == -1) {
            return 0;
        }
        MediaBrowserCompat.MediaItem mediaItem = PLAY_LIST.get(nowPlayIndex);
        int musicListIndex = MUSIC_LIST.indexOf(mediaItem);
        if (musicListIndex + 1 >= MUSIC_LIST.size()) {
            return 0;
        } else {
            return musicListIndex + 1;
        }
    }

    /**
     * 顺序上一曲
     *
     * @return 在音乐列表中的索引
     */
    private int toSequencePrevious() {
        if (nowPlayIndex == -1) {
            return MUSIC_LIST.size() - 1;
        }
        MediaBrowserCompat.MediaItem mediaItem = PLAY_LIST.get(nowPlayIndex);
        int musicListIndex = MUSIC_LIST.indexOf(mediaItem);
        if (musicListIndex - 1 < 0) {
            return MUSIC_LIST.size() - 1;
        } else {
            return musicListIndex - 1;
        }
    }
}
