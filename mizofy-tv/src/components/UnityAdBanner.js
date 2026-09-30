import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { WebView } from 'react-native-webview';

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
  const adHtml = `
    <!DOCTYPE html>
    <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            margin: 0;
            padding: 0;
            background: #111;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            font-family: sans-serif;
            overflow: hidden;
          }
          .ad-box {
            width: 100%;
            height: 50px;
            background: linear-gradient(90deg, #1a1a1a 0%, #2a2a2a 50%, #1a1a1a 100%);
            border: 1px solid #ff2d2d;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 12px;
            box-sizing: border-box;
          }
          .ad-badge {
            background: #ff2d2d;
            color: #fff;
            font-size: 10px;
            font-weight: bold;
            padding: 2px 6px;
            border-radius: 3px;
          }
          .ad-title {
            color: #fff;
            font-size: 12px;
            font-weight: bold;
          }
          .ad-btn {
            background: #25D366;
            color: #fff;
            font-size: 11px;
            font-weight: bold;
            padding: 4px 10px;
            border-radius: 15px;
            text-decoration: none;
          }
        </style>
      </head>
      <body>
        <div class="ad-box">
          <span class="ad-badge">SPONSORED</span>
          <span class="ad-title">🔥 Stream Live Movies & Sports!</span>
          <a href="#" class="ad-btn">INSTALL NOW</a>
        </div>
      </body>
    </html>
  `;

  return (
    <View style={styles.adContainer}>
      <WebView
        originWhitelist={['*']}
        source={{ html: adHtml }}
        style={{ width: '100%', height: 60, backgroundColor: 'transparent' }}
        scrollEnabled={false}
        javaScriptEnabled={true}
        domStorageEnabled={true}
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
