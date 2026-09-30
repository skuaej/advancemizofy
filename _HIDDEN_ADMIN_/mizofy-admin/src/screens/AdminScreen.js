import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, TextInput, Alert, ActivityIndicator } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { database } from '../firebaseConfig';
import { ref, onValue, set, push, update, remove } from 'firebase/database';
import { useNavigation } from '@react-navigation/native';

export default function AdminScreen() {
  const navigation = useNavigation();
  const [stats, setStats] = useState({ users: 0, channels: 0, banners: 0 });
  const [categories, setCategories] = useState([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [newCat, setNewCat] = useState('');
  const [editingCatId, setEditingCatId] = useState(null);
  const [editCatName, setEditCatName] = useState('');
  const [loading, setLoading] = useState(true);
  
  const [settings, setSettings] = useState({ telegramLink: '', whatsappLink: '', appShareLink: '', showAds: true });
  const [globalConfig, setGlobalConfig] = useState({ alertMsg: '', forceUpdateLink: '', requiredVersion: 1, forceUpdateActive: false });

  useEffect(() => {
    if (!database) { setLoading(false); return; }
    try {
      onValue(ref(database, 'counters/visits'), (s) => setStats(prev => ({ ...prev, users: s.val() || 0 })));
      onValue(ref(database, 'channels'), (s) => setStats(prev => ({ ...prev, channels: s.val() ? Object.keys(s.val()).length : 0 })));
      onValue(ref(database, 'banners'), (s) => setStats(prev => ({ ...prev, banners: s.val() ? Object.keys(s.val()).length : 0 })));
      onValue(ref(database, 'categories'), (s) => {
        const data = s.val();
        const list = data ? Object.keys(data).map(key => ({ id: key, ...data[key] })) : [];
        setCategories(list.sort((a, b) => (a.order || 0) - (b.order || 0)));
        setLoading(false);
      });
      onValue(ref(database, 'settings'), (s) => s.val() && setSettings(s.val()));
      onValue(ref(database, 'globalConfig'), (s) => {
        const val = s.val();
        if (val) {
          setGlobalConfig(prev => ({
            ...prev,
            ...val,
            requiredVersion: val.requiredVersion !== undefined ? val.requiredVersion : 2,
            forceUpdateActive: val.forceUpdateActive === true
          }));
        }
      });
    } catch (e) { console.warn(e); setLoading(false); }
  }, []);

  const addCategory = () => {
    if (!newCat.trim()) return;
    const nextOrder = categories.length > 0 ? Math.max(...categories.map(c => c.order || 0)) + 1 : 0;
    push(ref(database, 'categories'), { name: newCat.trim(), order: nextOrder });
    setNewCat('');
    Alert.alert("Success", "Category added!");
  };

  const sendForceUpdateNotificationNow = () => {
    const targetVer = parseInt(globalConfig.requiredVersion, 10) || 2;
    const notif = {
      title: "🔥 Mizofy TV Update Required!",
      message: `Version ${targetVer}.0 is now available. Please update Mizofy TV to continue watching!`,
      version: targetVer,
      isForceUpdate: true,
      timestamp: Date.now()
    };
    set(ref(database, 'latestNotification'), notif);
    push(ref(database, 'notifications'), notif);
    Alert.alert("Notification Sent", `Broadcast update notification for v${targetVer}.0 has been sent to all users!`);
  };

  const saveConfig = () => {
    const isLocked = Boolean(globalConfig.forceUpdateActive);
    const targetVer = Math.max(1, parseInt(globalConfig.requiredVersion, 10) || 1);

    const configToSave = {
      ...globalConfig,
      requiredVersion: targetVer,
      forceUpdateActive: isLocked,
      forceUpdateLink: (globalConfig.forceUpdateLink || '').trim(),
      alertMsg: (globalConfig.alertMsg || '').trim(),
    };

    set(ref(database, 'globalConfig'), configToSave);
    set(ref(database, 'settings'), settings);

    // If update is activated, automatically send native push notification to users
    if (isLocked) {
      const notif = {
        title: "🔥 Mizofy TV Update Required!",
        message: `Version ${targetVer}.0 is required. Please update to continue watching!`,
        version: targetVer,
        isForceUpdate: true,
        timestamp: Date.now()
      };
      set(ref(database, 'latestNotification'), notif);
      push(ref(database, 'notifications'), notif);
    }

    Alert.alert(
      "Settings Saved",
      isLocked 
        ? `Force update is ACTIVE for v${targetVer}.0. Notification sent to users!` 
        : "Configuration Saved!"
    );
  };

  const clearAlertMsg = () => {
    setGlobalConfig(prev => ({ ...prev, alertMsg: '' }));
    update(ref(database, 'globalConfig'), { alertMsg: '' });
    Alert.alert("Cleared", "Alert message removed from all users!");
  };

  const updateCategory = async () => {
    if (!editCatName.trim() || !editingCatId) return;
    
    const oldCatName = categories.find(c => c.id === editingCatId)?.name;
    const newCatName = editCatName.trim();

    // 1. Update the category name
    await update(ref(database, `categories/${editingCatId}`), { name: newCatName });

    // 2. Update all channels that used the old category name
    if (oldCatName && oldCatName !== newCatName) {
      onValue(ref(database, 'channels'), (snapshot) => {
        const channels = snapshot.val();
        if (channels) {
          const updates = {};
          Object.keys(channels).forEach(key => {
            if (channels[key].category === oldCatName) {
              updates[`channels/${key}/category`] = newCatName;
            }
          });
          if (Object.keys(updates).length > 0) {
            update(ref(database), updates);
          }
        }
      }, { onlyOnce: true });
    }

    setEditingCatId(null); setEditCatName('');
    Alert.alert('Success', 'Category and associated channels updated!');
  };

  const moveCategory = async (index, direction) => {
    const newCategories = [...categories];
    const targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= newCategories.length) return;

    // Swap orders
    const current = newCategories[index];
    const target = newCategories[targetIndex];
    
    const currentOrder = current.order || 0;
    const targetOrder = target.order || 0;

    await update(ref(database, `categories/${current.id}`), { order: targetOrder });
    await update(ref(database, `categories/${target.id}`), { order: currentOrder });
  };

  const deleteCategory = (id) => {
    Alert.alert(
      "Delete Category",
      "Are you sure? This will not delete channels, but they will become uncategorized.",
      [
        { text: "Cancel", style: "cancel" },
        { text: "Delete", style: "destructive", onPress: () => remove(ref(database, `categories/${id}`)) }
      ]
    );
  };

  const filteredCategories = categories.filter(c => c.name.toLowerCase().includes(searchQuery.toLowerCase()));

  if (loading) return <View style={styles.centered}><ActivityIndicator size="large" color="#ff2d2d" /></View>;

  return (
    <ScrollView style={styles.container}>
      <View style={styles.headerRow}>
        <Text style={styles.header}>Mizofy Admin</Text>
        <TouchableOpacity onPress={() => navigation.replace('Login')}>
           <Ionicons name="log-out-outline" size={26} color="#666" />
        </TouchableOpacity>
      </View>

      <View style={styles.statsGrid}>
        <View style={styles.statBox}><Text style={styles.statNum}>{stats.users}</Text><Text style={styles.statLab}>Visits</Text></View>
        <View style={styles.statBox}><Text style={styles.statNum}>{stats.channels}</Text><Text style={styles.statLab}>Channels</Text></View>
        <View style={styles.statBox}><Text style={styles.statNum}>{stats.banners}</Text><Text style={styles.statLab}>Banners</Text></View>
      </View>

      {/* QUICK ACTIONS GRID */}
      <View style={styles.actionGrid}>
         <TouchableOpacity style={styles.actionItem} onPress={() => navigation.navigate('Banners')}>
            <Ionicons name="images-outline" size={28} color="#ff2d2d" />
            <Text style={styles.actionText}>Banners</Text>
         </TouchableOpacity>
         <TouchableOpacity style={styles.actionItem} onPress={() => navigation.navigate('Notifications')}>
            <Ionicons name="notifications-outline" size={28} color="#ff2d2d" />
            <Text style={styles.actionText}>Notif</Text>
         </TouchableOpacity>
         <View style={styles.actionItem}>
            <Ionicons name="people-outline" size={28} color="#ff2d2d" />
            <Text style={styles.actionText}>{stats.users}</Text>
         </View>
      </View>

      {/* UPDATE TO USER PANEL */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Global Settings & Socials</Text>
        
        <View style={{flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 5}}>
          <Text style={[styles.label, {marginBottom: 0}]}>Scrolling Alert Message</Text>
          {globalConfig.alertMsg ? (
            <TouchableOpacity onPress={clearAlertMsg} style={{backgroundColor: '#ff2d2d', paddingHorizontal: 8, paddingVertical: 3, borderRadius: 5}}>
              <Text style={{color: '#fff', fontSize: 11, fontWeight: 'bold'}}>Clear / Delete</Text>
            </TouchableOpacity>
          ) : null}
        </View>
        <TextInput 
          style={styles.input} 
          value={globalConfig.alertMsg} 
          placeholder="Leave empty or click Clear to delete"
          placeholderTextColor="#444"
          onChangeText={t => setGlobalConfig({...globalConfig, alertMsg: t})} 
        />

        <Text style={styles.label}>Force Update APK Download Link (Direct or Mediafire Link)</Text>
        <TextInput 
          style={styles.input} 
          placeholder="Paste Mediafire or direct APK link"
          placeholderTextColor="#444"
          value={globalConfig.forceUpdateLink} 
          onChangeText={t => setGlobalConfig(prev => ({ ...prev, forceUpdateLink: t }))} 
        />

        <Text style={styles.label}>Target / Required App Version (Version Code)</Text>
        <TextInput 
          style={styles.input} 
          placeholder="e.g. 2, 3, 4..."
          placeholderTextColor="#444"
          keyboardType="numeric"
          value={String(globalConfig.requiredVersion !== undefined ? globalConfig.requiredVersion : '')} 
          onChangeText={t => {
            const clean = t.replace(/[^0-9]/g, '');
            setGlobalConfig(prev => ({ ...prev, requiredVersion: clean }));
          }} 
        />
        <Text style={{color: '#888', fontSize: 11, marginTop: -8, marginBottom: 15}}>
          Current installed apps are on v2. Set this to 3 or higher when you want to force users to update to a new APK.
        </Text>

        {/* FORCE UPDATE TOGGLE */}
        <View style={{flexDirection: 'row', alignItems: 'center', backgroundColor: globalConfig.forceUpdateActive ? '#260808' : '#141414', padding: 14, borderRadius: 10, borderWidth: 1, borderColor: globalConfig.forceUpdateActive ? '#ff2d2d' : '#333', marginBottom: 12}}>
          <View style={{flex: 1, paddingRight: 10}}>
            <Text style={{color: globalConfig.forceUpdateActive ? '#ff4d4d' : '#888', fontWeight: 'bold', fontSize: 13}}>
              {globalConfig.forceUpdateActive ? '🚨 FORCE UPDATE IS ENABLED (LOCKED)' : '✅ FORCE UPDATE IS DISABLED (NORMAL)'}
            </Text>
            <Text style={{color: '#aaa', fontSize: 11, marginTop: 3}}>
              {globalConfig.forceUpdateActive 
                ? `Apps below version ${globalConfig.requiredVersion || 2} will be blocked until updated.` 
                : 'All users have normal access. No update prompt shown.'}
            </Text>
          </View>
          <TouchableOpacity 
            style={{width: 52, height: 32, backgroundColor: globalConfig.forceUpdateActive ? '#ff2d2d' : '#333', borderRadius: 16, justifyContent: 'center', paddingHorizontal: 4}}
            onPress={() => {
              setGlobalConfig(prev => ({
                ...prev,
                forceUpdateActive: !prev.forceUpdateActive
              }));
            }}
          >
            <View style={{width: 24, height: 24, backgroundColor: '#fff', borderRadius: 12, alignSelf: globalConfig.forceUpdateActive ? 'flex-end' : 'flex-start'}} />
          </TouchableOpacity>
        </View>

        {/* BROADCAST NOTIFICATION BUTTON */}
        <TouchableOpacity 
          style={{backgroundColor: '#991111', padding: 12, borderRadius: 10, flexDirection: 'row', justifyContent: 'center', alignItems: 'center', marginBottom: 20}}
          onPress={sendForceUpdateNotificationNow}
        >
          <Ionicons name="megaphone-outline" size={18} color="#fff" style={{marginRight: 8}} />
          <Text style={{color: '#fff', fontWeight: 'bold', fontSize: 12}}>SEND UPDATE NOTIFICATION TO USERS NOW</Text>
        </TouchableOpacity>

        <Text style={styles.label}>Telegram Channel Link</Text>
        <TextInput 
          style={styles.input} 
          value={settings.telegramLink} 
          onChangeText={t => setSettings({...settings, telegramLink: t})} 
        />

        <Text style={styles.label}>WhatsApp Support Link</Text>
        <TextInput 
          style={styles.input} 
          value={settings.whatsappLink} 
          onChangeText={t => setSettings({...settings, whatsappLink: t})} 
        />

        <Text style={styles.label}>App Share Link</Text>
        <TextInput 
          style={styles.input} 
          value={settings.appShareLink} 
          onChangeText={t => setSettings({...settings, appShareLink: t})} 
        />

        <View style={{flexDirection: 'row', alignItems: 'center', marginBottom: 20}}>
          <Text style={[styles.label, {flex: 1, marginBottom: 0}]}>Show Unity Ads in User App</Text>
          <TouchableOpacity 
            style={{width: 50, height: 30, backgroundColor: settings.showAds !== false ? '#4CAF50' : '#444', borderRadius: 15, justifyContent: 'center', paddingHorizontal: 5}}
            onPress={() => setSettings({...settings, showAds: settings.showAds === false ? true : false})}
          >
            <View style={{width: 20, height: 20, backgroundColor: '#fff', borderRadius: 10, alignSelf: settings.showAds !== false ? 'flex-end' : 'flex-start'}} />
          </TouchableOpacity>
        </View>

        <TouchableOpacity style={styles.saveBtn} onPress={saveConfig}>
          <Text style={styles.saveBtnText}>SAVE & PUSH ALL SETTINGS</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Manage Categories</Text>
        
        {/* SEARCH CATEGORIES */}
        <View style={styles.searchBox}>
          <Ionicons name="search" size={20} color="#666" />
          <TextInput 
             style={styles.searchInput} 
             placeholder="Search Categories..." 
             placeholderTextColor="#666"
             value={searchQuery}
             onChangeText={setSearchQuery}
          />
        </View>

        <View style={styles.inputRow}>
          <TextInput style={[styles.input, {flex: 1, marginBottom: 0}]} placeholder="New Name" placeholderTextColor="#444" value={newCat} onChangeText={setNewCat} />
          <TouchableOpacity style={styles.addBtn} onPress={addCategory}><Ionicons name="add" size={24} color="#fff" /></TouchableOpacity>
        </View>

        <View style={{ maxHeight: 400 }}>
          <ScrollView nestedScrollEnabled={true}>
            {filteredCategories.map((cat, index) => (
              <View key={cat.id} style={styles.catItem}>
                {editingCatId === cat.id ? (
                  <TextInput style={[styles.input, {flex: 1, marginBottom: 0}]} value={editCatName} onChangeText={setEditCatName} autoFocus />
                ) : (
                  <TouchableOpacity style={{flex: 1}} onPress={() => navigation.navigate('CategoryContent', { category: cat.name })}>
                    <Text style={styles.catName}>{cat.name}</Text>
                  </TouchableOpacity>
                )}
                <View style={{flexDirection: 'row', gap: 12, alignItems: 'center'}}>
                  <TouchableOpacity onPress={() => moveCategory(index, -1)} disabled={index === 0}>
                    <Ionicons name="chevron-up" size={20} color={index === 0 ? "#222" : "#888"} />
                  </TouchableOpacity>
                  <TouchableOpacity onPress={() => moveCategory(index, 1)} disabled={index === categories.length - 1}>
                    <Ionicons name="chevron-down" size={20} color={index === categories.length - 1 ? "#222" : "#888"} />
                  </TouchableOpacity>
                  
                  {editingCatId === cat.id ? (
                    <TouchableOpacity onPress={updateCategory}><Ionicons name="checkmark" size={24} color="#4CAF50" /></TouchableOpacity>
                  ) : (
                    <TouchableOpacity onPress={() => {setEditingCatId(cat.id); setEditCatName(cat.name);}}><Ionicons name="create-outline" size={20} color="#fff" /></TouchableOpacity>
                  )}
                  <TouchableOpacity onPress={() => deleteCategory(cat.id)}>
                    <Ionicons name="trash-outline" size={20} color="#ff2d2d" />
                  </TouchableOpacity>
                </View>
              </View>
            ))}
          </ScrollView>
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000', padding: 15 },
  centered: { flex: 1, backgroundColor: '#000', justifyContent: 'center', alignItems: 'center' },
  headerRow: { marginTop: 40, marginBottom: 20, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  header: { color: '#fff', fontSize: 28, fontWeight: 'bold' },
  statsGrid: { flexDirection: 'row', gap: 10, marginBottom: 20 },
  statBox: { flex: 1, backgroundColor: '#111', padding: 15, borderRadius: 12, alignItems: 'center', borderWidth: 1, borderColor: '#222' },
  statNum: { color: '#ff2d2d', fontSize: 22, fontWeight: 'bold' },
  statLab: { color: '#888', fontSize: 11, marginTop: 5 },
  actionGrid: { flexDirection: 'row', gap: 10, marginBottom: 20 },
  actionItem: { flex: 1, backgroundColor: '#111', padding: 15, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  actionText: { color: '#fff', fontSize: 12, marginTop: 5, fontWeight: 'bold' },
  card: { backgroundColor: '#111', padding: 20, borderRadius: 15, marginBottom: 20 },
  cardTitle: { color: '#fff', fontSize: 18, fontWeight: 'bold', marginBottom: 15 },
  label: { color: '#666', fontSize: 12, marginBottom: 5 },
  inputRow: { flexDirection: 'row', gap: 10, marginBottom: 15 },
  searchBox: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#000', paddingHorizontal: 15, borderRadius: 10, marginBottom: 15, borderWidth: 1, borderColor: '#222' },
  searchInput: { flex: 1, color: '#fff', height: 45, marginLeft: 10 },
  input: { backgroundColor: '#000', color: '#fff', padding: 12, borderRadius: 8, borderWidth: 1, borderColor: '#222', marginBottom: 15 },
  addBtn: { backgroundColor: '#ff2d2d', width: 48, height: 48, borderRadius: 8, justifyContent: 'center', alignItems: 'center' },
  catItem: { flexDirection: 'row', justifyContent: 'space-between', padding: 15, backgroundColor: '#000', borderRadius: 10, marginBottom: 8, alignItems: 'center' },
  catName: { color: '#fff', fontWeight: 'bold', fontSize: 16 },
  saveBtn: { backgroundColor: '#ff2d2d', padding: 15, borderRadius: 12, alignItems: 'center', marginTop: 10 },
  saveBtnText: { color: '#fff', fontWeight: 'bold', fontSize: 16 }
});
