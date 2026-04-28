import React, { useState } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, Alert, ScrollView } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { database } from '../firebaseConfig';
import { ref, push, set } from 'firebase/database';

export default function NotificationScreen() {
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [image, setImage] = useState('');

  const sendNotification = () => {
    if (!title || !message) {
      Alert.alert("Error", "Title and Message are required");
      return;
    }

    const notifData = {
      title,
      message,
      image,
      timestamp: Date.now(),
    };

    // Save to Firebase (User app will listen to this node)
    push(ref(database, 'notifications'), notifData);
    
    // Also set as "latest" to trigger immediate UI alerts in some app versions
    set(ref(database, 'latestNotification'), notifData);

    Alert.alert("Success", "Notification sent to all users!");
    setTitle('');
    setMessage('');
    setImage('');
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Push Notifications</Text>
        <Text style={styles.subtitle}>Send alerts to all Mizofy TV users</Text>
      </View>

      <View style={styles.form}>
        <Text style={styles.label}>Notification Title</Text>
        <TextInput
          style={styles.input}
          value={title}
          onChangeText={setTitle}
          placeholder="e.g. New Movie Added!"
          placeholderTextColor="#666"
        />

        <Text style={styles.label}>Message Content</Text>
        <TextInput
          style={[styles.input, { height: 100 }]}
          value={message}
          onChangeText={setMessage}
          placeholder="Enter the alert message..."
          placeholderTextColor="#666"
          multiline
        />

        <Text style={styles.label}>Image URL (Optional)</Text>
        <TextInput
          style={styles.input}
          value={image}
          onChangeText={setImage}
          placeholder="https://image-link.com/img.jpg"
          placeholderTextColor="#666"
        />

        <TouchableOpacity style={styles.sendBtn} onPress={sendNotification}>
          <Ionicons name="send" size={20} color="#fff" style={{ marginRight: 10 }} />
          <Text style={styles.sendBtnText}>SEND NOTIFICATION</Text>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0a0a0a', padding: 20 },
  header: { marginTop: 40, marginBottom: 30 },
  headerTitle: { color: '#fff', fontSize: 26, fontWeight: 'bold' },
  subtitle: { color: '#888', fontSize: 14, marginTop: 5 },
  form: { backgroundColor: '#1a1a1a', padding: 20, borderRadius: 15 },
  label: { color: '#ff2d2d', fontWeight: 'bold', marginBottom: 10, marginTop: 15 },
  input: { backgroundColor: '#0a0a0a', color: '#fff', padding: 15, borderRadius: 10, borderWidth: 1, borderColor: '#333' },
  sendBtn: { backgroundColor: '#ff2d2d', padding: 18, borderRadius: 12, flexDirection: 'row', justifyContent: 'center', alignItems: 'center', marginTop: 30 },
  sendBtnText: { color: '#fff', fontWeight: 'bold', fontSize: 16 }
});
