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
        shouldDuckAndroid: false,
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
                overrideFileExtensionAndroid: 'ts', // Force TS for .ts streams
                headers: {
                  'User-Agent': 'Lavf/58.29.100', // Mimic FFmpeg/VLC core
                }
              }}
              useNativeControls={true} // Use native controls to see if it fixes audio routing
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
                    <script src="https://cdn.jsdelivr.net/npm/mpegts.js@latest/dist/mpegts.min.js"></script>
                    <style>
                      body { margin: 0; background: #000; overflow: hidden; display: flex; align-items: center; justify-content: center; height: 100vh; }
                      video { width: 100%; height: auto; max-height: 100vh; }
                    </style>
                  </head>
                  <body>
                    <video id="videoElement" controls autoplay playsinline></video>
                    <script>
                      if (mpegts.getFeatureList().mseLivePlayback) {
                        var videoElement = document.getElementById('videoElement');
                        var player = mpegts.createPlayer({
                          type: 'mse',
                          isLive: true,
                          url: '${channel.url}'
                        });
                        player.attachMediaElement(videoElement);
                        player.load();
                        player.play().catch(function(e) {
                          videoElement.play();
                        });
                      } else {
                        var v = document.getElementById('videoElement');
                        v.src = '${channel.url}';
                        v.play();
                      }
                    </script>
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

        {/* TAP DETECTOR */}
        <TouchableOpacity 
          style={StyleSheet.absoluteFill} 
          onPress={handleDoubleTap} 
          activeOpacity={1} 
        >
          {isNativeVideo && !useNative && controlsVisible && (
            <View style={styles.controlsOverlay}>
              {/* Custom controls logic... */}
            </View>
          )}
        </TouchableOpacity>

        {/* BACK BUTTON */}
        <TouchableOpacity style={styles.backButton} onPress={() => navigation.goBack()}>
          <Ionicons name="arrow-back" size={22} color="#fff" />
        </TouchableOpacity>
        
        {/* EXTERNAL PLAYER BUTTON - TOP RIGHT */}
        <TouchableOpacity style={styles.externalPlayerBtn} onPress={openExternalPlayer}>
          <Ionicons name="share-outline" size={22} color="#fff" />
        </TouchableOpacity>
      </View>
      
      <View style={styles.infoContainer}>
        <Text style={styles.title}>{channel.title}</Text>
        <Text style={styles.category}>{channel.category}</Text>
        
        <TouchableOpacity 
          style={styles.modeToggle} 
          onPress={() => setUseNative(!useNative)}
        >
          <Ionicons name={useNative ? "options" : "options-outline"} size={20} color="#fff" />
          <Text style={{color: '#fff', marginLeft: 10}}>
            {useNative ? "Using Native Engine (Auto)" : "Using Custom Engine"}
          </Text>
        </TouchableOpacity>

        <View style={styles.adSection}>
          <UnityAdBanner />
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
  externalPlayerBtn: { 
    position: 'absolute', top: 40, right: 15, zIndex: 10, 
    padding: 8, backgroundColor: '#ff2d2d', borderRadius: 20 
  },
  modeToggle: {
    flexDirection: 'row', alignItems: 'center', backgroundColor: '#1a1a1a', 
    padding: 15, borderRadius: 12, marginTop: 10
  },
  infoContainer: { padding: 20, flex: 1 },
  title: { color: '#fff', fontSize: 22, fontWeight: 'bold', marginBottom: 5 },
  category: { color: '#888', fontSize: 14, marginBottom: 20 },
  adSection: { marginVertical: 10 },
  statsRow: { flexDirection: 'row', marginTop: 20, gap: 12 },
  statBox: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#1a1a1a', padding: 12, borderRadius: 10 },
  statText: { color: '#fff', fontWeight: 'bold' }
});
