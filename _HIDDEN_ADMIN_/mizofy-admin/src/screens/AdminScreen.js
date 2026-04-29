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
  
  const [settings, setSettings] = useState({ telegramLink: '', whatsappLink: '', appShareLink: '' });
  const [globalConfig, setGlobalConfig] = useState({ alertMsg: '', forceUpdateLink: '', requiredVersion: 1 });

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
      onValue(ref(database, 'globalConfig'), (s) => s.val() && setGlobalConfig(s.val()));
    } catch (e) { console.warn(e); setLoading(false); }
  }, []);

  const addCategory = () => {
    if (!newCat.trim()) return;
    const nextOrder = categories.length > 0 ? Math.max(...categories.map(c => c.order || 0)) + 1 : 0;
    push(ref(database, 'categories'), { name: newCat.trim(), order: nextOrder });
    setNewCat('');
    Alert.alert("Success", "Category added!");
  };

  const saveConfig = () => {
    set(ref(database, 'globalConfig'), globalConfig);
    set(ref(database, 'settings'), settings);
    Alert.alert("Success", "Configuration Saved!");
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

  const filteredCategories = categories.filter(c => c.name.toLowerCase().includes(searchQuery.toLowerCase()));

  if (loading) return <View style={styles.centered}><ActivityIndicator size="large" color="#ff2d2d" /></View>;

  return (
    <ScrollView style={styles.container}>
      <View style={styles.headerRow}>
        <Text style={styles.header}>HaMizMizofy Admin
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
        
        <Text style={styles.label}>Scrolling Alert Message</Text>
        <TextInput 
          style={styles.input} 
          value={globalConfig.alertMsg} 
          onChangeText={t => setGlobalConfig({...globalConfig, alertMsg: t})} 
        />

        <View style={styles.inputRow}>
          <View style={{flex: 1}}>
            <Text style={styles.label}>Force Update Link</Text>
            <TextInput 
              style={styles.input} 
              value={globalConfig.forceUpdateLink} 
              onChangeText={t => setGlobalConfig({...globalConfig, forceUpdateLink: t})} 
            />
          </View>
          <View style={{width: 80}}>
            <Text style={styles.label}>Req Ver</Text>
            <TextInput 
              style={styles.input} 
              keyboardType="numeric"
              value={String(globalConfig.requiredVersion || 1)} 
              onChangeText={t => setGlobalConfig({...globalConfig, requiredVersion: parseInt(t) || 1})} 
            />
          </View>
        </View>

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
