import React, { useState, useEffect, useRef, useCallback } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, Image, Share, ScrollView, ActivityIndicator, Dimensions, TextInput, Alert, Modal } from 'react-native';
import { useNavigation, useFocusEffect } from '@react-navigation/native';
import UnityAdBanner from '../components/UnityAdBanner';
import { Ionicons } from '@expo/vector-icons';
import { ref, onValue } from 'firebase/database';
import { database } from '../firebaseConfig';
import * as Linking from 'expo-linking';
import * as ScreenCapture from 'expo-screen-capture';
import * as Network from 'expo-network';
import * as Device from 'expo-device';
import * as FileSystem from 'expo-file-system';
import * as IntentLauncher from 'expo-intent-launcher';
import * as Notifications from 'expo-notifications';
import * as Application from 'expo-application';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});

const { width } = Dimensions.get('window');

// Increment this natively when publishing new APKs
const CURRENT_APP_VERSION = 2;

export default function HomeScreen() {
  const navigation = useNavigation();
  const [channels, setChannels] = useState([]);
  const [categories, setCategories] = useState([]);
  const [activeCategory, setActiveCategory] = useState('');
  const [banners, setBanners] = useState([]);
  const [settings, setSettings] = useState({ telegramLink: '', whatsappLink: '', appShareLink: '', showAds: true });
  const [globalConfig, setGlobalConfig] = useState({ alertMsg: '', forceUpdateLink: '', requiredVersion: 1 });
  const [searchQuery, setSearchQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [securityViolation, setSecurityViolation] = useState(false);
  const [downloading, setDownloading] = useState(false);
  const [downloadProgress, setDownloadProgress] = useState(0);
  const [forceBypassed, setForceBypassed] = useState(false);
  const carouselRef = useRef(null);

  const downloadAndInstallApk = async () => {
    const link = globalConfig.forceUpdateLink;
    if (!link) {
      Alert.alert('Error', 'No update link set by admin.');
      return;
    }

    try {
      setDownloading(true);
      setDownloadProgress(0);

      let directUrl = link.trim();

      // Auto-upgrade http:// to https:// to prevent Android cross-protocol redirect blocking
      if (directUrl.startsWith('http://')) {
        directUrl = directUrl.replace('http://', 'https://');
      }

      // Check for redirects to capture the final direct download destination
      try {
        const resCheck = await fetch(directUrl, {
          method: 'GET',
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
          }
        });
        if (resCheck && resCheck.url) {
          directUrl = resCheck.url;
        }
      } catch (e) {
        console.log('Direct URL check:', e);
      }

      // 1. Handle Mediafire links by resolving the direct binary download URL
      if (link.includes('mediafire.com')) {
        try {
          const res = await fetch(link, {
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
            }
          });
          const text = await res.text();
          const match = text.match(/https:\/\/download\d+\.mediafire\.com\/[^\s"'<>]+/i) ||
                        text.match(/href=["'](https?:\/\/[a-zA-Z0-9_\-\.]*mediafire\.com\/[^\s"']+)["'][^>]*id=["']downloadButton["']/i);
          if (match) {
            directUrl = match[1] || match[0];
          }
        } catch (scrapeErr) {
          console.log('Mediafire direct link resolution error:', scrapeErr);
        }
      }

      // 2. Handle Google Drive links
      if (link.includes('drive.google.com')) {
        const gdriveMatch = link.match(/\/d\/([a-zA-Z0-9_-]+)/) || link.match(/id=([a-zA-Z0-9_-]+)/);
        if (gdriveMatch && gdriveMatch[1]) {
          directUrl = `https://drive.usercontent.google.com/download?id=${gdriveMatch[1]}&export=download&confirm=t`;
        }
      }

      const fileUri = FileSystem.cacheDirectory + 'mizofy_update.apk';

      // Delete old APK if exists
      const fileInfo = await FileSystem.getInfoAsync(fileUri);
      if (fileInfo.exists) {
        await FileSystem.deleteAsync(fileUri, { idempotent: true });
      }

      // Download directly inside the app with browser User-Agent
      const downloadResumable = FileSystem.createDownloadResumable(
        directUrl,
        fileUri,
        {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
          }
        },
        (progress) => {
          if (progress.totalBytesExpectedToWrite > 0) {
            const pct = progress.totalBytesWritten / progress.totalBytesExpectedToWrite;
            setDownloadProgress(Math.min(1, Math.max(0, pct)));
          }
        }
      );

      const downloadResult = await downloadResumable.downloadAsync();
      const localUri = downloadResult ? downloadResult.uri : fileUri;

      setDownloading(false);

      // Validate that downloaded file is a real APK (greater than 500 KB)
      const downloadedFileInfo = await FileSystem.getInfoAsync(localUri);
      if (!downloadedFileInfo.exists || downloadedFileInfo.size < 500 * 1024) {
        const sizeKb = downloadedFileInfo.exists ? Math.round(downloadedFileInfo.size / 1024) : 0;
        throw new Error(`The link provided is not an APK file (Downloaded size: ${sizeKb} KB). Please paste a valid direct APK download link.`);
      }

      // Convert file:// to content:// for Android PackageInstaller
      let contentUri = localUri;
      try {
        contentUri = await FileSystem.getContentUriAsync(localUri);
      } catch (uriErr) {
        console.log('getContentUriAsync fallback:', uriErr);
      }

      // Launch native Android installer directly
      await IntentLauncher.startActivityAsync('android.intent.action.VIEW', {
        data: contentUri,
        flags: 1, // FLAG_GRANT_READ_URI_PERMISSION
        type: 'application/vnd.android.package-archive',
      });

    } catch (e) {
      setDownloading(false);
      setDownloadProgress(0);
      console.error('APK Download & Install Error:', e);
      Alert.alert(
        'Download Error',
        e.message || 'Could not complete the automatic download. Would you like to open the download link in your browser?',
        [
          { text: 'Open in Browser', onPress: () => Linking.openURL(link) },
          { text: 'Retry', onPress: downloadAndInstallApk },
          { text: 'Cancel', style: 'cancel' }
        ]
      );
    }
  };

  useEffect(() => {
    if (!database) {
      setLoading(false);
      return;
    }

    try {
      // Request system notification permissions and create notification channel
      const initNotifications = async () => {
        try {
          const { status: existingStatus } = await Notifications.getPermissionsAsync();
          let finalStatus = existingStatus;
          if (existingStatus !== 'granted') {
            const { status } = await Notifications.requestPermissionsAsync();
            finalStatus = status;
          }
          await Notifications.setNotificationChannelAsync('default', {
            name: 'Mizofy TV Notifications',
            importance: Notifications.AndroidImportance.MAX,
            vibrationPattern: [0, 250, 250, 250],
            lightColor: '#ff2d2d',
          });
        } catch (err) {
          console.log('Notification channel setup error:', err);
        }
      };
      initNotifications();

      // Sync Channels
      const channelsRef = ref(database, 'channels');
      const unsubscribeChannels = onValue(channelsRef, (snapshot) => {
        const data = snapshot.val();
        if (data) setChannels(Object.keys(data).map(key => ({ id: key, ...data[key] })));
        else setChannels([]);
      });

      // Sync Categories
      const categoriesRef = ref(database, 'categories');
      const unsubscribeCategories = onValue(categoriesRef, (snapshot) => {
        const data = snapshot.val();
        if (data) {
          const sortedCats = Object.keys(data)
            .map(key => ({ id: key, ...data[key] }))
            .sort((a, b) => (a.order || 0) - (b.order || 0));
          
          const catList = sortedCats.map(c => c.name);
          setCategories(catList);
          if (catList.length > 0) setActiveCategory(catList[0]);
        } else setCategories([]);
      });

      // Sync Banners
      const bannersRef = ref(database, 'banners');
      const unsubscribeBanners = onValue(bannersRef, (snapshot) => {
        const data = snapshot.val();
        if (data) setBanners(Object.keys(data).map(key => data[key]).filter(b => b.imageUrl));
        else setBanners([]);
        setLoading(false);
      });

      // Sync Settings & Socials
      const settingsRef = ref(database, 'settings');
      const unsubscribeSettings = onValue(settingsRef, (snapshot) => {
        const data = snapshot.val();
        if (data) setSettings(data);
      });

      // Sync Global Config (Force Update & Notifications)
      const configRef = ref(database, 'globalConfig');
      const unsubscribeConfig = onValue(configRef, (snapshot) => {
        const data = snapshot.val();
        if (data) setGlobalConfig(data);
      });

      // Sync Latest Notification (Posts directly to Android System Notification Panel)
      const notifRef = ref(database, 'latestNotification');
      let isFirstLoadNotif = true;
      const unsubscribeNotif = onValue(notifRef, async (snapshot) => {
        const data = snapshot.val();
        if (data && !isFirstLoadNotif) {
          try {
            await Notifications.scheduleNotificationAsync({
              content: {
                title: data.title || "Mizofy TV",
                body: data.message || "",
                sound: true,
                priority: Notifications.AndroidNotificationPriority.HIGH,
              },
              trigger: null, // Shows directly in Android notification drawer
            });
          } catch (notifErr) {
            console.log('System notification post error:', notifErr);
          }
        }
        isFirstLoadNotif = false;
      });

      const timeout = setTimeout(() => setLoading(false), 3000);

      return () => {
        clearTimeout(timeout);
        unsubscribeChannels();
        unsubscribeCategories();
        unsubscribeBanners();
        unsubscribeSettings();
        unsubscribeConfig();
        unsubscribeNotif();
      };
    } catch (e) {
      console.warn('User Sync Error:', e);
      setLoading(false);
    }
  }, []);

  // Auto-Scroller for Banner Slider
  useEffect(() => {
    if (banners.length <= 1) return;
    let currentIndex = 0;
    const interval = setInterval(() => {
      currentIndex++;
      if (currentIndex >= banners.length) currentIndex = 0;
      carouselRef.current?.scrollToIndex({
        index: currentIndex,
        animated: true,
      });
    }, 4000); // Slides every 4 seconds

    return () => clearInterval(interval);
  }, [banners.length]);

  const onShareApp = async () => {
    try {
      await Share.share({ message: `Watch Premium Live TV! Download: ${settings.appShareLink || 'http://ummotv.com'}` });
    } catch (error) { console.log(error.message); }
  };

  const openSocial = (url) => {
    if(url) Linking.openURL(url);
  };

  const isStreamUrl = (url) => {
    if (!url) return false;
    const l = url.toLowerCase();
    return l.includes('.m3u8') || l.includes('.ts') || l.includes('.mpd') || 
           l.includes(':8000') || l.includes(':8080') || l.includes('/live/') || 
           l.includes('/play/') || (!l.includes('mediafire.com') && !l.endsWith('.html'));
  };

  const handleBannerPress = (banner) => {
    if (!banner.url) return;
    if (isStreamUrl(banner.url)) {
      navigation.navigate('Player', { channel: { url: banner.url, title: banner.title || 'Live Stream' } });
    } else {
      Linking.openURL(banner.url);
    }
  };

  const filteredChannels = activeCategory 
    ? channels.filter(c => c.category === activeCategory)
    : channels;

  const renderChannel = ({ item }) => (
    <TouchableOpacity style={styles.card} onPress={() => navigation.navigate('Player', { channel: item })}>
      <Image source={{ uri: item.thumbnail }} style={styles.thumbnail} />
      <View style={styles.cardInfo}>
        <Text style={styles.cardTitle}>{item.title}</Text>
        <Text style={styles.badge}>{item.category} {item.episode ? `• Ep ${item.episode}` : ''}</Text>
      </View>
    </TouchableOpacity>
  );

  // SECURITY VIOLATION BLOCKER
  if (securityViolation) {
    return (
      <View style={[styles.container, {justifyContent: 'center', alignItems: 'center', padding: 30}]}>
        <Ionicons name="shield-outline" size={80} color="#ff2d2d" />
        <Text style={{color: '#fff', fontSize: 24, fontWeight: 'bold', marginTop: 20}}>Security Error</Text>
        <Text style={{color: '#aaa', textAlign: 'center', marginTop: 10}}>
          Network capture tools or VPNs are not allowed while using Mizofy TV. Please disable them to continue.
        </Text>
        <TouchableOpacity 
          style={{marginTop: 30, backgroundColor: '#333', padding: 15, borderRadius: 10}}
          onPress={() => Linking.openSettings()}
        >
          <Text style={{color: '#fff'}}>Open Settings</Text>
        </TouchableOpacity>
      </View>
    );
  }

  // FORCE UPDATE BLOCKER
  const installedBuild = Number(Application.nativeBuildVersion || CURRENT_APP_VERSION || 1);
  const requiredBuild = Number(globalConfig.requiredVersion || 1);
  const isForceUpdateRequired = Boolean(
    !forceBypassed &&
    globalConfig.forceUpdateActive === true &&
    requiredBuild > installedBuild
  );

  if (isForceUpdateRequired) {
    const progressPercent = Math.round(downloadProgress * 100);

    return (
      <View style={[styles.container, {justifyContent: 'center', alignItems: 'center', padding: 25, backgroundColor: '#0a0a0a'}]}>
        <View style={{width: 100, height: 100, borderRadius: 50, backgroundColor: '#1a1a1a', justifyContent: 'center', alignItems: 'center', borderWidth: 2, borderColor: '#ff2d2d', marginBottom: 20}}>
          <Ionicons name="cloud-download-outline" size={54} color="#ff2d2d" />
        </View>
        
        <Text style={{color: '#fff', fontSize: 26, fontWeight: 'bold', textAlign: 'center'}}>Update Required</Text>
        <Text style={{color: '#ff2d2d', fontSize: 14, fontWeight: 'bold', marginTop: 5}}>
          Version {requiredBuild}.0 is Required (Current: v{installedBuild}.0)
        </Text>

        <Text style={{color: '#aaa', textAlign: 'center', marginTop: 15, marginBottom: 25, lineHeight: 22}}>
          A new version of Mizofy TV is available. Please update to continue watching streams smoothly.
        </Text>

        {downloading ? (
          <View style={{width: '100%', backgroundColor: '#161616', padding: 20, borderRadius: 14, borderWidth: 1, borderColor: '#ff2d2d', marginBottom: 25, alignItems: 'center'}}>
            <ActivityIndicator size="large" color="#ff2d2d" style={{marginBottom: 15}} />
            <Text style={{color: '#fff', fontWeight: 'bold', fontSize: 16, marginBottom: 10}}>
              Downloading APK... {progressPercent}%
            </Text>
            <View style={{width: '100%', height: 10, backgroundColor: '#262626', borderRadius: 5, overflow: 'hidden'}}>
              <View style={{width: `${Math.max(5, progressPercent)}%`, height: '100%', backgroundColor: '#ff2d2d', borderRadius: 5}} />
            </View>
            <Text style={{color: '#888', fontSize: 12, marginTop: 10}}>
              Please wait, installer will open automatically...
            </Text>
          </View>
        ) : (
          <View style={{backgroundColor: '#161616', width: '100%', padding: 15, borderRadius: 12, borderWidth: 1, borderColor: '#262626', marginBottom: 25}}>
            <Text style={{color: '#fff', fontWeight: 'bold', fontSize: 13, marginBottom: 8}}>📌 Direct In-App Update:</Text>
            <Text style={{color: '#888', fontSize: 12, lineHeight: 18}}>• Download completes inside the app without browser redirect.</Text>
            <Text style={{color: '#888', fontSize: 12, lineHeight: 18}}>• Android Package Installer opens automatically once done.</Text>
            <Text style={{color: '#888', fontSize: 12, lineHeight: 18}}>• Mizofy TV unlocks automatically after install.</Text>
          </View>
        )}

        <TouchableOpacity 
          style={{
            backgroundColor: downloading ? '#661a1a' : '#ff2d2d', 
            width: '100%', 
            paddingVertical: 18, 
            borderRadius: 14, 
            flexDirection: 'row', 
            justifyContent: 'center', 
            alignItems: 'center', 
            elevation: 5
          }}
          disabled={downloading}
          activeOpacity={0.8}
          onPress={downloadAndInstallApk}
        >
          {downloading ? (
            <>
              <ActivityIndicator size="small" color="#fff" style={{marginRight: 10}} />
              <Text style={{color: '#fff', fontWeight: 'bold', fontSize: 16}}>DOWNLOADING ({progressPercent}%)...</Text>
            </>
          ) : (
            <>
              <Ionicons name="download-outline" size={22} color="#fff" style={{marginRight: 10}} />
              <Text style={{color: '#fff', fontWeight: 'bold', fontSize: 16}}>DOWNLOAD & INSTALL UPDATE</Text>
            </>
          )}
        </TouchableOpacity>

        {/* ALREADY UPDATED / CHECK VERSION BUTTON */}
        {!downloading && (
          <TouchableOpacity 
            style={{
              backgroundColor: '#1a1a1a', 
              width: '100%', 
              paddingVertical: 14, 
              borderRadius: 14, 
              flexDirection: 'row', 
              justifyContent: 'center', 
              alignItems: 'center', 
              borderWidth: 1, 
              borderColor: '#333', 
              marginTop: 12
            }}
            activeOpacity={0.7}
            onPress={() => {
              if (installedBuild >= requiredBuild || !globalConfig.forceUpdateActive) {
                setForceBypassed(true);
                Alert.alert("Up to Date", `You have the latest version (v${installedBuild}.0). Unlocking app!`);
              } else {
                Alert.alert("Update Required", `Your installed version is v${installedBuild}.0, but v${requiredBuild}.0 is required. Please install the update.`);
              }
            }}
          >
            <Ionicons name="checkmark-circle-outline" size={20} color="#4CAF50" style={{marginRight: 8}} />
            <Text style={{color: '#fff', fontWeight: 'bold', fontSize: 14}}>ALREADY UPDATED? CHECK NOW</Text>
          </TouchableOpacity>
        )}
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView>
        <View style={styles.header}>
          <Text style={styles.logoText}>Mizofy <Text style={{color: '#ff2d2d'}}>TV</Text></Text>
          
          <View style={{flexDirection: 'row', gap: 15}}>
            {settings.whatsappLink ? (
               <TouchableOpacity style={styles.shareButton} onPress={() => openSocial(settings.whatsappLink)}>
                <Ionicons name="logo-whatsapp" size={24} color="#25D366" />
              </TouchableOpacity>
            ) : null}
            <TouchableOpacity style={styles.shareButton} onPress={onShareApp}>
              <Ionicons name="share-social" size={24} color="#fff" />
            </TouchableOpacity>
          </View>
        </View>

        {/* SEARCH BAR */}
        <View style={styles.searchContainer}>
          <Ionicons name="search" size={20} color="#666" style={{marginLeft: 15}} />
          <TextInput
            style={styles.searchInput}
            placeholder="Search all channels..."
            placeholderTextColor="#666"
            value={searchQuery}
            onChangeText={setSearchQuery}
          />
        </View>
        {/* CAROUSEL IMPLEMENTATION */}
        {banners.length > 0 && (
          <View style={styles.bannerContainer}>
            <FlatList
              ref={carouselRef}
              data={banners}
              horizontal
              pagingEnabled
              showsHorizontalScrollIndicator={false}
              keyExtractor={(item, index) => index.toString()}
              renderItem={({ item }) => (
                <TouchableOpacity activeOpacity={item.url ? 0.7 : 1} onPress={() => handleBannerPress(item)}>
                  <View style={styles.banner}>
                    <Image source={{ uri: item.imageUrl }} style={StyleSheet.absoluteFillObject} />
                    <View style={styles.bannerOverlay}>
                      <Text style={styles.bannerTitle}>{item.title || 'HOT LIVE STREAM'}</Text>
                      {item.url ? (
                        <View style={styles.watchBtn}>
                           {isStreamUrl(item.url) ? 
                             <Ionicons name="play" size={16} color="#fff" style={{marginRight: 8}}/> : 
                             <Ionicons name="open-outline" size={16} color="#fff" style={{marginRight: 8}}/>
                           }
                          <Text style={styles.watchBtnText}>{isStreamUrl(item.url) ? 'WATCH STREAM' : 'OPEN LINK'}</Text>
                        </View>
                      ) : null}
                    </View>
                  </View>
                </TouchableOpacity>
              )}
            />
          </View>
        )}

        {settings.showAds !== false && (
          <View style={{ paddingHorizontal: 15 }}>
            <UnityAdBanner />
          </View>
        )}

        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.categories}>
          {categories.map((cat, idx) => (
            <TouchableOpacity 
              key={idx} 
              style={[styles.catBtn, activeCategory === cat && styles.catActive]}
              onPress={() => setActiveCategory(cat)}
            >
              <Text style={[styles.catText, activeCategory === cat && styles.catTextActive]}>{cat}</Text>
            </TouchableOpacity>
          ))}
        </ScrollView>

        <View style={styles.gridSection}>
          <Text style={styles.sectionTitle}>Live Channels</Text>
          {loading ? (
            <ActivityIndicator size="large" color="#ff2d2d" style={{ marginTop: 50 }} />
          ) : filteredChannels.length > 0 ? (
            <FlatList 
              data={filteredChannels}
              renderItem={renderChannel}
              keyExtractor={item => item.id}
              numColumns={2}
              scrollEnabled={false}
            />
          ) : (
            <Text style={{color: '#666', textAlign: 'center', marginTop: 30}}>No channels available.</Text>
          )}
        </View>
      </ScrollView>

      {/* FLOATING TELEGRAM BUTTON */}
      {settings.telegramLink ? (
        <TouchableOpacity 
          style={styles.fabTelegram} 
          onPress={() => openSocial(settings.telegramLink)}
          activeOpacity={0.8}
        >
          <Ionicons name="paper-plane" size={28} color="#fff" />
        </TouchableOpacity>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0a0a0a' },
  header: { 
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', 
    padding: 20, paddingTop: 50, borderBottomWidth: 1, borderBottomColor: '#1a1a1a'
  },
  logoText: { fontSize: 24, fontWeight: 'bold', color: '#fff' },
  shareButton: { padding: 5 },
  searchContainer: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#1a1a1a', margin: 15, borderRadius: 10, borderWidth: 1, borderColor: '#333' },
  searchInput: { flex: 1, color: '#fff', padding: 12, fontSize: 16 },
  alertBanner: { backgroundColor: '#ff9900', flexDirection: 'row', padding: 12, alignItems: 'center', justifyContent: 'center' },
  alertText: { color: '#fff', fontWeight: 'bold', marginLeft: 10, textAlign: 'center' },
  bannerContainer: { height: 180, marginVertical: 15 },
  banner: {
    width: width - 30, height: 180, marginHorizontal: 15, backgroundColor: '#1a1a1a', borderRadius: 12,
    justifyContent: 'flex-end', alignItems: 'flex-start', borderColor: '#2a2a2a', borderWidth: 1,
    overflow: 'hidden'
  },
  bannerOverlay: { padding: 15, width: '100%', backgroundColor: 'rgba(0,0,0,0.6)' },
  bannerTitle: { color: '#fff', fontSize: 18, fontWeight: 'bold', marginBottom: 10 },
  watchBtn: { flexDirection: 'row', backgroundColor: '#ff2d2d', paddingVertical: 10, paddingHorizontal: 20, borderRadius: 25, alignItems: 'center', alignSelf: 'flex-start' },
  watchBtnText: { color: '#fff', fontWeight: 'bold' },
  categories: { flexDirection: 'row', paddingHorizontal: 15, paddingVertical: 10, paddingBottom: 20 },
  catBtn: { paddingHorizontal: 15, paddingVertical: 8, borderRadius: 20, backgroundColor: '#1a1a1a', marginRight: 10 },
  catActive: { backgroundColor: '#ff2d2d' },
  catText: { color: '#888', fontWeight: 'bold' },
  catTextActive: { color: '#fff', fontWeight: 'bold' },
  gridSection: { padding: 15, flex: 1, paddingBottom: 80 },
  sectionTitle: { color: '#fff', fontSize: 18, fontWeight: 'bold', marginBottom: 15 },
  card: { flex: 1, margin: 5, backgroundColor: '#1a1a1a', borderRadius: 12, overflow: 'hidden', borderWidth: 1, borderColor: '#2a2a2a' },
  thumbnail: { width: '100%', height: 100, resizeMode: 'cover' },
  cardInfo: { padding: 10 },
  cardTitle: { color: '#fff', fontSize: 14, fontWeight: 'bold' },
  badge: { color: '#888', fontSize: 12, marginTop: 4 },
  fabTelegram: {
    position: 'absolute', bottom: 25, right: 18,
    width: 52, height: 52, borderRadius: 26,
    backgroundColor: '#0088cc', alignItems: 'center', justifyContent: 'center',
    elevation: 8, shadowColor: '#000', shadowOffset: {width: 0, height: 4}, shadowOpacity: 0.4, shadowRadius: 4
  }
});
