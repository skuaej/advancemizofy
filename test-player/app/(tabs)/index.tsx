import React, { useState } from 'react';
import { StyleSheet, View, Text, TouchableOpacity } from 'react-native';
import { Video, ResizeMode, Audio } from 'expo-av';

export default function HomeScreen() {
  const [showPlayer, setShowPlayer] = useState(false);

  React.useEffect(() => {
    Audio.setAudioModeAsync({
      allowsRecordingIOS: false,
      staysActiveInBackground: true,
      interruptionModeIOS: 1,
      playsInSilentModeIOS: true,
      shouldDuckAndroid: false,
      interruptionModeAndroid: 2,
      playThroughEarpieceAndroid: false,
    });
  }, []);

  if (!showPlayer) {
    return (
      <View style={styles.container}>
        <Text style={styles.welcomeTitle}>bsdk welcome</Text>
        <Text style={styles.welcomeSub}>Test Player App (8082)</Text>
        <TouchableOpacity 
          style={styles.startButton} 
          onPress={() => setShowPlayer(true)}
        >
          <Text style={styles.buttonText}>START PLAYER</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>bsdd start</Text>
      <Video
        source={{ 
          uri: 'http://datahub11.com/live/76446885500/86436775522/9399.ts',
          overrideFileExtensionAndroid: 'ts'
        }}
        rate={1.0}
        volume={1.0}
        isMuted={false}
        resizeMode={ResizeMode.CONTAIN}
        shouldPlay
        isLooping
        style={styles.video}
        useNativeControls
        onError={(e) => console.log('Video Error:', e)}
      />
      <TouchableOpacity 
        style={styles.backButton} 
        onPress={() => setShowPlayer(false)}
      >
        <Text style={styles.buttonText}>BACK</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20
  },
  welcomeTitle: {
    color: '#ff2d2d',
    fontSize: 32,
    fontWeight: 'bold',
  },
  welcomeSub: {
    color: '#888',
    fontSize: 16,
    marginTop: 10,
    marginBottom: 40
  },
  startButton: {
    backgroundColor: '#ff2d2d',
    paddingHorizontal: 40,
    paddingVertical: 15,
    borderRadius: 30,
  },
  title: {
    color: '#fff',
    fontSize: 20,
    marginBottom: 20,
  },
  video: {
    width: '100%',
    height: 300,
    backgroundColor: '#000'
  },
  backButton: {
    backgroundColor: '#333',
    paddingHorizontal: 30,
    paddingVertical: 10,
    borderRadius: 20,
    marginTop: 30
  },
  buttonText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 16
  }
});
