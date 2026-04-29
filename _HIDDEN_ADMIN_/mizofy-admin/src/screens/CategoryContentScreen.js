import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, Image, TextInput, Alert, Modal, ScrollView, ActivityIndicator } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { database } from '../firebaseConfig';
import { ref, onValue, remove, update, push } from 'firebase/database';
import { useRoute, useNavigation } from '@react-navigation/native';
import * as ImagePicker from 'expo-image-picker';

export default function CategoryContentScreen() {
  const route = useRoute();
  const navigation = useNavigation();
  const { category } = route.params;
  
  const [channels, setChannels] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalVisible, setModalVisible] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [m3uModal, setM3uModal] = useState(false);
  const [m3uUrl, setM3uUrl] = useState('');
  const [swapSelectedId, setSwapSelectedId] = useState(null);
  const [bulkAddModal, setBulkAddModal] = useState(false);
  const [bulkAddText, setBulkAddText] = useState('');
  
  // Bulk Selection State
  const [selectedIds, setSelectedIds] = useState([]);
  const [isSelectionMode, setIsSelectionMode] = useState(false);
  const [moveModalVisible, setMoveModalVisible] = useState(false);
  const [categories, setCategories] = useState([]);

  const [form, setForm] = useState({
    title: '',
    url: '',
    thumbnail: '',
    type: 'auto', // auto, stream, youtube, embed
    episode: '',
  });

  useEffect(() => {
    if (!database) return;
    const unsubscribe = onValue(ref(database, 'channels'), (s) => {
      const data = s.val();
      const list = data ? Object.keys(data).map(k => ({ id: k, ...data[k] })).filter(c => c.category === category) : [];
      setChannels(list.sort((a, b) => (a.order || 0) - (b.order || 0)));
      setLoading(false);
    });

    // Fetch categories for "Move to Category" feature
    onValue(ref(database, 'categories'), (s) => {
      const data = s.val();
      if (data) setCategories(Object.keys(data).map(k => data[k].name));
    });

    return () => unsubscribe();
  }, [category]);

  const toggleSelection = (id) => {
    if (selectedIds.includes(id)) {
      const newSelected = selectedIds.filter(i => i !== id);
      setSelectedIds(newSelected);
      if (newSelected.length === 0) setIsSelectionMode(false);
    } else {
      setSelectedIds([...selectedIds, id]);
      setIsSelectionMode(true);
    }
  };

  const handleLongPress = (id) => {
    if (!isSelectionMode) {
      setIsSelectionMode(true);
      setSelectedIds([id]);
    }
  };

  const bulkDelete = () => {
    Alert.alert("Bulk Delete", `Delete ${selectedIds.length} selected channels?`, [
      { text: "Cancel" },
      { text: "Delete All", style: 'destructive', onPress: async () => {
        const updates = {};
        selectedIds.forEach(id => {
          updates[`channels/${id}`] = null;
        });
        await update(ref(database), updates);
        setSelectedIds([]);
        setIsSelectionMode(false);
        Alert.alert("Success", "Channels deleted");
      }}
    ]);
  };

  const bulkMove = async (targetCategory) => {
    if (targetCategory === category) {
      setMoveModalVisible(false);
      return;
    }
    const updates = {};
    selectedIds.forEach(id => {
      updates[`channels/${id}/category`] = targetCategory;
    });
    await update(ref(database), updates);
    setSelectedIds([]);
    setIsSelectionMode(false);
    setMoveModalVisible(false);
    Alert.alert("Success", `Moved ${selectedIds.length} channels to ${targetCategory}`);
  };

  const filteredChannels = channels.filter(c => 
    c.title.toLowerCase().includes(searchQuery.toLowerCase()) || 
    c.url.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const pickImage = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.5,
    });
    if (!result.canceled) {
      setForm({ ...form, thumbnail: result.assets[0].uri });
    }
  };

  const handleSave = () => {
    if (!form.title || !form.url) {
      Alert.alert("Error", "Title and URL are required");
      return;
    }

    const channelData = { ...form, category };
    if (!editingId) {
      channelData.order = channels.length > 0 ? Math.max(...channels.map(c => c.order || 0)) + 1 : 0;
    }

    if (editingId) {
      update(ref(database, `channels/${editingId}`), channelData);
      Alert.alert("Success", "Channel updated!");
    } else {
      push(ref(database, 'channels'), channelData);
      Alert.alert("Success", "Channel added!");
    }

    setModalVisible(false);
    setForm({ title: '', url: '', thumbnail: '', type: 'auto', episode: '' });
    setEditingId(null);
  };

  const editChannel = (item) => {
    if (isSelectionMode) {
      toggleSelection(item.id);
      return;
    }
    setEditingId(item.id);
    setForm({
      title: item.title,
      url: item.url,
      thumbnail: item.thumbnail || '',
      type: item.type || 'auto',
      episode: item.episode || '',
    });
    setModalVisible(true);
  };

  const deleteChannel = (id) => {
    Alert.alert("Delete", "Remove this channel?", [
      { text: "Cancel" },
      { text: "Delete", style: 'destructive', onPress: () => remove(ref(database, `channels/${id}`)) }
    ]);
  };

  const handleSwap = async (channel) => {
    if (!swapSelectedId) {
      setSwapSelectedId(channel.id);
    } else if (swapSelectedId === channel.id) {
      setSwapSelectedId(null);
    } else {
      // Perform the swap
      const sourceChannel = channels.find(c => c.id === swapSelectedId);
      const targetChannel = channel;

      if (sourceChannel && targetChannel) {
        const sourceOrder = sourceChannel.order !== undefined ? sourceChannel.order : channels.indexOf(sourceChannel);
        const targetOrder = targetChannel.order !== undefined ? targetChannel.order : channels.indexOf(targetChannel);

        await update(ref(database, `channels/${sourceChannel.id}`), { order: targetOrder });
        await update(ref(database, `channels/${targetChannel.id}`), { order: sourceOrder });
      }
      setSwapSelectedId(null);
      Alert.alert("Success", "Positions swapped!");
    }
  };

  const moveChannel = async (index, direction) => {
    const targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= channels.length) return;

    const current = channels[index];
    const target = channels[targetIndex];
    
    // If they have the same order or no order, re-index the whole category list
    if (current.order === target.order || current.order === undefined || target.order === undefined) {
      const updates = {};
      channels.forEach((chan, i) => {
        let newOrder = i;
        if (i === index) newOrder = targetIndex;
        else if (i === targetIndex) newOrder = index;
        updates[`channels/${chan.id}/order`] = newOrder;
      });
      await update(ref(database), updates);
    } else {
      const currentOrder = current.order;
      const targetOrder = target.order;
      await update(ref(database, `channels/${current.id}`), { order: targetOrder });
      await update(ref(database, `channels/${target.id}`), { order: currentOrder });
    }
  };

  const handleM3UImport = () => {
    setM3uUrl('');
    setM3uModal(true);
  };

  const fetchAndParseM3U = async () => {
    if (!m3uUrl) return;
    setLoading(true);
    setM3uModal(false);
    try {
      const response = await fetch(m3uUrl);
      const text = await response.text();
      const lines = text.split('\n');
      let count = 0;
      let maxOrder = channels.length > 0 ? Math.max(...channels.map(c => c.order || 0)) : -1;

      for (let i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('#EXTINF:')) {
          const info = lines[i];
          const streamUrl = lines[i + 1]?.trim();
          if (streamUrl && !streamUrl.startsWith('#')) {
            // Regex to extract title and logo
            const titleMatch = info.match(/,(.*)$/);
            const logoMatch = info.match(/tvg-logo="(.*?)"/);
            
            const title = titleMatch ? titleMatch[1].trim() : 'Untitled';
            const thumbnail = logoMatch ? logoMatch[1] : '';

            push(ref(database, 'channels'), {
              title,
              url: streamUrl,
              thumbnail,
              category,
              type: 'auto',
              episode: '',
              order: ++maxOrder
            });
            count++;
            i++; // skip next line as we used it as streamUrl
          }
        }
      }
      Alert.alert("Import Success", `Successfully imported ${count} channels into ${category}`);
    } catch (e) {
      Alert.alert("Error", "Failed to fetch M3U. Ensure URL is correct.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="arrow-back" size={28} color="#fff" />
        </TouchableOpacity>
        <Text style={styles.title}>{category}</Text>
        <View style={{flexDirection: 'row', gap: 10}}>
          {isSelectionMode ? (
            <>
              <TouchableOpacity onPress={() => setMoveModalVisible(true)}>
                <Ionicons name="move" size={28} color="#4FC3F7" />
              </TouchableOpacity>
              <TouchableOpacity onPress={bulkDelete}>
                <Ionicons name="trash" size={28} color="#ff2d2d" />
              </TouchableOpacity>
              <TouchableOpacity onPress={() => setIsSelectionMode(false)}>
                <Ionicons name="close-circle" size={28} color="#fff" />
              </TouchableOpacity>
            </>
          ) : (
            <>
              <TouchableOpacity onPress={() => setBulkAddModal(true)}>
                <Ionicons name="list-outline" size={28} color="#FF9800" />
              </TouchableOpacity>
              <TouchableOpacity onPress={() => handleM3UImport()}>
                <Ionicons name="cloud-download-outline" size={28} color="#4CAF50" />
              </TouchableOpacity>
              <TouchableOpacity onPress={() => { setEditingId(null); setModalVisible(true); }}>
                <Ionicons name="add-circle" size={32} color="#ff2d2d" />
              </TouchableOpacity>
            </>
          )}
        </View>
      </View>

      {/* BULK MOVE MODAL */}
      <Modal visible={moveModalVisible} transparent animationType="slide">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalHeader}>Move {selectedIds.length} items to:</Text>
            <ScrollView style={{maxHeight: 300}}>
              {categories.map(cat => (
                <TouchableOpacity 
                  key={cat} 
                  style={[styles.catOption, cat === category && {opacity: 0.5}]} 
                  disabled={cat === category}
                  onPress={() => bulkMove(cat)}
                >
                  <Text style={styles.catOptionText}>{cat}</Text>
                  {cat === category && <Text style={{color: '#444', fontSize: 10}}> Current</Text>}
                </TouchableOpacity>
              ))}
            </ScrollView>
            <TouchableOpacity style={styles.cancelBtn} onPress={() => setMoveModalVisible(false)}>
              <Text style={styles.btnText}>CANCEL</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* BULK ADD MODAL */}
      <Modal visible={bulkAddModal} transparent animationType="slide">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalHeader}>Bulk Add (One URL per line)</Text>
            <TextInput 
              style={[styles.input, {height: 150}]} 
              placeholder={"http://example.com/stream1.m3u8\nhttp://example.com/stream2.ts"} 
              placeholderTextColor="#444"
              multiline
              value={bulkAddText}
              onChangeText={setBulkAddText}
            />
            <View style={styles.modalBtns}>
              <TouchableOpacity style={styles.cancelBtn} onPress={() => setBulkAddModal(false)}>
                <Text style={styles.btnText}>CANCEL</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.submitBtn} onPress={async () => {
                const urls = bulkAddText.split('\n').map(u => u.trim()).filter(u => u.length > 5);
                if (urls.length === 0) return;
                setLoading(true);
                setBulkAddModal(false);
                let maxOrder = channels.length > 0 ? Math.max(...channels.map(c => c.order || 0)) : -1;
                for (let url of urls) {
                  await push(ref(database, 'channels'), {
                    title: url.split('/').pop().split('?')[0] || 'New Channel',
                    url: url,
                    category,
                    type: 'auto',
                    order: ++maxOrder
                  });
                }
                setBulkAddText('');
                setLoading(false);
                Alert.alert("Success", `Added ${urls.length} channels`);
              }}>
                <Text style={styles.btnText}>ADD ALL</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* M3U IMPORT MODAL */}
      <Modal visible={m3uModal} transparent animationType="fade">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalHeader}>Fetch from M3U URL</Text>
            <TextInput 
              style={styles.input} 
              placeholder="https://.../playlist.m3u" 
              placeholderTextColor="#444"
              value={m3uUrl}
              onChangeText={setM3uUrl}
            />
            <View style={styles.modalBtns}>
              <TouchableOpacity style={styles.cancelBtn} onPress={() => setM3uModal(false)}>
                <Text style={styles.btnText}>CANCEL</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.submitBtn} onPress={fetchAndParseM3U}>
                <Text style={styles.btnText}>FETCH</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* CHANNEL SEARCH */}
      <View style={styles.searchBox}>
        <Ionicons name="search" size={20} color="#666" />
        <TextInput 
          style={styles.searchInput} 
          placeholder={isSelectionMode ? `${selectedIds.length} items selected` : `Search in ${category}...`} 
          placeholderTextColor="#666"
          value={searchQuery}
          onChangeText={setSearchQuery}
        />
      </View>

      {loading ? (
        <ActivityIndicator size="large" color="#ff2d2d" style={{marginTop: 50}} />
      ) : (
        <FlatList 
          data={filteredChannels}
          keyExtractor={item => item.id}
          renderItem={({ item, index }) => (
            <TouchableOpacity 
              style={[
                styles.card, 
                swapSelectedId === item.id && styles.cardSelected,
                selectedIds.includes(item.id) && styles.cardMultiSelected
              ]}
              onPress={() => isSelectionMode ? toggleSelection(item.id) : null}
              onLongPress={() => handleLongPress(item.id)}
              activeOpacity={0.7}
            >
              <View style={styles.orderControls}>
                {isSelectionMode ? (
                  <Ionicons 
                    name={selectedIds.includes(item.id) ? "checkbox" : "square-outline"} 
                    size={24} 
                    color={selectedIds.includes(item.id) ? "#ff2d2d" : "#444"} 
                  />
                ) : (
                  <>
                    <TouchableOpacity 
                      style={[styles.swapBtn, swapSelectedId === item.id && styles.swapBtnActive]} 
                      onPress={() => handleSwap(item)}
                    >
                      <Ionicons name={swapSelectedId === item.id ? "swap-horizontal" : "reorder-four"} size={22} color="#fff" />
                    </TouchableOpacity>
                    <View style={{marginTop: 5}}>
                      <TouchableOpacity onPress={() => moveChannel(index, -1)} disabled={index === 0}>
                        <Ionicons name="chevron-up" size={18} color={index === 0 ? "#222" : "#555"} />
                      </TouchableOpacity>
                      <TouchableOpacity onPress={() => moveChannel(index, 1)} disabled={index === channels.length - 1}>
                        <Ionicons name="chevron-down" size={18} color={index === channels.length - 1 ? "#222" : "#555"} />
                      </TouchableOpacity>
                    </View>
                  </>
                )}
              </View>
              <Image source={{ uri: item.thumbnail || 'https://via.placeholder.com/150' }} style={styles.img} />
              <View style={styles.info}>
                <Text style={styles.t}>{item.title}</Text>
                <Text style={styles.u} numberOfLines={1}>{item.url}</Text>
                <Text style={styles.typeTag}>{item.type?.toUpperCase() || 'AUTO'} {item.episode ? `• EP ${item.episode}` : ''}</Text>
              </View>
              {!isSelectionMode && (
                <View style={styles.actions}>
                  <TouchableOpacity onPress={() => editChannel(item)}>
                    <Ionicons name="create-outline" size={24} color="#fff" />
                  </TouchableOpacity>
                  <TouchableOpacity onPress={() => deleteChannel(item.id)}>
                    <Ionicons name="trash-outline" size={24} color="#ff2d2d" />
                  </TouchableOpacity>
                </View>
              )}
            </TouchableOpacity>
          )}
        />
      )}

      {/* ADD/EDIT MODAL */}
      <Modal visible={modalVisible} animationType="slide" transparent={true}>
        <View style={styles.modalOverlay}>
          <ScrollView contentContainerStyle={styles.modalContent}>
            <Text style={styles.modalHeader}>{editingId ? 'Edit Channel' : 'Add New Channel'}</Text>
            
            <View style={{flexDirection: 'row', gap: 15, marginBottom: 20}}>
               <TouchableOpacity style={styles.imagePickerMini} onPress={pickImage}>
                {form.thumbnail ? (
                  <Image source={{ uri: form.thumbnail }} style={styles.previewImg} />
                ) : (
                  <Ionicons name="camera" size={24} color="#444" />
                )}
              </TouchableOpacity>
              <View style={{flex: 1}}>
                 <Text style={styles.label}>Logo URL (Paste Link)</Text>
                 <TextInput 
                  style={styles.inputSmall} 
                  placeholder="https://..." 
                  placeholderTextColor="#444"
                  value={form.thumbnail}
                  onChangeText={t => setForm({...form, thumbnail: t})}
                />
              </View>
            </View>

            <Text style={styles.label}>Channel Name</Text>
            <TextInput 
              style={styles.input} 
              placeholder="e.g. Star Sports" 
              placeholderTextColor="#444"
              value={form.title}
              onChangeText={t => setForm({...form, title: t})}
            />

            <Text style={styles.label}>Stream URL</Text>
            <TextInput 
              style={styles.input} 
              placeholder="m3u8, mpd, youtube" 
              placeholderTextColor="#444"
              value={form.url}
              onChangeText={t => setForm({...form, url: t})}
            />

            <Text style={styles.label}>Episode / Subtitle (Optional)</Text>
            <TextInput 
              style={styles.input} 
              placeholder="e.g. 10 or New" 
              placeholderTextColor="#444"
              value={form.episode}
              onChangeText={t => setForm({...form, episode: t})}
            />

            <Text style={styles.label}>Stream Type</Text>
            <View style={styles.typeRow}>
              {['auto', 'stream', 'youtube', 'embed'].map(type => (
                <TouchableOpacity 
                  key={type}
                  style={[styles.typeBtn, form.type === type && styles.typeBtnActive]}
                  onPress={() => setForm({...form, type})}
                >
                  <Text style={[styles.typeBtnText, form.type === type && styles.typeBtnTextActive]}>
                    {type.toUpperCase()}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            <View style={styles.modalBtns}>
              <TouchableOpacity style={styles.cancelBtn} onPress={() => setModalVisible(false)}>
                <Text style={styles.btnText}>CANCEL</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.submitBtn} onPress={handleSave}>
                <Text style={styles.btnText}>{editingId ? 'UPDATE' : 'ADD CHANNEL'}</Text>
              </TouchableOpacity>
            </View>
          </ScrollView>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000' },
  header: { flexDirection: 'row', padding: 20, paddingTop: 50, backgroundColor: '#111', alignItems: 'center', justifyContent: 'space-between' },
  title: { color: '#fff', fontSize: 20, fontWeight: 'bold' },
  searchBox: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#111', paddingHorizontal: 15, borderRadius: 10, margin: 10, borderWidth: 1, borderColor: '#222' },
  searchInput: { flex: 1, color: '#fff', height: 45, marginLeft: 10 },
  card: { flexDirection: 'row', padding: 12, backgroundColor: '#111', margin: 10, borderRadius: 12, alignItems: 'center', borderWidth: 1, borderColor: '#222' },
  cardSelected: { borderColor: '#ff2d2d', backgroundColor: '#1a0000' },
  cardMultiSelected: { borderColor: '#ff2d2d', backgroundColor: '#1a1a1a' },
  orderControls: { paddingRight: 10, justifyContent: 'center', alignItems: 'center' },
  swapBtn: { backgroundColor: '#222', padding: 8, borderRadius: 8, marginBottom: 2 },
  swapBtnActive: { backgroundColor: '#ff2d2d' },
  img: { width: 60, height: 60, borderRadius: 8, backgroundColor: '#000' },
  info: { flex: 1, marginLeft: 15 },
  t: { color: '#fff', fontWeight: 'bold', fontSize: 16 },
  u: { color: '#666', fontSize: 11, marginTop: 2 },
  typeTag: { color: '#ff2d2d', fontSize: 9, fontWeight: 'bold', marginTop: 4 },
  actions: { flexDirection: 'row', gap: 15, paddingLeft: 10 },
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.9)', justifyContent: 'center', padding: 20 },
  modalContent: { backgroundColor: '#111', borderRadius: 20, padding: 20, borderWidth: 1, borderColor: '#222' },
  modalHeader: { color: '#fff', fontSize: 22, fontWeight: 'bold', marginBottom: 20, textAlign: 'center' },
  imagePickerMini: { width: 60, height: 60, backgroundColor: '#000', borderRadius: 8, justifyContent: 'center', alignItems: 'center', borderWidth: 1, borderColor: '#222', overflow: 'hidden' },
  imagePicker: { width: '100%', height: 150, backgroundColor: '#000', borderRadius: 12, justifyContent: 'center', alignItems: 'center', marginBottom: 20, borderWidth: 1, borderColor: '#222', overflow: 'hidden' },
  previewImg: { width: '100%', height: '100%' },
  pickerPlaceholder: { alignItems: 'center' },
  input: { backgroundColor: '#000', color: '#fff', padding: 15, borderRadius: 10, marginBottom: 15, borderWidth: 1, borderColor: '#222' },
  inputSmall: { backgroundColor: '#000', color: '#fff', padding: 10, borderRadius: 8, borderWidth: 1, borderColor: '#222' },
  label: { color: '#666', marginBottom: 10, fontSize: 12, fontWeight: 'bold' },
  typeRow: { flexDirection: 'row', gap: 8, marginBottom: 25 },
  typeBtn: { flex: 1, padding: 10, borderRadius: 8, borderWidth: 1, borderColor: '#222', alignItems: 'center' },
  typeBtnActive: { backgroundColor: '#ff2d2d', borderColor: '#ff2d2d' },
  typeBtnText: { color: '#666', fontWeight: 'bold', fontSize: 10 },
  typeBtnTextActive: { color: '#fff' },
  modalBtns: { flexDirection: 'row', gap: 10 },
  cancelBtn: { flex: 1, backgroundColor: '#222', padding: 15, borderRadius: 10, alignItems: 'center' },
  submitBtn: { flex: 1, backgroundColor: '#ff2d2d', padding: 15, borderRadius: 10, alignItems: 'center' },
  btnText: { color: '#fff', fontWeight: 'bold' },
  catOption: { padding: 15, borderBottomWidth: 1, borderBottomColor: '#222', flexDirection: 'row', alignItems: 'center' },
  catOptionText: { color: '#fff', fontSize: 16 }
});
