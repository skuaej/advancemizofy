import React, { useRef, useState, useCallback, useEffect } from 'react';
import { View, Text, StyleSheet, Dimensions, TouchableOpacity, PanResponder, StatusBar as RNStatusBar, AppState, Alert } from 'react-native';
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
            adjustVolume(-dy / 500); 
          } else {
            adjustBrightness(-dy / 500);
          }
          showControls();
        }
      },
      onPanResponderRelease: () => {},
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
      
      // Volume Hammer: Forcibly ensure volume is 100% multiple times
      let hammerCount = 0;
      const hammerInterval = setInterval(() => {
        if (video.current && hammerCount < 10) {
          video.current.setVolumeAsync(1.0).catch(() => {});
          video.current.setIsMutedAsync(false).catch(() => {});
          hammerCount++;
        } else {
          clearInterval(hammerInterval);
        }
      }, 1000);
      
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
    }, 3000);
  };

  const showControls = () => {
    setControlsVisible(true);
    startTimer();
  };

  const adjustVolume = async (delta) => {
    const newVol = Math.min(1.0, Math.max(0, volume + delta));
    setVolume(newVol);
    if (video.current) await video.current.setVolumeAsync(newVol);
    setShowVolumeBar(true);
    setTimeout(() => setShowVolumeBar(false), 1500);
  };

  const adjustBrightness = async (delta) => {
    const newBright = Math.min(1.0, Math.max(0.05, brightness + delta));
    setBrightnessVal(newBright);
    try {
      await Brightness.setBrightnessAsync(newBright);
    } catch (e) {}
    setShowBrightnessBar(true);
    setTimeout(() => setShowBrightnessBar(false), 1500);
  };

  const togglePlayPause = async () => {
    if (isLocked) { showControls(); return; }
    showControls();
    if (video.current) {
      if (isPlaying) await video.current.pauseAsync();
      else await video.current.playAsync();
      setIsPlaying(!isPlaying);
    }
  };

  const handleDoubleTap = (event) => {
    if (isLocked) { showControls(); return; }
    const now = Date.now();
    if (lastTap && (now - lastTap) < 300) {
      const { locationX } = event.nativeEvent;
      if (locationX > SCREEN_WIDTH / 2) {
        video.current?.getStatusAsync().then(s => {
          if (s.isLoaded) video.current.setPositionAsync(s.positionMillis + 10000);
        });
      } else {
        video.current?.getStatusAsync().then(s => {
          if (s.isLoaded) video.current.setPositionAsync(s.positionMillis - 10000);
        });
      }
    } else {
      setLastTap(now);
      showControls();
    }
  };

  const getBaseDomain = (url) => {
    try {
      const match = url.match(/^(https?:\/\/[^\/]+)/);
      return match ? match[1] : url;
    } catch (e) { return url; }
  };

  const openExternalPlayer = async () => {
    try {
      await IntentLauncher.startActivityAsync('android.intent.action.VIEW', {
        data: channel.url,
        type: 'video/*',
      });
    } catch (e) {
      Alert.alert("Error", "Please install VLC or MX Player to play this stream.");
    }
  };

  const url = (channel.url || '').toLowerCase();
  const isYouTube = channel.type === 'youtube' || url.includes('youtube.com') || url.includes('youtu.be');
  const isWebEmbed = channel.type === 'embed';
  const getExtension = () => {
    if (url.includes('.mpd')) return 'mpd';
    if (url.includes('.m3u8')) return 'm3u8';
    if (url.includes('.ts')) return 'ts'; 
    if (url.includes(':8000') || url.includes(':8080') || url.includes('/play/')) return 'm3u8';
    return undefined;
  };

  const isNativeVideo = channel.type === 'stream' || (!isYouTube && !isWebEmbed && (
    url.includes('.m3u8') || url.includes('.mpd') || url.includes('.ts') || 
    url.includes(':8000') || url.includes(':8080') || url.includes('/play/') ||
    url.includes('/live/') || !url.includes('.html')
  ));

  return (
    <View style={styles.container}>
      <View style={styles.videoContainer}>
        <View style={StyleSheet.absoluteFill} {...panResponder.panHandlers}>
          {isNativeVideo && playerType === 'native' ? (
            <Video
              key={channel.url}
              ref={video}
              style={styles.video}
              source={{ 
                uri: channel.url,
                overrideFileExtensionAndroid: 'ts',
                headers: {
                  'Icy-MetaData': '1',
                  'User-Agent': 'VLC/3.0.12 LibVLC/3.0.12'
                }
              }}
              useNativeControls={false}
              resizeMode={resizeMode}
              isLooping={false}
              volume={1.0}
              shouldMute={false}
              shouldCorrectPitch={false}
              shouldPlay={true}
              onLoad={async () => {
                if (video.current) {
                  await video.current.setVolumeAsync(1.0);
                  await video.current.setIsMutedAsync(false);
                }
              }}
              onPlaybackStatusUpdate={setStatus}
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
                    <script src="https://cdn.jsdelivr.net/npm/shaka-player@latest/dist/shaka-player.ui.js"></script>
                    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/shaka-player@latest/dist/controls.css">
                    <style>
                      body { margin: 0; background: #000; overflow: hidden; display: flex; align-items: center; justify-content: center; height: 100vh; }
                      #video { width: 100%; height: 100vh; }
                    </style>
                  </head>
                  <body>
                    <div data-shaka-player-container style="width:100%; height:100vh;">
                      <video id="video" data-shaka-player autoplay playsinline style="width:100%; height:100%;"></video>
                    </div>
                    <script>
                      async function initApp() {
                        const video = document.getElementById('video');
                        const ui = video['ui'];
                        const controls = ui.getControls();
                        const player = controls.getPlayer();

                        try {
                          await player.load('${channel.url}');
                          console.log('The video has now been loaded!');
                        } catch (e) {
                          console.error('Error code', e.code, 'object', e);
                          // Fallback to native video tag if Shaka fails
                          video.src = '${channel.url}';
                        }
                      }

                      document.addEventListener('shaka-ui-loaded', initApp);
                      document.addEventListener('shaka-ui-load-failed', () => {
                         const video = document.getElementById('video');
                         video.src = '${channel.url}';
                         video.play();
                      });
                    </script>
                  </body>
                  </html>
                `
              }}
              allowsFullscreenVideo={true}
            />
          )}
        </View>

        <TouchableOpacity style={StyleSheet.absoluteFill} onPress={handleDoubleTap} activeOpacity={1}>
          {controlsVisible && !isLocked && (
            <View style={styles.controlsOverlay}>
              {/* TOP BAR */}
              <View style={styles.topBar}>
                <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
                  <Ionicons name="arrow-back" size={24} color="#fff" />
                </TouchableOpacity>
                <Text style={styles.headerTitle} numberOfLines={1}>{channel.title}</Text>
                <TouchableOpacity onPress={openExternalPlayer} style={styles.vlcBtn}>
                  <Ionicons name="logo-playstation" size={24} color="#fff" />
                  <Text style={styles.vlcText}>VLC</Text>
                </TouchableOpacity>
              </View>

              {/* CENTER CONTROLS */}
              <View style={styles.centerRow}>
                <TouchableOpacity style={styles.mainPlayBtn} onPress={togglePlayPause}>
                  <Ionicons name={isPlaying ? "pause" : "play"} size={45} color="#fff" />
                </TouchableOpacity>
              </View>

              {/* BOTTOM BAR */}
              <View style={styles.bottomBar}>
                <TouchableOpacity style={styles.bottomIcon} onPress={() => setIsLocked(true)}>
                  <Ionicons name="lock-open-outline" size={22} color="#fff" />
                </TouchableOpacity>
                <TouchableOpacity style={styles.bottomIcon} onPress={() => setPlayerType(playerType === 'native' ? 'web' : 'native')}>
                  <Ionicons name={playerType === 'native' ? "globe-outline" : "tv-outline"} size={22} color="#fff" />
                </TouchableOpacity>
                <TouchableOpacity style={styles.bottomIcon} onPress={() => setResizeMode(resizeMode === ResizeMode.CONTAIN ? ResizeMode.STRETCH : ResizeMode.CONTAIN)}>
                  <Ionicons name="expand-outline" size={22} color="#fff" />
                </TouchableOpacity>
              </View>
            </View>
          )}

          {isLocked && controlsVisible && (
            <View style={styles.lockOverlay}>
              <TouchableOpacity style={styles.lockBtnLarge} onPress={() => setIsLocked(false)}>
                <Ionicons name="lock-closed" size={40} color="#fff" />
                <Text style={{color: '#fff', marginTop: 10, fontWeight: 'bold'}}>UNLOCK</Text>
              </TouchableOpacity>
            </View>
          )}

          {showVolumeBar && (
            <View style={styles.indicatorOverlay}>
              <Ionicons name="volume-high" size={28} color="#fff" />
              <View style={styles.indicatorBarBg}>
                <View style={[styles.indicatorBarFill, { width: `${volume * 100}%`, backgroundColor: '#ff2d2d' }]} />
              </View>
            </View>
          )}

          {showBrightnessBar && (
            <View style={styles.indicatorOverlay}>
              <Ionicons name="sunny" size={28} color="#fff" />
              <View style={styles.indicatorBarBg}>
                <View style={[styles.indicatorBarFill, { width: `${brightness * 100}%`, backgroundColor: '#ffcc00' }]} />
              </View>
            </View>
          )}
        </TouchableOpacity>
      </View>
      
      <View style={styles.infoContainer}>
        <Text style={styles.title}>{channel.title}</Text>
        <Text style={styles.category}>{channel.category} • {channel.type === 'stream' ? 'Live Stream' : 'Video'}</Text>
        {/* Temporarily disabled Ad Banner to prevent audio focus theft */}
        {/* <View style={styles.adSection}><UnityAdBanner /></View> */}
        
        <TouchableOpacity style={styles.vlcActionBtn} onPress={openExternalPlayer}>
          <Ionicons name="flash" size={20} color="#fff" />
          <Text style={styles.vlcActionText}>FIX SOUND: PLAY IN VLC PLAYER</Text>
        </TouchableOpacity>

        <View style={styles.statsRow}>
          <View style={styles.statBox}>
            <Ionicons name="eye" size={20} color="#ff2d2d" />
            <Text style={styles.statText}>  LIVE</Text>
          </View>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0a0a0a' },
  videoContainer: { width: '100%', height: SCREEN_WIDTH * (9 / 16), backgroundColor: '#000' },
  video: { flex: 1 },
  controlsOverlay: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'space-between', padding: 15 },
  topBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  backBtn: { padding: 5 },
  headerTitle: { color: '#fff', fontSize: 16, fontWeight: 'bold', flex: 1, marginHorizontal: 15 },
  vlcBtn: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#ff6600', paddingHorizontal: 10, paddingVertical: 5, borderRadius: 15 },
  vlcText: { color: '#fff', fontWeight: 'bold', marginLeft: 5, fontSize: 12 },
  centerRow: { alignItems: 'center', justifyContent: 'center' },
  mainPlayBtn: { backgroundColor: 'rgba(255,45,45,0.8)', width: 80, height: 80, borderRadius: 40, alignItems: 'center', justifyContent: 'center' },
  bottomBar: { flexDirection: 'row', justifyContent: 'space-around', paddingBottom: 10 },
  bottomIcon: { padding: 10, backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: 20 },
  lockOverlay: { ...StyleSheet.absoluteFillObject, alignItems: 'center', justifyContent: 'center', backgroundColor: 'rgba(0,0,0,0.6)' },
  lockBtnLarge: { alignItems: 'center' },
  indicatorOverlay: { position: 'absolute', top: '40%', alignSelf: 'center', flexDirection: 'row', alignItems: 'center', backgroundColor: 'rgba(0,0,0,0.8)', borderRadius: 25, padding: 15, gap: 10 },
  indicatorBarBg: { width: 100, height: 4, backgroundColor: 'rgba(255,255,255,0.2)', borderRadius: 2 },
  indicatorBarFill: { height: '100%', borderRadius: 2 },
  infoContainer: { padding: 20 },
  title: { color: '#fff', fontSize: 22, fontWeight: 'bold' },
  category: { color: '#888', fontSize: 14, marginVertical: 5 },
  vlcActionBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', backgroundColor: '#ff6600', padding: 15, borderRadius: 12, marginTop: 15 },
  vlcActionText: { color: '#fff', fontWeight: 'bold', marginLeft: 10 },
  adSection: { marginVertical: 15 },
  statsRow: { flexDirection: 'row', gap: 10 },
  statBox: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#1a1a1a', padding: 10, borderRadius: 8 },
  statText: { color: '#fff', fontWeight: 'bold', fontSize: 12 }
});
