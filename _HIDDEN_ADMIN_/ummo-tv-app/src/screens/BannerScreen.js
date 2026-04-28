import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, Image, TextInput, Alert, Modal, ScrollView, ActivityIndicator } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { database } from '../firebaseConfig';
import { ref, onValue, remove, push, update } from 'firebase/database';
import * as ImagePicker from 'expo-image-picker';

export default function BannerScreen() {
  const [banners, setBanners] = useState([]);
  const [modalVisible, setModalVisible] = useState(false);
  const [newBanner, setNewBanner] = useState({ imageUrl: '', url: '', title: '' });
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!database) return;
    const unsub = onValue(ref(database, 'banners'), (s) => {
      const data = s.val();
      setBanners(data ? Object.keys(data).map(k => ({ id: k, ...data[k] })) : []);
    });
    return () => unsub();
  }, []);

  const pickImage = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      quality: 0.5,
    });

    if (!result.canceled) {
      setNewBanner({ ...newBanner, imageUrl: result.assets[0].uri });
    }
  };

  const addBanner = () => {
    if (!newBanner.imageUrl) {
      Alert.alert("Error", "Please select an image");
      return;
    }
    push(ref(database, 'banners'), newBanner);
    setNewBanner({ imageUrl: '', url: '', title: '' });
    setModalVisible(false);
  };

  const deleteBanner = (id) => {
    Alert.alert("Delete", "Remove this banner?", [
      { text: "Cancel" },
      { text: "Delete", onPress: () => remove(ref(database, `banners/${id}`)) }
    ]);
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Manage Banners</Text>
        <TouchableOpacity onPress={() => setModalVisible(true)}>
          <Ionicons name="add-circle" size={32} color="#ff2d2d" />
        </TouchableOpacity>
      </View>

      <FlatList
        data={banners}
        renderItem={({ item }) => (
          <View style={styles.bannerCard}>
            <Image source={{ uri: item.imageUrl }} style={styles.bannerImg} />
            <View style={styles.bannerInfo}>
              <Text style={styles.bannerTitle}>{item.title || 'Untitled Banner'}</Text>
              <Text style={styles.bannerLink} numberOfLines={1}>{item.url || 'No Link'}</Text>
            </View>
            <TouchableOpacity onPress={() => deleteBanner(item.id)}>
              <Ionicons name="trash-outline" size={24} color="#ff2d2d" />
            </TouchableOpacity>
          </View>
        )}
        keyExtractor={item => item.id}
      />

      <Modal visible={modalVisible} animationType="slide" transparent={true}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalHeader}>Add New Banner</Text>
            
            <TouchableOpacity style={styles.imagePicker} onPress={pickImage}>
              {newBanner.imageUrl ? (
                <Image source={{ uri: newBanner.imageUrl }} style={styles.previewImg} />
              ) : (
                <View style={styles.pickerPlaceholder}>
                  <Ionicons name="camera-outline" size={40} color="#666" />
                  <Text style={styles.pickerText}>Select Banner Image</Text>
                </View>
              )}
            </TouchableOpacity>

            <TextInput
              style={styles.input}
              placeholder="Banner Title (Optional)"
              placeholderTextColor="#666"
              value={newBanner.title}
              onChangeText={t => setNewBanner({...newBanner, title: t})}
            />

            <TextInput
              style={styles.input}
              placeholder="Action Link / Category Name"
              placeholderTextColor="#666"
              value={newBanner.url}
              onChangeText={t => setNewBanner({...newBanner, url: t})}
            />

            <View style={styles.modalBtns}>
              <TouchableOpacity style={styles.cancelBtn} onPress={() => setModalVisible(false)}>
                <Text style={styles.btnText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.submitBtn} onPress={addBanner}>
                <Text style={styles.btnText}>Add Banner</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0a0a0a', padding: 15 },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: 40, marginBottom: 20 },
  title: { color: '#fff', fontSize: 24, fontWeight: 'bold' },
  bannerCard: { flexDirection: 'row', backgroundColor: '#1a1a1a', borderRadius: 12, padding: 12, marginBottom: 15, alignItems: 'center' },
  bannerImg: { width: 80, height: 45, borderRadius: 6 },
  bannerInfo: { flex: 1, marginLeft: 15 },
  bannerTitle: { color: '#fff', fontWeight: 'bold' },
  bannerLink: { color: '#666', fontSize: 12 },
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.8)', justifyContent: 'center', padding: 20 },
  modalContent: { backgroundColor: '#1a1a1a', borderRadius: 20, padding: 20 },
  modalHeader: { color: '#fff', fontSize: 20, fontWeight: 'bold', marginBottom: 20, textAlign: 'center' },
  imagePicker: { width: '100%', height: 150, backgroundColor: '#0a0a0a', borderRadius: 12, justifyContent: 'center', alignItems: 'center', marginBottom: 15, overflow: 'hidden' },
  previewImg: { width: '100%', height: '100%' },
  pickerPlaceholder: { alignItems: 'center' },
  pickerText: { color: '#666', marginTop: 10 },
  input: { backgroundColor: '#0a0a0a', color: '#fff', padding: 15, borderRadius: 10, marginBottom: 15 },
  modalBtns: { flexDirection: 'row', gap: 10 },
  cancelBtn: { flex: 1, backgroundColor: '#333', padding: 15, borderRadius: 10, alignItems: 'center' },
  submitBtn: { flex: 1, backgroundColor: '#ff2d2d', padding: 15, borderRadius: 10, alignItems: 'center' },
  btnText: { color: '#fff', fontWeight: 'bold' }
});
