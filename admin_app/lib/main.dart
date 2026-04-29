import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDummyKey_ReplaceWithActual",
      appId: "1:dummy:android:dummy",
      messagingSenderId: "dummy",
      projectId: "ummo-tv-be82a",
      databaseURL: "https://ummo-tv-be82a-default-rtdb.firebaseio.com",
    ),
  );
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
        primaryColor: Colors.orangeAccent,
        colorSchemeSeed: Colors.orangeAccent,
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
    if (_passController.text == "mizofy123") { // Default password from original repo logic often
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
            border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings_rounded, size: 64, color: Colors.orangeAccent),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
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
    const SettingsManager(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: Colors.orangeAccent,
        unselectedItemColor: Colors.white54,
        backgroundColor: const Color(0xFF1A1A1A),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.tv_rounded), label: 'Channels'),
          BottomNavigationBarItem(icon: Icon(Icons.view_carousel_rounded), label: 'Banners'),
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
  List<dynamic> _channels = [];

  @override
  void initState() {
    super.initState();
    _db.child('channels').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        setState(() {
          _channels = data.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value as Map)}).toList();
        });
      }
    });
  }

  void _addChannel() {
    showDialog(context: context, builder: (context) => const ChannelDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Channel Management'), backgroundColor: Colors.transparent),
      body: ListView.builder(
        itemCount: _channels.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final ch = _channels[index];
          return Card(
            color: Colors.white.withOpacity(0.05),
            child: ListTile(
              leading: Image.network(ch['thumbnail'] ?? '', width: 50, height: 50, errorBuilder: (_, __, ___) => const Icon(Icons.tv)),
              title: Text(ch['title'] ?? ''),
              subtitle: Text(ch['category'] ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _db.child('channels/${ch['id']}').remove()),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addChannel,
        backgroundColor: Colors.orangeAccent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

class ChannelDialog extends StatefulWidget {
  const ChannelDialog({super.key});

  @override
  State<ChannelDialog> createState() => _ChannelDialogState();
}

class _ChannelDialogState extends State<ChannelDialog> {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _thumbController = TextEditingController();
  final _catController = TextEditingController();

  void _save() {
    FirebaseDatabase.instance.ref().child('channels').push().set({
      'title': _titleController.text,
      'url': _urlController.text,
      'thumbnail': _thumbController.text,
      'category': _catController.text,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Channel'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _urlController, decoration: const InputDecoration(labelText: 'Stream URL')),
            TextField(controller: _thumbController, decoration: const InputDecoration(labelText: 'Thumbnail URL')),
            TextField(controller: _catController, decoration: const InputDecoration(labelText: 'Category')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class BannerManager extends StatelessWidget {
  const BannerManager({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Banner Management Coming Soon'));
  }
}

class SettingsManager extends StatelessWidget {
  const SettingsManager({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Global Settings Coming Soon'));
  }
}
