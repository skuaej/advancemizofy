import React from 'react';
import { View, Text, StyleSheet, Dimensions, TouchableOpacity, Platform } from 'react-native';
import { NavigationContainer, DarkTheme } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { StatusBar } from 'expo-status-bar';
import { Ionicons } from '@expo/vector-icons';

// Screens
import HomeScreen from './src/screens/HomeScreen';
import PlayerScreen from './src/screens/PlayerScreen';

// Security
import * as IntentLauncher from 'expo-intent-launcher';
import * as Device from 'expo-device';

const Stack = createNativeStackNavigator();
const Tab = createBottomTabNavigator();

const customDarkTheme = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    background: '#0a0a0a',
    card: '#1a1a1a',
    text: '#ffffff',
    primary: '#ff2d2d',
    border: '#2a2a2a'
  },
};

function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarStyle: {
          backgroundColor: '#1a1a1a',
          borderTopColor: '#2a2a2a',
          height: 60,
          paddingBottom: 10,
        },
        tabBarActiveTintColor: '#ff2d2d',
        tabBarInactiveTintColor: 'gray',
        tabBarIcon: ({ focused, color, size }) => {
          return <Ionicons name={focused ? 'home' : 'home-outline'} size={size} color={color} />;
        },
      })}
    >
      <Tab.Screen name="Home" component={HomeScreen} />
    </Tab.Navigator>
  );
}

export default function App() {
  const [securityBlock, setSecurityBlock] = React.useState(false);

  React.useEffect(() => {
    // Highly aggressive Android Package Sniffer to detect tampering software
    const checkSecurity = async () => {
      if (Platform.OS === 'web') return; // Bypass security on web
      
      if (!Device.isDevice) {
        setSecurityBlock(true);
        return;
      }

      // Run background check after app is loaded to prevent hanging
      setTimeout(async () => {
        const dangerousPackages = [
          'com.guoshi.httpcanary',
          'com.guoshi.httpcanary.premium',
          'com.emanuelef.remote_capture',
          'app.greyshirts.sslcapture',
          'com.minhui.networkcapture'
        ];

        for (let pkg of dangerousPackages) {
          try {
            // Use queryIntentActivities or similar if available, 
            // otherwise use a very fast check
            const result = await IntentLauncher.startActivityAsync(IntentLauncher.ActivityAction.MAIN, {
              packageName: pkg
            });
            if (result) {
              setSecurityBlock(true);
              return;
            }
          } catch (e) {}
        }
      }, 5000); // 5 second delay
    };
    checkSecurity();
  }, []);

  if (securityBlock) {
    return (
      <View style={{flex: 1, backgroundColor: '#000', justifyContent: 'center', alignItems: 'center'}}>
        <Ionicons name="warning" size={80} color="#ff2d2d" />
        <Text style={{color: '#fff', fontSize: 24, fontWeight: 'bold', marginTop: 20}}>SECURITY VIOLATION</Text>
        <Text style={{color: '#888', textAlign: 'center', padding: 30}}>Network monitoring or emulation software detected. Remove any packet sniffing apps to continue.</Text>
      </View>
    );
  }

  return (
    <NavigationContainer theme={customDarkTheme}>
      <StatusBar style="light" backgroundColor="#0a0a0a" />
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        <Stack.Screen name="MainTabs" component={MainTabs} />
        <Stack.Screen name="Player" component={PlayerScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
