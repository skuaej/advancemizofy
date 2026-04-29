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
import 'package:marquee/marquee.dart';
import 'dart:async';

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
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

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
    _checkSecurity();
  }

  Future<void> _checkSecurity() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

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
        } catch (e) {}
      }
    } catch (e) {}

    if (mounted) setState(() { _isChecking = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF2D2D))));
    if (_isBlocked) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security_rounded, size: 80, color: Color(0xFFFF2D2D)),
              const SizedBox(height: 20),
              Text('SECURITY ALERT', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
              const Padding(padding: EdgeInsets.all(20.0), child: Text('Dangerous software detected. Remove any sniffing tools to continue.', textAlign: TextAlign.center)),
            ],
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
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<dynamic> _channels = [];
  List<dynamic> _filteredChannels = [];
  List<String> _categories = [];
  String _activeCategory = 'All';
  List<dynamic> _banners = [];
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _globalConfig = {};
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _listenToData();
    _initUnityAds();
  }

  void _initUnityAds() {
    UnityAds.init(gameId: '6099899');
  }

  void _listenToData() {
    try {
      _db.child('channels').onValue.listen((event) {
        final data = event.snapshot.value;
        if (data is Map) {
          setState(() {
            _channels = data.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value as Map)}).toList();
            _filter();
          });
        }
      });
      _db.child('categories').onValue.listen((event) {
        final data = event.snapshot.value;
        if (data is Map) {
          final List<Map<String, dynamic>> cats = data.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value as Map)}).toList();
          cats.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
          setState(() { _categories = ['All', ...cats.map((c) => c['name'] as String)]; });
        }
      });
      _db.child('banners').onValue.listen((event) {
        final data = event.snapshot.value;
        if (data is Map) setState(() => _banners = data.values.toList());
      });
      _db.child('settings').onValue.listen((event) {
        final data = event.snapshot.value;
        if (data is Map) setState(() => _settings = Map<String, dynamic>.from(data));
      });
      _db.child('globalConfig').onValue.listen((event) {
        final data = event.snapshot.value;
        if (data is Map) setState(() => _globalConfig = Map<String, dynamic>.from(data));
      });
    } catch (e) {}
  }

  void _filter() {
    setState(() {
      _filteredChannels = _channels.where((c) {
        final matchesCat = _activeCategory == 'All' || c['category'] == _activeCategory;
        final matchesSearch = c['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCat && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      children: const [
                        TextSpan(text: 'Mizofy '),
                        TextSpan(text: 'TV', style: TextStyle(color: Color(0xFFFF2D2D))),
                      ],
                    ),
                  ),
                  const Icon(Icons.share_rounded, color: Colors.white70),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                onChanged: (v) { _searchQuery = v; _filter(); },
                decoration: InputDecoration(
                  hintText: 'Search all channels...',
                  prefixIcon: const Icon(Icons.search, color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (_globalConfig['alertMsg'] != null && _globalConfig['alertMsg'].toString().isNotEmpty)
              Container(
                height: 35,
                margin: const EdgeInsets.only(top: 16),
                child: Marquee(
                  text: _globalConfig['alertMsg'],
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  blankSpace: 100.0,
                  velocity: 50.0,
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  if (_banners.isNotEmpty)
                    SizedBox(
                      height: 180,
                      child: PageView.builder(
                        itemCount: _banners.length,
                        itemBuilder: (context, i) {
                          final b = _banners[i];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), image: DecorationImage(image: NetworkImage(b['imageUrl'] ?? ''), fit: BoxFit.cover)),
                            child: Container(
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [Colors.black, Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter)),
                              padding: const EdgeInsets.all(16),
                              alignment: Alignment.bottomLeft,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b['title'] ?? 'LIVE CRICKET', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PlayerScreen(channel: Map<String, dynamic>.from(b)))),
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('WATCH STREAM'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (_settings['showAds'] != false)
                    Padding(padding: const EdgeInsets.all(16.0), child: UnityBannerAd(placementId: 'Banner_Android')),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, i) {
                        final cat = _categories[i];
                        final active = _activeCategory == cat;
                        return GestureDetector(
                          onTap: () { setState(() { _activeCategory = cat; _filter(); }); },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(color: active ? Colors.red : const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
                            child: Center(child: Text(cat, style: TextStyle(fontWeight: FontWeight.bold, color: active ? Colors.white : Colors.white60))),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(padding: const EdgeInsets.all(16.0), child: Text('Live Channels', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold))),
                  _filteredChannels.isEmpty 
                    ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text("Connecting to streams...", style: TextStyle(color: Colors.white24))))
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.9),
                        itemCount: _filteredChannels.length,
                        itemBuilder: (context, i) {
                          final ch = _filteredChannels[i];
                          return GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PlayerScreen(channel: ch))),
                            child: Container(
                              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: Image.network(ch['thumbnail'] ?? '', fit: BoxFit.cover, width: double.infinity, errorBuilder: (c, e, s) => const Icon(Icons.tv, size: 50)))),
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(ch['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(ch['category'] ?? '', style: const TextStyle(color: Colors.white24, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, backgroundColor: Colors.blueAccent, child: const Icon(Icons.send_rounded, color: Colors.white)),
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
  double _volume = 100.0;
  double _brightness = 0.5;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    player.open(Media(widget.channel['url'] ?? ''));
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PIPView(
      builder: (context, isFloating) {
        if (isFloating) {
          return Scaffold(backgroundColor: Colors.black, body: Video(controller: controller, controls: NoVideoControls));
        }
        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () { setState(() => _showControls = !_showControls); if (_showControls) _startHideTimer(); },
            onVerticalDragUpdate: (details) {
              if (details.localPosition.dx < MediaQuery.of(context).size.width / 2) {
                // Brightness
                setState(() { _brightness = (_brightness - details.delta.dy / 300).clamp(0.0, 1.0); });
              } else {
                // Volume
                setState(() { _volume = (_volume - details.delta.dy / 3).clamp(0.0, 100.0); player.setVolume(_volume); });
              }
            },
            child: Stack(
              children: [
                Center(child: AspectRatio(aspectRatio: 16 / 9, child: Video(controller: controller, controls: NoVideoControls))),
                
                // Indicators
                if (!_showControls) ...[
                  Positioned(
                    top: 50, left: 20,
                    child: Column(children: [const Icon(Icons.brightness_6, color: Colors.white70), Text("${(_brightness * 100).toInt()}%")]),
                  ),
                  Positioned(
                    top: 50, right: 20,
                    child: Column(children: [const Icon(Icons.volume_up, color: Colors.white70), Text("${_volume.toInt()}%")]),
                  ),
                ],

                // Controls Overlay
                if (_showControls)
                  AnimatedOpacity(
                    opacity: 1.0, duration: const Duration(milliseconds: 300),
                    child: Container(
                      color: Colors.black38,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Text(widget.channel['title'] ?? ''), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(icon: const Icon(Icons.replay_10, size: 48), onPressed: () => player.seek(player.state.position - const Duration(seconds: 10))),
                              StreamBuilder(
                                stream: player.stream.playing,
                                builder: (context, playing) => IconButton(
                                  icon: Icon(playing.data == true ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 72, color: Colors.red),
                                  onPressed: () => player.playOrPause(),
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.forward_10, size: 48), onPressed: () => player.seek(player.state.position + const Duration(seconds: 10))),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                IconButton(icon: const Icon(Icons.picture_in_picture_alt), onPressed: () => PIPView.of(context).presentFloating(const MizofyUserApp())),
                                const Spacer(),
                                IconButton(icon: const Icon(Icons.fullscreen), onPressed: () {
                                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                                  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
