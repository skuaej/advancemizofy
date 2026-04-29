import React, { useState, useEffect, useRef, useCallback } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, Image, Share, ScrollView, ActivityIndicator, Dimensions, TextInput, Alert } from 'react-native';
import { useNavigation, useFocusEffect } from '@react-navigation/native';
import UnityAdBanner from '../components/UnityAdBanner';
import { Ionicons } from '@expo/vector-icons';
import { ref, onValue } from 'firebase/database';
import { database } from '../firebaseConfig';
import * as Linking from 'expo-linking';
import * as ScreenCapture from 'expo-screen-capture';
import * as Network from 'expo-network';
import * as Device from 'expo-device';

const { width } = Dimensions.get('window');

// Increment this natively when publishing new APKs
const CURRENT_APP_VERSION = 1;

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
  const carouselRef = useRef(null);

  useEffect(() => {
    if (!database) {
      setLoading(false);
      return;
    }

    try {
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

      const timeout = setTimeout(() => setLoading(false), 3000);

      return () => {
        clearTimeout(timeout);
        unsubscribeChannels();
        unsubscribeCategories();
        unsubscribeBanners();
        unsubscribeSettings();
        unsubscribeConfig();
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

  const handleBannerPress = (banner) => {
    if (!banner.url) return;
    // Check if it's an external web link or a live video stream
    if (banner.url.endsWith('.m3u8') || banner.url.endsWith('.ts')) {
      navigation.navigate('Player', { channel: { url: banner.url, title: banner.title } });
    } else {
      Linking.openURL(banner.url); // Open embedded WebView links directly in user's browser
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
  if (globalConfig.requiredVersion > CURRENT_APP_VERSION) {
    return (
      <View style={[styles.container, {justifyContent: 'center', alignItems: 'center', padding: 30}]}>
        <Ionicons name="cloud-download" size={80} color="#ff2d2d" />
        <Text style={{color: '#fff', fontSize: 24, fontWeight: 'bold', marginTop: 20}}>Update Required</Text>
        <Text style={{color: '#aaa', textAlign: 'center', marginTop: 10, marginBottom: 30}}>
          A new version of Mizofy TV is available. You must update to continue watching streams safely.
        </Text>
        <TouchableOpacity 
          style={{backgroundColor: '#ff2d2d', paddingVertical: 15, paddingHorizontal: 30, borderRadius: 25}}
          onPress={() => Linking.openURL(globalConfig.forceUpdateLink || 'http://ummotv.com')}
        >
          <Text style={{color: '#fff', fontWeight: 'bold'}}>DOWNLOAD LATEST APK</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {globalConfig.alertMsg ? (
        <View style={styles.alertBanner}>
          <Ionicons name="warning" size={20} color="#fff" />
          <Text style={styles.alertText}>{globalConfig.alertMsg}</Text>
        </View>
      ) : null}

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
                           {item.url.includes('.ts') || item.url.includes('.m3u8') ? 
                             <Ionicons name="play" size={16} color="#fff" style={{marginRight: 8}}/> : 
                             <Ionicons name="open-outline" size={16} color="#fff" style={{marginRight: 8}}/>
                           }
                          <Text style={styles.watchBtnText}>{item.url.includes('.ts') ? 'WATCH STREAM' : 'OPEN LINK'}</Text>
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
