import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pip_view/pip_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  
  // Initialize Firebase with the project info found in firebaseConfig.js
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDummyKey_ReplaceWithActual", // Placeholder as not found in JS
      appId: "1:dummy:android:dummy",
      messagingSenderId: "dummy",
      projectId: "ummo-tv-be82a",
      databaseURL: "https://ummo-tv-be82a-default-rtdb.firebaseio.com",
    ),
  );

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
        colorSchemeSeed: const Color(0xFFFF2D2D),
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
    _checkSecurity();
  }

  Future<void> _checkSecurity() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    // Emulator check
    if (!androidInfo.isPhysicalDevice) {
      setState(() { _isBlocked = true; _isChecking = false; });
      return;
    }

    // Dangerous packages check (HttpCanary, etc.)
    final dangerousPackages = [
      'com.guoshi.httpcanary',
      'com.guoshi.httpcanary.premium',
      'com.emanuelef.remote_capture',
      'app.greyshirts.sslcapture',
      'com.minhui.networkcapture'
    ];

    for (var pkg in dangerousPackages) {
      try {
        final bool isInstalled = await platform.invokeMethod('isPackageInstalled', {"packageName": pkg});
        if (isInstalled) {
          setState(() { _isBlocked = true; _isChecking = false; });
          return;
        }
      } catch (e) { /* Ignore error */ }
    }

    setState(() { _isChecking = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF2D2D))));
    }
    if (_isBlocked) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_rounded, size: 100, color: Color(0xFFFF2D2D)),
                const SizedBox(height: 24),
                Text(
                  'SECURITY VIOLATION',
                  style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Network monitoring software or emulators detected. Please remove them to continue using Mizofy TV.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const HomeScreen();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<dynamic> _channels = [];
  List<dynamic> _filteredChannels = [];
  List<String> _categories = [];
  String _activeCategory = 'All';
  List<dynamic> _banners = [];
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _globalConfig = {};
  bool _isLoading = true;
  final PageController _bannerController = PageController();

  @override
  void initState() {
    super.initState();
    _initUnityAds();
    _listenToData();
  }

  void _initUnityAds() {
    UnityAds.init(
      gameId: '6099899',
      onComplete: () => print('Unity Ads Initialized'),
      onFailed: (error, message) => print('Unity Ads Failed: $error $message'),
    );
  }

  void _listenToData() {
    // Sync Channels
    _dbRef.child('channels').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        setState(() {
          _channels = data.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value as Map)}).toList();
          _filterChannels();
        });
      }
    });

    // Sync Categories
    _dbRef.child('categories').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        final List<Map<String, dynamic>> cats = data.entries
            .map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value as Map)})
            .toList();
        cats.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
        setState(() {
          _categories = ['All', ...cats.map((c) => c['name'] as String)];
        });
      }
    });

    // Sync Banners
    _dbRef.child('banners').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        setState(() {
          _banners = data.values.toList();
          _isLoading = false;
        });
      }
    });

    // Sync Settings
    _dbRef.child('settings').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) setState(() => _settings = Map<String, dynamic>.from(data));
    });

    // Sync Global Config
    _dbRef.child('globalConfig').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) setState(() => _globalConfig = Map<String, dynamic>.from(data));
    });
  }

  void _filterChannels() {
    setState(() {
      _filteredChannels = _channels.where((c) {
        final matchesCat = _activeCategory == 'All' || c['category'] == _activeCategory;
        return matchesCat;
      }).toList();
    });
  }

  void _openUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFF0A0A0A),
            title: Text(
              'Mizofy TV',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            actions: [
              if (_settings['whatsappLink'] != null)
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
                  onPressed: () => _openUrl(_settings['whatsappLink']),
                ),
              IconButton(
                icon: const Icon(Icons.share_rounded),
                onPressed: () {
                  // Implement share
                },
              ),
            ],
          ),
          
          if (_globalConfig['alertMsg'] != null)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.orangeAccent,
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_globalConfig['alertMsg'], style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ),

          // Banner Carousel
          if (_banners.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180,
                child: PageView.builder(
                  controller: _bannerController,
                  itemCount: _banners.length,
                  itemBuilder: (context, index) {
                    final b = _banners[index];
                    return GestureDetector(
                      onTap: () => _openUrl(b['url']),
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(image: NetworkImage(b['imageUrl']), fit: BoxFit.cover),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Unity Ad Banner
          if (_settings['showAds'] != false)
            SliverToBoxAdapter(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: UnityBannerAd(
                  placementId: 'Banner_Android',
                  onLoad: (placementId) => print('Banner loaded: $placementId'),
                  onClick: (placementId) => print('Banner clicked: $placementId'),
                  onFailed: (placementId, error, message) => print('Banner failed: $placementId $error $message'),
                ),
              ),
            ),

          // Categories
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isActive = _activeCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() { _activeCategory = cat; _filterChannels(); }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFFF2D2D) : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(cat, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.white60)),
                    ),
                  );
                },
              ),
            ),
          ),

          // Channel Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final ch = _filteredChannels[index];
                  return ChannelCard(channel: ch);
                },
                childCount: _filteredChannels.length,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _settings['telegramLink'] != null
          ? FloatingActionButton(
              onPressed: () => _openUrl(_settings['telegramLink']),
              backgroundColor: const Color(0xFF0088CC),
              child: const Icon(Icons.send_rounded, color: Colors.white),
            )
          : null,
    );
  }
}

class ChannelCard extends StatelessWidget {
  final Map<String, dynamic> channel;
  const ChannelCard({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => PlayerScreen(channel: channel)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  image: DecorationImage(
                    image: NetworkImage(channel['thumbnail'] ?? ''),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    channel['category'] ?? '',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
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
  late final VideoController controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    player.open(Media(widget.channel['url'] ?? ''));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PIPView(
      builder: (context, isFloating) {
        if (isFloating) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Video(controller: controller, controls: NoVideoControls),
          );
        }
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(widget.channel['title'] ?? 'Live Stream'),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_in_picture_alt_rounded),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PIPView(
                        builder: (context, isFloating) => Scaffold(
                          backgroundColor: Colors.black,
                          body: Video(controller: controller, controls: NoVideoControls),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Video(controller: controller),
            ),
          ),
        );
      },
    );
  }
}
