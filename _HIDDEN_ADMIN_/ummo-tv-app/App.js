import React from 'react';
import { NavigationContainer, DarkTheme } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { StatusBar } from 'expo-status-bar';

// Screens
import LoginScreen from './src/screens/LoginScreen';
import AdminScreen from './src/screens/AdminScreen';
import CategoryContentScreen from './src/screens/CategoryContentScreen';
import BannerScreen from './src/screens/BannerScreen';
import NotificationScreen from './src/screens/NotificationScreen';

const Stack = createNativeStackNavigator();

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

export default function App() {
  return (
    <NavigationContainer theme={customDarkTheme}>
      <StatusBar style="light" backgroundColor="#0a0a0a" />
      <Stack.Navigator 
        initialRouteName="Login"
        screenOptions={{ 
          headerShown: false,
          animation: 'fade_from_bottom'
        }}
      >
        <Stack.Screen name="Login" component={LoginScreen} />
        <Stack.Screen name="AdminHome" component={AdminScreen} />
        <Stack.Screen name="CategoryContent" component={CategoryContentScreen} />
        <Stack.Screen name="Banners" component={BannerScreen} />
        <Stack.Screen name="Notifications" component={NotificationScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
