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
  String? _activeCategoryId;
  List<dynamic> _banners = [];
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _globalConfig = {};
  final PageController _bannerCtrl = PageController();
  Timer? _bannerTimer;

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
      final currentVersion = packageInfo.version;
      final serverVersion = config['version'] ?? "1.0.0";
      
      if (currentVersion != serverVersion && config['forceUpdate'] == true) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (c) => AlertDialog(
              title: const Text('Update Required'),
              content: const Text('A new version of Mizofy TV is available. Please update to continue.'),
              actions: [
                ElevatedButton(onPressed: () => _open(config['updateUrl']), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('UPDATE NOW')),
              ],
            ),
          );
        }
      }
    }
  }

  void _initUnityAds() {
    UnityAds.init(
      gameId: Platform.isAndroid ? '5611533' : '5611532',
      testMode: false,
    );
  }

  void _showInterstitial(VoidCallback onComplete) {
    UnityAds.showVideoAd(
      placementId: Platform.isAndroid ? 'Interstitial_Android' : 'Interstitial_iOS',
      onComplete: (p) => onComplete(),
      onSkipped: (p) => onComplete(),
      onFailed: (p, e, m) => onComplete(),
    );
  }

  @override
  void dispose() { _bannerTimer?.cancel(); _bannerCtrl.dispose(); super.dispose(); }

  void _listen() {
    // Fast one-time fetch for snappy start
    _db.child('categories').get().then((snap) {
      if (snap.exists && mounted) {
        final data = snap.value as Map;
        setState(() {
          _categories = data.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value)}).toList();
          _categories.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
          if (_activeCategoryId == null && _categories.isNotEmpty) _activeCategoryId = _categories[0]['id'];
        });
      }
    });

    _db.child('categories').onValue.listen((e) {
      if (e.snapshot.value is Map) {
        final data = e.snapshot.value as Map;
        setState(() {
          _categories = data.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value)}).toList();
          _categories.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
        });
      }
    });
    _db.child('channels').onValue.listen((e) {
      if (e.snapshot.value is Map) {
        final data = e.snapshot.value as Map;
        setState(() => _channels = data.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value)}).toList());
      }
    });
    _db.child('banners').onValue.listen((e) {
      if (e.snapshot.value is Map) {
        final data = e.snapshot.value as Map;
        setState(() => _banners = data.values.take(5).toList());
      }
    });
    _db.child('settings').onValue.listen((e) {
      if (e.snapshot.value is Map) setState(() => _settings = Map<String, dynamic>.from(e.snapshot.value as Map));
    });
    _db.child('globalConfig').onValue.listen((e) {
      if (e.snapshot.value is Map) setState(() => _globalConfig = Map<String, dynamic>.from(e.snapshot.value as Map));
    });
  }

  void _open(String? url) async { if (url != null) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); }

  @override
  Widget build(BuildContext context) {
    final filtered = _channels.where((ch) => ch['categoryId'] == _activeCategoryId).toList();
    filtered.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.tv_rounded, color: Colors.white, size: 20)),
                    const SizedBox(width: 10),
                    RichText(text: TextSpan(style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold), children: const [TextSpan(text: 'MIZOFY '), TextSpan(text: 'TV', style: TextStyle(color: Colors.red))])),
                  ],
                ),
                IconButton(icon: const Icon(Icons.share_rounded), onPressed: () => _open(_settings['shareLink'])),
              ]),
            ),
            
            if (_globalConfig['alertMsg'] != null && _globalConfig['alertMsg'].toString().isNotEmpty && _globalConfig['alertMsg'] != "Hi")
              Container(height: 20, child: Marquee(text: "${_globalConfig['alertMsg']}   •   ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10), velocity: 30.0)),

            Expanded(child: ListView(
              children: [
                if (_banners.isNotEmpty)
                  SizedBox(height: 240, child: PageView.builder(
                    controller: _bannerCtrl,
                    itemCount: _banners.length,
                    itemBuilder: (c, i) => GestureDetector(
                      onTap: () => _showInterstitial(() => Navigator.push(context, MaterialPageRoute(builder: (c) => PlayerScreen(channel: Map<String, dynamic>.from(_banners[i]))))),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), image: DecorationImage(image: NetworkImage(_banners[i]['imageUrl'] ?? ''), fit: BoxFit.cover)),
                        child: Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Colors.black, Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.center)),
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.bottomLeft,
                          child: Text(_banners[i]['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
                        ),
                      ),
                    ),
                  )),
                
                if (_settings['showAds'] != false)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Center(child: UnityBannerAd(placementId: Platform.isAndroid ? 'Banner_Android' : 'Banner_iOS'))),

                SizedBox(height: 40, child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (c, i) {
                    final cat = _categories[i];
                    final active = _activeCategoryId == cat['id'];
                    return GestureDetector(
                      onTap: () => setState(() => _activeCategoryId = cat['id']),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8, top: 2, bottom: 2), 
                        padding: const EdgeInsets.symmetric(horizontal: 14), 
                        decoration: BoxDecoration(color: active ? Colors.red : const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)), 
                        child: Center(child: Text(cat['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: active ? Colors.white : Colors.white60))),
                      ),
                    );
                  },
                )),

                GridView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.0),
                  itemCount: filtered.length,
                  itemBuilder: (c, i) => GestureDetector(
                    onTap: () => _showInterstitial(() => Navigator.push(context, MaterialPageRoute(builder: (c) => PlayerScreen(channel: filtered[i])))),
                    child: Container(
                      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), 
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: Image.network(filtered[i]['thumbnail'] ?? '', fit: BoxFit.cover, width: double.infinity, errorBuilder: (c,e,s) => const Icon(Icons.tv, size: 30, color: Colors.white10)))),
                        Padding(padding: const EdgeInsets.all(10), child: Text(filtered[i]['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      ]),
                    ),
                  ),
                ),
              ],
            )),
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

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player = Player();
  late final VideoController ctrl = VideoController(player);
  static const platform = MethodChannel('mizofy.user/security');

  @override
  void initState() {
    super.initState();
    player.open(Media(widget.channel['url'] ?? '', httpHeaders: {'User-Agent': 'VLC/3.0.16 LibVLC/3.0.16'}));
  }

  @override
  void dispose() { player.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return PIPView(builder: (c, isF) => Scaffold(
      backgroundColor: Colors.black, 
      body: Stack(
        children: [
          Center(child: AspectRatio(aspectRatio: 16/9, child: Video(controller: ctrl))),
          if (!isF) Positioned(top: 40, left: 10, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
          if (!isF) Positioned(bottom: 20, right: 20, child: FloatingActionButton(mini: true, backgroundColor: Colors.red, onPressed: () {
            platform.invokeMethod('enterPipMode');
          }, child: const Icon(Icons.picture_in_picture_alt))),
        ],
      )
    ));
  }
}
