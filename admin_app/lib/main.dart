import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:reorderables/reorderables.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    debugPrint("Firebase Admin Init Error: $e");
  }
  runApp(const MizofyAdminApp());
}

class MizofyAdminApp extends StatelessWidget {
  const MizofyAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mizofy Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFFF2D2D),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const AdminLogin(),
    );
  }
}

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final TextEditingController _passController = TextEditingController();

  void _login() {
    if (_passController.text == "mizofy123") {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Admin Password')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings_rounded, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text('Admin Access', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Enter Admin Password',
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  child: const Text('UNLOCK PANEL', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const ChannelManager(),
    const BannerManager(),
    const PushNotificationManager(),
    const SettingsManager(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: const Color(0xFFFF2D2D),
        unselectedItemColor: Colors.white24,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A1A1A),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.tv_rounded), label: 'Channels'),
          BottomNavigationBarItem(icon: Icon(Icons.view_carousel_rounded), label: 'Banners'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active_rounded), label: 'Push'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

class ChannelManager extends StatefulWidget {
  const ChannelManager({super.key});

  @override
  State<ChannelManager> createState() => _ChannelManagerState();
}

class _ChannelManagerState extends State<ChannelManager> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _channels = [];

  @override
  void initState() {
    super.initState();
    try {
      _db.child('channels').onValue.listen((event) {
        final data = event.snapshot.value;
        if (data is Map) {
          setState(() {
            _channels = data.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value as Map)}).toList();
          });
        }
      });
    } catch (e) {
      debugPrint("DB Admin Error: $e");
    }
  }

  void _importM3U() async {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fetch from M3U URL'),
        content: TextField(controller: urlController, decoration: const InputDecoration(hintText: 'https://.../playlist.m3u')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              try {
                final response = await http.get(Uri.parse(urlController.text)).timeout(const Duration(seconds: 10));
                if (response.statusCode == 200) {
                  final lines = response.body.split('\n');
                  for (int i = 0; i < lines.length; i++) {
                    if (lines[i].startsWith('#EXTINF:')) {
                      final title = lines[i].split(',').last.trim();
                      final url = lines[i + 1].trim();
                      _db.child('channels').push().set({
                        'title': title,
                        'url': url,
                        'category': 'Imported',
                        'thumbnail': 'https://via.placeholder.com/150',
                      });
                    }
                  }
                  Navigator.pop(context);
                }
              } catch (e) {
                debugPrint("M3U Import Error: $e");
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('FETCH'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Channels'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(icon: const Icon(Icons.cloud_download_rounded), onPressed: _importM3U),
          IconButton(icon: const Icon(Icons.add_circle_outline_rounded), onPressed: () {}),
        ],
      ),
      body: _channels.isEmpty 
        ? const Center(child: Text("No channels found. Use + or M3U Import."))
        : ReorderableListView(
            onReorder: (oldIndex, newIndex) {},
            children: _channels.map((ch) => Card(
              key: ValueKey(ch['id']),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1A1A1A),
              child: ListTile(
                leading: const Icon(Icons.drag_indicator_rounded, color: Colors.white10),
                title: Text(ch['title'] ?? ''),
                subtitle: Text(ch['category'] ?? '', style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
                trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _db.child('channels/${ch['id']}').remove()),
              ),
            )).toList(),
          ),
    );
  }
}

class PushNotificationManager extends StatelessWidget {
  const PushNotificationManager({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push Notifications'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send alerts to all Mizofy TV users', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 32),
            _buildField('Notification Title', 'e.g. New Movie Added!'),
            const SizedBox(height: 24),
            _buildField('Message Content', 'Enter the alert message...', maxLines: 4),
            const SizedBox(height: 24),
            _buildField('Image URL (Optional)', 'https://image-link.com/img.jpg'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.send_rounded),
                label: const Text('SEND NOTIFICATION', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2D2D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFFF2D2D), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white10),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

class BannerManager extends StatefulWidget {
  const BannerManager({super.key});

  @override
  State<BannerManager> createState() => _BannerManagerState();
}

class _BannerManagerState extends State<BannerManager> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<dynamic> _banners = [];

  @override
  void initState() {
    super.initState();
    _db.child('banners').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        setState(() {
          _banners = data.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value as Map)}).toList();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Banners'), backgroundColor: Colors.transparent, actions: [IconButton(icon: const Icon(Icons.add_circle, color: Colors.red), onPressed: () {})]),
      body: ListView.builder(
        itemCount: _banners.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, i) {
          final b = _banners[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(b['url'] ?? 'No Link', style: const TextStyle(color: Colors.white24, fontSize: 10)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _db.child('banners/${b['id']}').remove()),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SettingsManager extends StatelessWidget {
  const SettingsManager({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Settings Management')));
  }
}
