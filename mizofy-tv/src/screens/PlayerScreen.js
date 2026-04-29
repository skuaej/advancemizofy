import React, { useRef, useState, useCallback, useEffect } from 'react';
import { View, Text, StyleSheet, Dimensions, TouchableOpacity, PanResponder, StatusBar as RNStatusBar, AppState } from 'react-native';
import { Video, ResizeMode, Audio } from 'expo-av';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useRoute, useFocusEffect } from '@react-navigation/native';
import * as ScreenOrientation from 'expo-screen-orientation';
import * as Brightness from 'expo-brightness';
import { WebView } from 'react-native-webview';
import * as IntentLauncher from 'expo-intent-launcher';
import UnityAdBanner from '../components/UnityAdBanner';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

export default function PlayerScreen() {
  const route = useRoute();
  const navigation = useNavigation();
  const video = useRef(null);
  const [status, setStatus] = useState({});
  const [volume, setVolume] = useState(1.0);
  const [brightness, setBrightnessVal] = useState(0.5);
  const [showVolumeBar, setShowVolumeBar] = useState(false);
  const [showBrightnessBar, setShowBrightnessBar] = useState(false);
  const [isPlaying, setIsPlaying] = useState(true);
  const [controlsVisible, setControlsVisible] = useState(true);
  const [resizeMode, setResizeMode] = useState(ResizeMode.CONTAIN);
  const [useNative, setUseNative] = useState(false);
  const [playerType, setPlayerType] = useState('native'); // native or web
  const [isLocked, setIsLocked] = useState(false);
  const [playbackSpeed, setPlaybackSpeed] = useState(1.0);
  const [lastTap, setLastTap] = useState(null);
  
  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onPanResponderMove: (evt, gestureState) => {
        if (isLocked) return;
        const { dx, dy, moveX } = gestureState;
        if (Math.abs(dy) > 10) {
          if (moveX > SCREEN_WIDTH / 2) {
            adjustVolume(-dy / 500); // Swipe up to increase
          } else {
            adjustBrightness(-dy / 500);
          }
          showControls();
        }
      },
      onPanResponderRelease: () => {
        // Just hide bars after a delay
      },
    })
  ).current;
  const timerRef = useRef(null);
  const { channel } = route.params;
  const isPlayingRef = useRef(isPlaying);
  useEffect(() => { isPlayingRef.current = isPlaying; }, [isPlaying]);

  useFocusEffect(
    useCallback(() => {
      Audio.setIsEnabledAsync(true);
      Brightness.getBrightnessAsync().then(b => setBrightnessVal(b)).catch(() => {});
      
      Audio.setAudioModeAsync({
        allowsRecordingIOS: false,
        staysActiveInBackground: true,
        interruptionModeIOS: 1, 
        playsInSilentModeIOS: true,
        shouldDuckAndroid: true,
        interruptionModeAndroid: 2, 
        playThroughEarpieceAndroid: false,
      });

      const subscription = AppState.addEventListener('change', nextAppState => {
        if (nextAppState === 'background' || nextAppState === 'inactive') {
          if (video.current && isPlayingRef.current) {
             video.current.playAsync();
          }
        }
      });

      startTimer();

      return () => {
        subscription.remove();
        if (timerRef.current) clearTimeout(timerRef.current);
        ScreenOrientation.lockAsync(ScreenOrientation.OrientationLock.PORTRAIT);
      };
    }, [])
  );

  const startTimer = () => {
    if (timerRef.current) clearTimeout(timerRef.current);
    timerRef.current = setTimeout(() => {
      setControlsVisible(false);
    }, 2000);
  };

  const showControls = () => {
    setControlsVisible(true);
    startTimer();
  };

  // Volume controls
  const adjustVolume = async (delta) => {
    const newVol = Math.min(1.0, Math.max(0, volume + delta));
    setVolume(newVol);
    if (video.current) {
      await video.current.setVolumeAsync(newVol);
    }
    setShowVolumeBar(true);
    setTimeout(() => setShowVolumeBar(false), 1500);
  };

  // Brightness controls
  const adjustBrightness = async (delta) => {
    const newBright = Math.min(1.0, Math.max(0.05, brightness + delta));
    setBrightnessVal(newBright);
    try {
      await Brightness.setBrightnessAsync(newBright);
    } catch (e) { console.log('Brightness error:', e); }
    setShowBrightnessBar(true);
    setTimeout(() => setShowBrightnessBar(false), 1500);
  };

  // Play/Pause toggle
  const togglePlayPause = async () => {
    if (isLocked) {
      showControls();
      return;
    }
    showControls();
    if (video.current) {
      if (isPlaying) {
        await video.current.pauseAsync();
      } else {
        await video.current.playAsync();
      }
      setIsPlaying(!isPlaying);
    }
  };

  const handleDoubleTap = (event) => {
    if (isLocked) {
      showControls();
      return;
    }
    const now = Date.now();
    const DOUBLE_TAP_DELAY = 300;
    if (lastTap && (now - lastTap) < DOUBLE_TAP_DELAY) {
      const { locationX } = event.nativeEvent;
      if (locationX > SCREEN_WIDTH / 2) {
        // Seek forward
        video.current?.getStatusAsync().then(s => {
          if (s.isLoaded) video.current.setPositionAsync(s.positionMillis + 10000);
        });
      } else {
        // Seek backward
        video.current?.getStatusAsync().then(s => {
          if (s.isLoaded) video.current.setPositionAsync(s.positionMillis - 10000);
        });
      }
    } else {
      setLastTap(now);
      showControls();
    }
  };

  const changeSpeed = async () => {
    const speeds = [1.0, 1.25, 1.5, 2.0, 0.5];
    const nextIndex = (speeds.indexOf(playbackSpeed) + 1) % speeds.length;
    const newSpeed = speeds[nextIndex];
    setPlaybackSpeed(newSpeed);
    // Only apply rate if it's 1.0 or if the video is loaded and supports it
    if (video.current) {
      try {
        await video.current.setRateAsync(newSpeed, true);
      } catch (e) { console.log("Rate change not supported"); }
    }
    showControls();
  };
  
  const openExternalPlayer = async () => {
    try {
      await IntentLauncher.startActivityAsync('android.intent.action.VIEW', {
        data: channel.url,
        type: 'video/*',
      });
    } catch (e) {
      console.log("External Player Error:", e);
      alert("Please install VLC or MX Player to play this stream.");
    }
  };

  const getYouTubeEmbedUrl = (url) => {
    const regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*/;
    const match = url.match(regExp);
    const videoId = (match && match[2].length === 11) ? match[2] : url;
    return `https://www.youtube.com/embed/${videoId}?autoplay=1&controls=1&showinfo=0&rel=0`;
  };

  const url = (channel.url || '').toLowerCase();
  const isYouTube = channel.type === 'youtube' || url.includes('youtube.com') || url.includes('youtu.be');
  const isWebEmbed = channel.type === 'embed';
  const isNativeVideo = channel.type === 'stream' || (!isYouTube && !isWebEmbed && (
    url.includes('.m3u8') || 
    url.includes('.mpd') || 
    url.includes('.ts') || 
    url.includes(':8000') || 
    url.includes(':8080') ||
    url.includes('/play/') ||
    url.includes('/live/') ||
    !url.includes('.html')
  ));

  const getExtension = () => {
    if (url.includes('.mpd')) return 'mpd';
    if (url.includes('.m3u8')) return 'm3u8';
    if (url.includes('.ts')) return 'ts'; 
    if (url.includes(':8000') || url.includes(':8080') || url.includes('/play/')) return 'm3u8';
    return undefined;
  };

  return (
    <View style={styles.container}>
      <View style={styles.videoContainer}>
        <View style={StyleSheet.absoluteFill} {...panResponder.panHandlers}>
          {isNativeVideo && playerType === 'native' && channel.url ? (
            <Video
              key={channel.url}
              ref={video}
              style={styles.video}
              source={{ 
                uri: channel.url,
                overrideFileExtensionAndroid: getExtension(),
                headers: {
                  'User-Agent': 'VLC/3.0.12 LibVLC/3.0.12',
                  'Accept': '*/*',
                  'Connection': 'keep-alive',
                }
              }}
              useNativeControls={useNative}
              resizeMode={resizeMode}
              isLooping={false}
              volume={1.0}
              shouldMute={false}
              shouldCorrectPitch={false}
              onPlaybackStatusUpdate={s => {
                setStatus(s);
                if (s.isPlaying !== undefined) setIsPlaying(s.isPlaying);
              }}
              onError={(e) => {
                console.log("Player Error:", e);
              }}
              onFullscreenUpdate={async ({ fullscreenUpdate }) => {
                if (fullscreenUpdate === 1) {
                  await ScreenOrientation.lockAsync(ScreenOrientation.OrientationLock.LANDSCAPE);
                } else if (fullscreenUpdate === 3 || fullscreenUpdate === 2) {
                  await ScreenOrientation.lockAsync(ScreenOrientation.OrientationLock.PORTRAIT);
                }
              }}
              shouldPlay
            />
          ) : (
            <WebView
              style={styles.video}
              source={{ 
                html: `
                  <!DOCTYPE html>
                  <html>
                  <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0"/>
                    <link href="https://vjs.zencdn.net/7.20.3/video-js.css" rel="stylesheet" />
                    <script src="https://vjs.zencdn.net/7.20.3/video.min.js"></script>
                    <style>
                      body { margin: 0; background: #000; overflow: hidden; }
                      .video-js { width: 100vw !important; height: 100vh !important; }
                    </style>
                  </head>
                  <body>
                    <video id="video" class="video-js vjs-default-skin" controls autoplay playsinline data-setup='{}'>
                      <source src="${channel.url}" type="${channel.url.includes('.mpd') ? 'application/dash+xml' : 'application/x-mpegURL'}">
                    </video>
                  </body>
                  </html>
                `
              }}
              allowsFullscreenVideo={true}
              javaScriptEnabled={true}
              domStorageEnabled={true}
              startInLoadingState={true}
              mediaPlaybackRequiresUserAction={false}
            />
          )}
        </View>

        {/* TAP DETECTOR (Always present to handle showing/hiding) */}
        <TouchableOpacity 
          style={StyleSheet.absoluteFill} 
          onPress={handleDoubleTap} 
          activeOpacity={1} 
        >
          {isNativeVideo && controlsVisible && (
            <View style={styles.controlsOverlay}>
              {isLocked ? (
                <View style={{flex: 1, alignItems: 'center', justifyContent: 'center'}}>
                  <TouchableOpacity style={styles.lockBtnLarge} onPress={() => setIsLocked(false)}>
                    <Ionicons name="lock-closed" size={40} color="#fff" />
                    <Text style={{color: '#fff', marginTop: 10, fontWeight: 'bold'}}>UNLOCK</Text>
                  </TouchableOpacity>
                </View>
              ) : (
                <>
                  {/* LEFT: Brightness & Lock */}
                  <View style={styles.controlColumn}>
                    <TouchableOpacity style={styles.controlBtn} onPress={() => setIsLocked(true)}>
                      <Ionicons name="lock-open-outline" size={18} color="#fff" />
                    </TouchableOpacity>
                    <TouchableOpacity style={[styles.controlBtn, {marginTop: 10}]} onPress={() => adjustBrightness(0.1)}>
                      <Ionicons name="sunny" size={18} color="#ffcc00" />
                    </TouchableOpacity>
                    <TouchableOpacity style={styles.controlBtn} onPress={() => adjustBrightness(-0.1)}>
                      <Ionicons name="sunny-outline" size={18} color="#ffcc00" />
                    </TouchableOpacity>
                  </View>

                  {/* CENTER: Play/Pause + Fullscreen + Speed */}
                  <View style={styles.centerControls}>
                    <TouchableOpacity style={styles.fullscreenBtn} onPress={changeSpeed}>
                      <Text style={{color: '#fff', fontWeight: 'bold', fontSize: 12}}>{playbackSpeed}x</Text>
                    </TouchableOpacity>
                    <TouchableOpacity style={styles.playBtn} onPress={togglePlayPause}>
                      <Ionicons name={isPlaying ? "pause" : "play"} size={32} color="#fff" />
                    </TouchableOpacity>
                    <View style={{gap: 10}}>
                      <TouchableOpacity 
                        style={styles.fullscreenBtn} 
                        onPress={() => video.current?.presentFullscreenPlayer()}
                      >
                        <Ionicons name="expand" size={18} color="#fff" />
                      </TouchableOpacity>
                      <TouchableOpacity 
                        style={styles.fullscreenBtn} 
                        onPress={() => {
                          const modes = [ResizeMode.CONTAIN, ResizeMode.COVER, ResizeMode.STRETCH];
                          const nextIndex = (modes.indexOf(resizeMode) + 1) % modes.length;
                          setResizeMode(modes[nextIndex]);
                          showControls();
                        }}
                      >
                        <Ionicons name="scan" size={18} color="#fff" />
                      </TouchableOpacity>
                    </View>
                    <TouchableOpacity 
                      style={styles.fullscreenBtn} 
                      onPress={() => setPlayerType(playerType === 'native' ? 'web' : 'native')}
                    >
                      <Ionicons name={playerType === 'native' ? "globe-outline" : "tv-outline"} size={18} color="#fff" />
                    </TouchableOpacity>
                    <TouchableOpacity 
                      style={styles.fullscreenBtn} 
                      onPress={async () => {
                        if (video.current) {
                          await video.current.unloadAsync();
                          await video.current.loadAsync({ uri: channel.url }, {}, true);
                        }
                      }}
                    >
                      <Ionicons name="refresh" size={18} color="#fff" />
                    </TouchableOpacity>
                    <TouchableOpacity 
                      style={[styles.fullscreenBtn, {backgroundColor: '#ff2d2d'}]} 
                      onPress={openExternalPlayer}
                    >
                      <Ionicons name="share-outline" size={18} color="#fff" />
                    </TouchableOpacity>
                  </View>

                  {/* RIGHT: Volume */}
                  <View style={styles.controlColumn}>
                    <TouchableOpacity style={styles.controlBtn} onPress={() => adjustVolume(0.1)}>
                      <Ionicons name="volume-high" size={18} color="#ff2d2d" />
                    </TouchableOpacity>
                    <TouchableOpacity style={styles.controlBtn} onPress={() => adjustVolume(-0.1)}>
                      <Ionicons name="volume-low" size={18} color="#ff2d2d" />
                    </TouchableOpacity>
                  </View>
                </>
              )}
            </View>
          )}

          {isNativeVideo && showVolumeBar && (
            <View style={styles.indicatorOverlay}>
              <Ionicons name={volume === 0 ? "volume-mute" : "volume-high"} size={28} color="#fff" />
              <View style={styles.indicatorBarBg}>
                <View style={[styles.indicatorBarFill, { width: `${volume * 100}%`, backgroundColor: '#ff2d2d' }]} />
              </View>
              <Text style={styles.indicatorText}>{Math.round(volume * 100)}%</Text>
            </View>
          )}

          {isNativeVideo && showBrightnessBar && (
            <View style={styles.indicatorOverlay}>
              <Ionicons name="sunny" size={28} color="#fff" />
              <View style={styles.indicatorBarBg}>
                <View style={[styles.indicatorBarFill, { width: `${brightness * 100}%`, backgroundColor: '#ffcc00' }]} />
              </View>
              <Text style={styles.indicatorText}>{Math.round(brightness * 100)}%</Text>
            </View>
          )}
        </TouchableOpacity>

        {/* BACK BUTTON */}
        <TouchableOpacity style={styles.backButton} onPress={() => navigation.goBack()}>
          <Ionicons name="arrow-back" size={22} color="#fff" />
        </TouchableOpacity>
      </View>
      
      <View style={styles.infoContainer}>
        <Text style={styles.title}>{channel.title}</Text>
        <Text style={styles.category}>{channel.category} • {channel.type === 'youtube' ? 'YouTube' : channel.type === 'embed' ? 'Web Embed' : 'Live Streaming'}</Text>
        
        <View style={styles.adSection}>
          <UnityAdBanner />
        </View>

        <View style={styles.statsRow}>
          <View style={styles.statBox}>
            <Ionicons name="eye" size={20} color="#ff2d2d" />
            <Text style={styles.statText}>  Live</Text>
          </View>
          {isNativeVideo && (
            <TouchableOpacity style={styles.statBox} onPress={() => adjustVolume(volume > 0 ? -volume : 1)}>
              <Ionicons name={volume === 0 ? "volume-mute" : "volume-high"} size={20} color="#ff2d2d" />
              <Text style={styles.statText}>  {volume === 0 ? 'Unmute' : 'Mute'}</Text>
            </TouchableOpacity>
          )}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0a0a0a' },
  videoContainer: { width: '100%', height: SCREEN_WIDTH * (9 / 16), backgroundColor: '#000' },
  video: { flex: 1 },
  backButton: { 
    position: 'absolute', top: 40, left: 15, zIndex: 10, 
    padding: 8, backgroundColor: 'rgba(0,0,0,0.6)', borderRadius: 20 
  },

  // Controls overlay at bottom of video
  controlsOverlay: {
    position: 'absolute', bottom: 0, left: 0, right: 0,
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
    paddingHorizontal: 20, paddingBottom: 15,
    backgroundColor: 'rgba(0,0,0,0.5)',
    zIndex: 100,
  },
  controlColumn: { alignItems: 'center', gap: 4 },
  controlBtn: {
    flexDirection: 'row', alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.6)', borderRadius: 20,
    paddingVertical: 5, paddingHorizontal: 8,
  },
  miniIcon: { marginLeft: 1 },
  centerControls: { flexDirection: 'row', alignItems: 'center', gap: 15 },
  playBtn: {
    backgroundColor: 'rgba(255,45,45,0.7)', borderRadius: 30,
    width: 60, height: 60, alignItems: 'center', justifyContent: 'center',
  },
  lockBtnLarge: {
    backgroundColor: 'rgba(255,45,45,0.8)', padding: 30, borderRadius: 100,
    alignItems: 'center', justifyContent: 'center'
  },
  fullscreenBtn: {
    backgroundColor: 'rgba(0,0,0,0.6)', borderRadius: 18,
    padding: 10, minWidth: 40, alignItems: 'center'
  },

  // Volume/Brightness overlay indicator
  indicatorOverlay: {
    position: 'absolute', top: '40%', alignSelf: 'center',
    flexDirection: 'row', alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.75)', borderRadius: 25,
    paddingVertical: 8, paddingHorizontal: 16, gap: 10,
  },
  indicatorBarBg: {
    width: 100, height: 5, backgroundColor: 'rgba(255,255,255,0.3)', borderRadius: 3,
  },
  indicatorBarFill: { height: '100%', borderRadius: 3 },
  indicatorText: { color: '#fff', fontSize: 13, fontWeight: 'bold' },

  infoContainer: { padding: 20, flex: 1 },
  title: { color: '#fff', fontSize: 22, fontWeight: 'bold', marginBottom: 5 },
  category: { color: '#888', fontSize: 14, marginBottom: 20 },
  adSection: { marginVertical: 10 },
  statsRow: { flexDirection: 'row', marginTop: 20, gap: 12 },
  statBox: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#1a1a1a', padding: 12, borderRadius: 10 },
  statText: { color: '#fff', fontWeight: 'bold' }
});
