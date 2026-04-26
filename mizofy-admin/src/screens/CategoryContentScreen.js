import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, Image, TextInput, Alert, Modal, ScrollView, ActivityIndicator } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { database } from '../firebaseConfig';
import { ref, onValue, remove, update, push } from 'firebase/database';
import { useRoute, useNavigation } from '@react-navigation/native';

export default function CategoryContentScreen() {
  const route = useRoute();
  const navigation = useNavigation();
  const { category } = route.params;
  const [channels, setChannels] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onValue(ref(database, 'channels'), (s) => {
      const data = s.val();
      setChannels(data ? Object.keys(data).map(k => ({ id: k, ...data[k] })).filter(c => c.category === category) : []);
      setLoading(false);
    });
    return () => unsubscribe();
  }, [category]);

  const deleteChannel = (id) => {
    Alert.alert("Delete", "Are you sure?", [
      { text: "No" }, { text: "Yes", onPress: () => remove(ref(database, `channels/${id}`)) }
    ]);
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}><Ionicons name="arrow-back" size={28} color="#fff" /></TouchableOpacity>
        <Text style={styles.title}>{category}</Text>
      </View>
      <FlatList 
        data={channels}
        renderItem={({ item }) => (
          <View style={styles.card}>
            <Image source={{ uri: item.thumbnail }} style={styles.img} />
            <View style={styles.info}>
              <Text style={styles.t}>{item.title}</Text>
              <Text style={styles.u} numberOfLines={1}>{item.url}</Text>
            </View>
            <TouchableOpacity onPress={() => deleteChannel(item.id)}><Ionicons name="trash-outline" size={24} color="#ff2d2d" /></TouchableOpacity>
          </View>
        )}
        keyExtractor={item => item.id}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0a0a0a' },
  header: { flexDirection: 'row', padding: 20, paddingTop: 50, backgroundColor: '#1a1a1a', alignItems: 'center' },
  title: { color: '#fff', fontSize: 20, fontWeight: 'bold', marginLeft: 15 },
  card: { flexDirection: 'row', padding: 10, backgroundColor: '#1a1a1a', margin: 10, borderRadius: 10, alignItems: 'center' },
  img: { width: 50, height: 50, borderRadius: 5 },
  info: { flex: 1, marginLeft: 15 },
  t: { color: '#fff', fontWeight: 'bold' },
  u: { color: '#666', fontSize: 10 }
});
