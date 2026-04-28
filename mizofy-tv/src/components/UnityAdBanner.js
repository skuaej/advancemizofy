import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { BannerView } from 'react-native-unity-ads';

/**
 * Verified Unity Ads Configuration for UmmoTV Project
 * --------------------------------------------------
 * Project ID: 41e8a3b2-6982-4d5f-9e7a-03b561f75b26
 * Organization ID: 13469669010512
 * Android Game ID: 6099899
 * iOS Game ID: 6099898
 */

export const UNITY_CONFIG = {
  PROJECT_ID: '41e8a3b2-6982-4d5f-9e7a-03b561f75b26',
  ANDROID_GAME_ID: '6099899',
  IOS_GAME_ID: '6099898',
  PLACEMENTS: {
    BANNER: 'Banner_Android',
    INTERSTITIAL: 'Interstitial_Android',
    REWARDED: 'Rewarded_Android',
    LEGACY_BANNER: 'banner'
  }
};

export default function UnityAdBanner() {
  return (
    <View style={styles.adContainer}>
      <BannerView
        placementId={UNITY_CONFIG.PLACEMENTS.BANNER}
        onLoad={() => console.log('Banner loaded')}
        onError={(err) => console.log('Banner error:', err)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  adContainer: {
    width: '100%',
    height: 60,
    backgroundColor: '#1a1a1a',
    justifyContent: 'center',
    alignItems: 'center',
    marginVertical: 10,
    borderWidth: 1,
    borderColor: '#ff2d2d',
    borderRadius: 8,
  },
  adText: {
    color: '#ff2d2d',
    fontWeight: 'bold',
    fontSize: 12,
  },
  subText: {
    color: '#666',
    fontSize: 9,
  }
});
