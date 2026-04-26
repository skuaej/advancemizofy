import React from 'react';
import { NavigationContainer, DarkTheme } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

import AdminScreen from './src/screens/AdminScreen';
import CategoryContentScreen from './src/screens/CategoryContentScreen';

const Stack = createNativeStackNavigator();

export default function App() {
  return (
    <NavigationContainer theme={DarkTheme}>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        <Stack.Screen name="AdminHome" component={AdminScreen} />
        <Stack.Screen name="CategoryContent" component={CategoryContentScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
