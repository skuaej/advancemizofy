import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, TextInput, Alert, ActivityIndicator } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { database } from '../firebaseConfig';
import { ref, onValue, set, push, remove } from 'firebase/database';
import { useNavigation } from '@react-navigation/native';

export default function AdminScreen() {
  const navigation = useNavigation();
  const [stats, setStats] = useState({ users: 0, channels: 0, banners: 0 });
  const [categories, setCategories] = useState([]);
  const [newCat, setNewCat] = useState('');
  const [loading, setLoading] = useState(true);
  
  const [settings, setSettings] = useState({ telegramLink: '', whatsappLink: '', appShareLink: '' });
  const [globalConfig, setGlobalConfig] = useState({ alertMsg: '', forceUpdateLink: '', requiredVersion: 1 });

  useEffect(() => {
    onValue(ref(database, 'counters/visits'), (s) => setStats(prev => ({ ...prev, users: s.val() || 0 })));
    onValue(ref(database, 'channels'), (s) => setStats(prev => ({ ...prev, channels: s.val() ? Object.keys(s.val()).length : 0 })));
    onValue(ref(database, 'banners'), (s) => setStats(prev => ({ ...prev, banners: s.val() ? Object.keys(s.val()).length : 0 })));
    
    onValue(ref(database, 'categories'), (s) => {
      const data = s.val();
      setCategories(data ? Object.keys(data).map(key => ({ id: key, ...data[key] })) : []);
      setLoading(false);
    });

    onValue(ref(database, 'settings'), (s) => s.val() && setSettings(s.val()));
    onValue(ref(database, 'globalConfig'), (s) => s.val() && setGlobalConfig(s.val()));
  }, []);

  const addCategory = () => {
    if (!newCat.trim()) return;
    push(ref(database, 'categories'), { name: newCat.trim() });
    setNewCat('');
    Alert.alert("Success", "Category added!");
  };

  if (loading) return <View style={styles.centered}><ActivityIndicator size="large" color="#ff2d2d" /></View>;

  return (
    <ScrollView style={styles.container}>
      <View style={styles.headerRow}><Text style={styles.header}>Mizofy Admin</Text></View>
      <View style={styles.statsGrid}>
        <View style={styles.statBox}><Text style={styles.statNum}>{stats.users}</Text><Text style={styles.statLab}>Visits</Text></View>
        <View style={styles.statBox}><Text style={styles.statNum}>{stats.channels}</Text><Text style={styles.statLab}>Channels</Text></View>
        <View style={styles.statBox}><Text style={styles.statNum}>{stats.banners}</Text><Text style={styles.statLab}>Banners</Text></View>
      </View>
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Categories</Text>
        <View style={styles.inputRow}>
          <TextInput style={styles.input} placeholder="New Category" placeholderTextColor="#666" value={newCat} onChangeText={setNewCat} />
          <TouchableOpacity style={styles.addBtn} onPress={addCategory}><Ionicons name="add" size={24} color="#fff" /></TouchableOpacity>
        </View>
        {categories.map((cat) => (
          <TouchableOpacity key={cat.id} style={styles.catItem} onPress={() => navigation.navigate('CategoryContent', { category: cat.name })}>
            <Text style={styles.catName}>{cat.name}</Text>
            <Ionicons name="chevron-forward" size={20} color="#666" />
          </TouchableOpacity>
        ))}
      </View>
      <TouchableOpacity style={styles.saveBtn} onPress={() => {
          set(ref(database, 'settings'), settings);
          set(ref(database, 'globalConfig'), globalConfig);
          Alert.alert("Success", "Settings Saved");
      }}>
          <Text style={styles.saveBtnText}>SAVE ALL SETTINGS</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0a0a0a', padding: 15 },
  centered: { flex: 1, backgroundColor: '#0a0a0a', justifyContent: 'center', alignItems: 'center' },
  headerRow: { marginTop: 40, marginBottom: 20 },
  header: { color: '#fff', fontSize: 26, fontWeight: 'bold' },
  statsGrid: { flexDirection: 'row', gap: 10, marginBottom: 20 },
  statBox: { flex: 1, backgroundColor: '#1a1a1a', padding: 15, borderRadius: 12, alignItems: 'center' },
  statNum: { color: '#ff2d2d', fontSize: 20, fontWeight: 'bold' },
  statLab: { color: '#888', fontSize: 10, marginTop: 5 },
  card: { backgroundColor: '#1a1a1a', padding: 20, borderRadius: 12, marginBottom: 20 },
  cardTitle: { color: '#fff', fontSize: 18, fontWeight: 'bold', marginBottom: 15 },
  inputRow: { flexDirection: 'row', gap: 10, marginBottom: 15 },
  input: { flex: 1, backgroundColor: '#0a0a0a', color: '#fff', padding: 12, borderRadius: 8 },
  addBtn: { backgroundColor: '#ff2d2d', width: 48, height: 48, borderRadius: 8, justifyContent: 'center', alignItems: 'center' },
  catItem: { flexDirection: 'row', justifyContent: 'space-between', padding: 15, backgroundColor: '#0a0a0a', borderRadius: 8, marginBottom: 8 },
  catName: { color: '#fff', fontWeight: 'bold' },
  saveBtn: { backgroundColor: '#ff2d2d', padding: 15, borderRadius: 10, alignItems: 'center' },
  saveBtnText: { color: '#fff', fontWeight: 'bold' }
});
