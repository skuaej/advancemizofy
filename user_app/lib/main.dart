import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pip_view/pip_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:marquee/marquee.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'dart:io';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDummyKey_ReplaceWithActual",
        appId: "1:dummy:android:dummy",
        messagingSenderId: "dummy",
        projectId: "ummo-tv-be82a",
        databaseURL: "https://ummo-tv-be82a-default-rtdb.firebaseio.com",
      ),
    ).timeout(const Duration(seconds: 5));

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    await FirebaseMessaging.instance.subscribeToTopic('all_users');
    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(android: AndroidNotificationDetails('mizofy_channel', 'Mizofy Notifications', importance: Importance.max, priority: Priority.high, icon: '@mipmap/ic_launcher')),
        );
      }
    });

    FirebaseDatabase.instance.ref().child('totalUsers').runTransaction((count) {
      if (count == null) return Transaction.success(1);
      return Transaction.success((count as int) + 1);
    });
  } catch (e) {}
  
  runApp(const MizofyUserApp());
}

class MizofyUserApp extends StatelessWidget {
  const MizofyUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mizofy TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFFF2D2D),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const SecurityWrapper(),
    );
  }
}

class SecurityWrapper extends StatefulWidget {
  const SecurityWrapper({super.key});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> {
  bool _isBlocked = false;
  bool _isChecking = true;
  static const platform = MethodChannel('mizofy.user/security');

  @override
  void initState() {
    super.initState();
    _check();
  }

  void _check() async {
    try {
      final dangerousPackages = ['com.guoshi.httpcanary', 'com.guoshi.httpcanary.premium', 'com.emanuelef.remote_capture', 'app.greyshirts.sslcapture', 'com.minhui.networkcapture'];
      for (var pkg in dangerousPackages) {
        try {
          final bool inst = await platform.invokeMethod('isPackageInstalled', {"packageName": pkg});
          if (inst) { setState(() { _isBlocked = true; _isChecking = false; }); return; }
        } catch (e) {}
      }
    } catch (e) {}
    if (mounted) setState(() { _isChecking = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF2D2D))));
    if (_isBlocked) return const Scaffold(body: Center(child: Text('SECURITY ALERT: Sniffing software detected.')));
    return const HomeScreen();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<dynamic> _channels = [];
  List<dynamic> _categories = [];
  String _activeCategoryId = "";
  String _searchQuery = "";
  bool _isSearching = false;
  final _searchCtrl = TextEditingController();
  List<dynamic> _banners = [];
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _globalConfig = {};
  final PageController _bannerCtrl = PageController();
  Timer? _bannerTimer;
  Map<String, List<dynamic>> _categoryCache = {};
  int _currentCacheVersion = 0;

  @override
  void initState() {
    super.initState();
    _listen();
    _checkUpdate();
    _initUnityAds();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_banners.isNotEmpty && _bannerCtrl.hasClients) {
        int next = (_bannerCtrl.page?.toInt() ?? 0) + 1;
        if (next >= _banners.length) next = 0;
        _bannerCtrl.animateToPage(next, duration: const Duration(milliseconds: 1000), curve: Curves.easeInOut);
      }
    });
  }

  void _checkUpdate() async {
    final snapshot = await _db.child('globalConfig').get();
    if (snapshot.exists) {
      final config = Map<String, dynamic>.from(snapshot.value as Map);
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.version != config['version'] && config['forceUpdate'] == true) {
        if (mounted) {
          showDialog(
            context: context, barrierDismissible: false,
            builder: (c) => AlertDialog(
              title: const Text('Update Required'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New version of Mizofy TV is available.'),
                  if (config['releaseNotes'] != null) ...[
                    const SizedBox(height: 12),
                    const Text('WHAT\'S NEW:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.redAccent)),
                    Text(config['releaseNotes'], style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ],
              ),
              actions: [ElevatedButton(onPressed: () => _open(config['updateUrl']), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('UPDATE NOW'))],
            ),
          );
        }
      }
      
      // Cache Refresh Logic
      if (config['cacheVersion'] != null && config['cacheVersion'] > _currentCacheVersion) {
        _currentCacheVersion = config['cacheVersion'];
        _categoryCache.clear();
      }
    }
  }

  void _initUnityAds() {
    bool testMode = _globalConfig['unityTestMode'] ?? false;
    UnityAds.init(
      gameId: Platform.isAndroid ? '6099899' : '6099898', 
      testMode: testMode,
      onComplete: () {
        print('Unity Ads Initialization Complete (TestMode: $testMode)');
        UnityAds.setPrivacyConsent(PrivacyConsentType.gdpr, true);
        UnityAds.setPrivacyConsent(PrivacyConsentType.ccpa, true);
        _loadAds();
      },
      onFailed: (error, message) {
        print('Unity Ads Initialization Failed: [$error] $message');
        Future.delayed(const Duration(seconds: 30), () => _initUnityAds());
      },
    );
  }

  void _loadAds() {
    final iid = Platform.isAndroid ? 'Interstitial_Android' : 'Interstitial_iOS';
    final rid = Platform.isAndroid ? 'Rewarded_Android' : 'Rewarded_iOS';
    
    UnityAds.load(
      placementId: iid,
      onComplete: (p) => print('Interstitial Loaded: $p'),
      onFailed: (p, e, m) {
        print('Interstitial Load Failed: $m. Retrying in 30s...');
        Future.delayed(const Duration(seconds: 30), () => _loadAds());
      },
    );
    UnityAds.load(
      placementId: rid,
      onComplete: (p) => print('Rewarded Loaded: $p'),
      onFailed: (p, e, m) => print('Rewarded Load Failed: $m'),
    );
  }

  void _showInterstitial(VoidCallback onComplete) {
    if (_settings['showAds'] == false) { onComplete(); return; }
    UnityAds.showVideoAd(
      placementId: Platform.isAndroid ? 'Interstitial_Android' : 'Interstitial_iOS',
      onComplete: (p) { _loadAds(); onComplete(); },
      onSkipped: (p) { _loadAds(); onComplete(); },
      onFailed: (p, e, m) {
        print('Interstitial Failed: $m');
        _loadAds();
        onComplete();
      },
    );
  }

  void _showRewardedAd(VoidCallback onReward) {
    UnityAds.showVideoAd(
      placementId: Platform.isAndroid ? 'Rewarded_Android' : 'Rewarded_iOS',
      onComplete: (p) { _loadAds(); onReward(); },
      onSkipped: (p) { _loadAds(); print('User skipped rewarded ad'); },
      onFailed: (p, e, m) { _loadAds(); print('Rewarded Ad Failed: $m'); },
    );
  }

  @override
  void dispose() { _bannerTimer?.cancel(); _bannerCtrl.dispose(); _searchCtrl.dispose(); super.dispose(); }

  void _listen() {
    _db.onValue.listen((event) {
      if (event.snapshot.value is Map && mounted) {
        final root = event.snapshot.value as Map;
        setState(() {
          if (root['categories'] is Map) {
            final catData = root['categories'] as Map;
            _categories = catData.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value)}).toList();
            _categories.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
            if (_activeCategoryId.isEmpty && _categories.isNotEmpty) _activeCategoryId = _categories[0]['id'];
          }
          if (root['channels'] is Map) {
            final chData = root['channels'] as Map;
            _channels = chData.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value)}).toList();
            _categoryCache.clear();
            for (var ch in _channels) {
              final cid = ch['categoryId']?.toString() ?? 'unknown';
              _categoryCache.putIfAbsent(cid, () => []).add(ch);
            }
            _categoryCache.forEach((k, v) => v.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0)));
          }
          if (root['banners'] is Map) _banners = (root['banners'] as Map).values.take(5).toList();
          if (root['settings'] is Map) _settings = Map<String, dynamic>.from(root['settings'] as Map);
          if (root['globalConfig'] is Map) _globalConfig = Map<String, dynamic>.from(root['globalConfig'] as Map);
        });
      }
    });
  }

  void _open(String? url) async { if (url != null) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); }

  @override
  Widget build(BuildContext context) {
    final filtered = (_categoryCache[_activeCategoryId] ?? []).where((ch) => (ch['title'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                if (!_isSearching) Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8), 
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.red, Color(0xFF8B0000)]), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)]), 
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24)
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MIZOFY', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        Container(height: 2, width: 40, color: Colors.red),
                      ],
                    ),
                  ],
                ),
                if (_isSearching) Expanded(child: TextField(controller: _searchCtrl, autofocus: true, onChanged: (v) => setState(() => _searchQuery = v), decoration: const InputDecoration(hintText: 'Search Channels...', border: InputBorder.none, hintStyle: TextStyle(color: Colors.white24)))),
                Row(children: [
                  IconButton(icon: Icon(_isSearching ? Icons.close : Icons.search_rounded), onPressed: () => setState(() { _isSearching = !_isSearching; if (!_isSearching) { _searchQuery = ""; _searchCtrl.clear(); } })),
                  IconButton(icon: const Icon(Icons.share_rounded), onPressed: () => _open(_settings['shareLink'])),
                ]),
              ]),
            ),
            
            if (_globalConfig['alertMsg'] != null && _globalConfig['alertMsg'].toString().isNotEmpty && _globalConfig['alertMsg'] != "Hi" && !_isSearching)
              Container(height: 22, color: Colors.red.withOpacity(0.05), child: Marquee(text: "${_globalConfig['alertMsg']}   •   ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10), velocity: 30.0)),

            Expanded(child: Scrollbar(child: ListView(
              cacheExtent: 1000,
              children: [
                if (_banners.isNotEmpty && !_isSearching)
                  SizedBox(height: 240, child: PageView.builder(
                    controller: _bannerCtrl,
                    itemCount: _banners.length,
                    itemBuilder: (c, i) => GestureDetector(
                      onTap: () => _showInterstitial(() => Navigator.push(context, MaterialPageRoute(builder: (c) => PlayerScreen(channel: Map<String, dynamic>.from(_banners[i]))))),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), image: DecorationImage(image: NetworkImage(_banners[i]['imageUrl'] ?? ''), fit: BoxFit.cover), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))]),
                        child: Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Colors.black, Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.center)),
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.bottomLeft,
                          child: Text(_banners[i]['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
                        ),
                      ),
                    ),
                  )),
                
                if (_settings['showAds'] != false)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Center(child: UnityBannerAd(placementId: Platform.isAndroid ? 'Banner_Android' : 'Banner_iOS'))),

                if (!_isSearching) SizedBox(height: 42, child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (c, i) {
                    final cat = _categories[i];
                    final active = _activeCategoryId == cat['id'];
                    return GestureDetector(
                      onTap: () => setState(() => _activeCategoryId = cat['id']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 10, top: 4, bottom: 4), 
                        padding: const EdgeInsets.symmetric(horizontal: 18), 
                        decoration: BoxDecoration(color: active ? Colors.red : const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? Colors.redAccent : Colors.white10), boxShadow: active ? [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 6)] : null), 
                        child: Center(child: Text(cat['name']?.toUpperCase() ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5, color: active ? Colors.white : Colors.white54))),
                      ),
                    );
                  },
                )),

                GridView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.05),
                  itemCount: filtered.length,
                  itemBuilder: (c, i) => GestureDetector(
                    onTap: () => _showInterstitial(() => Navigator.push(context, MaterialPageRoute(builder: (c) => PlayerScreen(channel: filtered[i])))),
                    child: Container(
                      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.05))), 
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(18)), child: Image.network(filtered[i]['thumbnail'] ?? '', fit: BoxFit.cover, width: double.infinity, errorBuilder: (c,e,s) => const Center(child: Icon(Icons.tv, size: 30, color: Colors.white10))))),
                        Padding(padding: const EdgeInsets.all(10), child: Text(filtered[i]['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white70))),
                      ]),
                    ),
                  ),
                ),
              ],
            ))),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_settings['whatsappLink'] != null) FloatingActionButton.small(heroTag: 'wa', onPressed: () => _open(_settings['whatsappLink']), backgroundColor: const Color(0xFF25D366), child: const Icon(Icons.chat, color: Colors.white, size: 16)),
          const SizedBox(height: 8),
          if (_settings['telegramLink'] != null) FloatingActionButton.small(heroTag: 'tg', onPressed: () => _open(_settings['telegramLink']), backgroundColor: const Color(0xFF0088CC), child: const Icon(Icons.send, color: Colors.white, size: 16)),
        ],
      ),
    );
  }
}

class PlayerScreen extends StatefulWidget {
  final Map<String, dynamic> channel;
  const PlayerScreen({super.key, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  late final Player player = Player(configuration: const PlayerConfiguration(vo: 'mediacodec', title: 'Mizofy TV'));
  late final VideoController ctrl = VideoController(player);
  static const platform = MethodChannel('mizofy.user/security');
  bool _showControls = true;
  Timer? _hideTimer;
  late final WebViewController _webCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.channel['isEmbed'] == true) {
      _webCtrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..loadRequest(Uri.parse(widget.channel['url'] ?? ''));
    } else {
      player.open(Media(
        widget.channel['url'] ?? '', 
        httpHeaders: {
          'User-Agent': 'VLC/3.0.16 LibVLC/3.0.16',
          'Referer': '',
          'Origin': '',
        }
      ));
    }
    player.setVolume(100);
    platform.invokeMethod('setPlayerActive', {"active": true});
    _startHideTimer();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Force resume in PiP
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && player.state.playing == false) {
          player.play();
        }
      });
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  void dispose() { 
    WidgetsBinding.instance.removeObserver(this);
    platform.invokeMethod('setPlayerActive', {"active": false});
    _hideTimer?.cancel(); 
    player.dispose(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    return PIPView(builder: (c, isF) {
      // Logic to show ONLY the video player area in PiP
      if (isF) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: widget.channel['isEmbed'] == true 
                  ? WebViewWidget(controller: _webCtrl)
                  : AspectRatio(aspectRatio: 16/9, child: Video(controller: ctrl))
              ),
              StreamBuilder(
                stream: player.stream.playing,
                builder: (c, snap) => snap.data == false ? Center(
                  child: IconButton(
                    iconSize: 50,
                    icon: const Icon(Icons.play_circle_filled, color: Colors.white70),
                    onPressed: () => player.play(),
                  ),
                ) : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }

      return Scaffold(
        backgroundColor: Colors.black, 
        body: GestureDetector(
          onTap: () {
            setState(() => _showControls = !_showControls);
            if (_showControls) _startHideTimer();
          },
          child: Stack(
            children: [
              Center(
                child: widget.channel['isEmbed'] == true 
                  ? WebViewWidget(controller: _webCtrl)
                  : AspectRatio(aspectRatio: 16/9, child: Video(controller: ctrl))
              ),
              
              if (_showControls) ...[
                Positioned.fill(child: Container(color: Colors.black38)),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(iconSize: 48, icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white), onPressed: () => platform.invokeMethod('enterPipMode')),
                      if (widget.channel['isEmbed'] != true) ...[
                        const SizedBox(width: 40),
                        StreamBuilder(
                          stream: player.stream.playing,
                          builder: (c, snap) => IconButton(
                            iconSize: 64,
                            icon: Icon(snap.data == true ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
                            onPressed: () => player.playOrPause(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(top: 40, left: 10, right: 10, child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.channel['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                  ],
                )),
                if (widget.channel['isEmbed'] != true)
                  Positioned(bottom: 20, left: 20, right: 20, child: StreamBuilder(
                    stream: player.stream.position,
                    builder: (c, snap) {
                      final pos = snap.data ?? Duration.zero;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Slider(
                            value: pos.inSeconds.toDouble(),
                            max: (player.state.duration.inSeconds > 0) ? player.state.duration.inSeconds.toDouble() : 1.0,
                            activeColor: Colors.red,
                            inactiveColor: Colors.white24,
                            onChanged: (v) => player.seek(Duration(seconds: v.toInt())),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDur(pos), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              Text(_formatDur(player.state.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
                      );
                    },
                  )),
              ],
            ],
          ),
        )
      );
    });
  }

  String _formatDur(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }
}
