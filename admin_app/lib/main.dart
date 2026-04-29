import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:reorderables/reorderables.dart';
import 'dart:async';

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
    );
  } catch (e) {}
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Password')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.red.withOpacity(0.2))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_rounded, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text('Mizofy Admin', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(controller: _passController, obscureText: true, decoration: InputDecoration(hintText: 'Admin PIN', filled: true, fillColor: Colors.black, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _login, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('ENTER'))),
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
    const ChannelCategoryManager(),
    const BannerManager(),
    const PushNotificationManager(),
    const GlobalSettingsManager(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.white24,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A1A1A),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.category_rounded), label: 'Content'),
          BottomNavigationBarItem(icon: Icon(Icons.view_carousel_rounded), label: 'Banners'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active_rounded), label: 'Push'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Stats'),
        ],
      ),
    );
  }
}

class ChannelCategoryManager extends StatefulWidget {
  const ChannelCategoryManager({super.key});

  @override
  State<ChannelCategoryManager> createState() => _ChannelCategoryManagerState();
}

class _ChannelCategoryManagerState extends State<ChannelCategoryManager> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _db.child('categories').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        setState(() {
          _categories = data.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value)}).toList();
          _categories.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
        });
      }
    });
  }

  void _addCategory() {
    final controller = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Add Category'),
      content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'e.g. Sports')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () { _db.child('categories').push().set({'name': controller.text, 'order': _categories.length}); Navigator.pop(context); }, child: const Text('ADD')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Content Management'), backgroundColor: Colors.transparent, actions: [IconButton(icon: const Icon(Icons.add_box_rounded, color: Colors.red), onPressed: _addCategory)]),
      body: Column(
        children: [
          // Categories horizontal list with Drag & Move
          SizedBox(
            height: 60,
            child: ReorderableRow(
              onReorder: (oldI, newI) {
                // Update Firebase order
                setState(() {
                  final item = _categories.removeAt(oldI);
                  _categories.insert(newI, item);
                  for (int i = 0; i < _categories.length; i++) {
                    _db.child('categories/${_categories[i]['id']}').update({'order': i});
                  }
                });
              },
              children: _categories.map((cat) => GestureDetector(
                key: ValueKey(cat['id']),
                onTap: () => setState(() => _selectedCategoryId = cat['id']),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: _selectedCategoryId == cat['id'] ? Colors.red : Colors.white10, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Row(
                    children: [
                      Text(cat['name'] ?? ''),
                      const SizedBox(width: 4),
                      IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.close, size: 14, color: Colors.white24), onPressed: () => _db.child('categories/${cat['id']}').remove()),
                    ],
                  )),
                ),
              )).toList(),
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(child: _selectedCategoryId == null ? const Center(child: Text("Select a Category")) : ChannelListManager(categoryId: _selectedCategoryId!, categoryName: _categories.firstWhere((c) => c['id'] == _selectedCategoryId)['name'])),
        ],
      ),
    );
  }
}

class ChannelListManager extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  const ChannelListManager({super.key, required this.categoryId, required this.categoryName});

  @override
  State<ChannelListManager> createState() => _ChannelListManagerState();
}

class _ChannelListManagerState extends State<ChannelListManager> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _channels = [];
  String _search = "";

  @override
  void initState() {
    super.initState();
    _db.child('channels').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        setState(() {
          _channels = data.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value)})
              .where((ch) => ch['categoryId'] == widget.categoryId).toList();
        });
      }
    });
  }

  void _addChannel() {
    showDialog(context: context, builder: (context) => ChannelEditDialog(categoryId: widget.categoryId));
  }

  void _importM3U() {
    final controller = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('M3U Import'),
      content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'M3U URL')),
      actions: [
        ElevatedButton(onPressed: () async {
          final res = await http.get(Uri.parse(controller.text));
          if (res.statusCode == 200) {
            final lines = res.body.split('\n');
            for (int i = 0; i < lines.length; i++) {
              if (lines[i].startsWith('#EXTINF:')) {
                final title = lines[i].split(',').last.trim();
                final url = lines[i+1].trim();
                _db.child('channels').push().set({'title': title, 'url': url, 'categoryId': widget.categoryId, 'category': widget.categoryName, 'thumbnail': 'https://via.placeholder.com/150'});
              }
            }
          }
          Navigator.pop(context);
        }, child: const Text('IMPORT')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _channels.where((ch) => ch['title'].toString().toLowerCase().contains(_search.toLowerCase())).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(child: TextField(onChanged: (v) => setState(() => _search = v), decoration: InputDecoration(hintText: 'Search Channels...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
              IconButton(icon: const Icon(Icons.cloud_download_rounded, color: Colors.blue), onPressed: _importM3U),
              IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: _addChannel),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView(
            onReorder: (oldI, newI) {},
            children: filtered.map((ch) => Card(
              key: ValueKey(ch['id']),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Image.network(ch['thumbnail'] ?? '', width: 40, height: 40, errorBuilder: (c,e,s) => const Icon(Icons.tv)),
                title: Text(ch['title'] ?? ''),
                subtitle: Text(ch['url'] ?? '', maxLines: 1),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => showDialog(context: context, builder: (context) => ChannelEditDialog(channel: ch))),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _db.child('channels/${ch['id']}').remove()),
                ]),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}

class ChannelEditDialog extends StatefulWidget {
  final Map<String, dynamic>? channel;
  final String? categoryId;
  const ChannelEditDialog({super.key, this.channel, this.categoryId});

  @override
  State<ChannelEditDialog> createState() => _ChannelEditDialogState();
}

class _ChannelEditDialogState extends State<ChannelEditDialog> {
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _thumb = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.channel != null) {
      _title.text = widget.channel!['title'] ?? '';
      _url.text = widget.channel!['url'] ?? '';
      _thumb.text = widget.channel!['thumbnail'] ?? '';
    }
  }

  void _save() {
    if (widget.channel != null) {
      FirebaseDatabase.instance.ref().child('channels/${widget.channel!['id']}').update({
        'title': _title.text, 'url': _url.text, 'thumbnail': _thumb.text,
      });
    } else {
      FirebaseDatabase.instance.ref().child('channels').push().set({
        'title': _title.text, 'url': _url.text, 'thumbnail': _thumb.text, 'categoryId': widget.categoryId,
      });
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.channel != null ? 'Edit Channel' : 'Add Channel'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
        TextField(controller: _url, decoration: const InputDecoration(labelText: 'Stream URL (m3u8, etc)')),
        TextField(controller: _thumb, decoration: const InputDecoration(labelText: 'Thumbnail URL')),
      ])),
      actions: [ElevatedButton(onPressed: _save, child: const Text('SAVE'))],
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
  List<Map<String, dynamic>> _banners = [];

  @override
  void initState() {
    super.initState();
    _db.child('banners').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        setState(() => _banners = data.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value)}).toList());
      }
    });
  }

  void _addBanner() {
    if (_banners.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only 5 banners allowed!')));
      return;
    }
    final title = TextEditingController();
    final url = TextEditingController();
    final image = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Add Banner'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(hintText: 'Title')),
        TextField(controller: image, decoration: const InputDecoration(hintText: 'Image URL')),
        TextField(controller: url, decoration: const InputDecoration(hintText: 'Stream URL')),
      ]),
      actions: [ElevatedButton(onPressed: () { _db.child('banners').push().set({'title': title.text, 'imageUrl': image.text, 'url': url.text}); Navigator.pop(context); }, child: const Text('ADD'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banners (Max 5)'), backgroundColor: Colors.transparent, actions: [IconButton(icon: const Icon(Icons.add_circle, color: Colors.red), onPressed: _addBanner)]),
      body: ListView.builder(
        itemCount: _banners.length,
        itemBuilder: (context, i) => ListTile(
          leading: Image.network(_banners[i]['imageUrl'] ?? '', width: 100, errorBuilder: (c,e,s) => const Icon(Icons.image)),
          title: Text(_banners[i]['title'] ?? ''),
          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _db.child('banners/${_banners[i]['id']}').remove()),
        ),
      ),
    );
  }
}

class PushNotificationManager extends StatefulWidget {
  const PushNotificationManager({super.key});

  @override
  State<PushNotificationManager> createState() => _PushNotificationManagerState();
}

class _PushNotificationManagerState extends State<PushNotificationManager> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _image = TextEditingController();

  void _send() {
    // In a real app, this would call FCM or store in Firebase 'notifications' for the app to pick up
    FirebaseDatabase.instance.ref().child('notifications').push().set({
      'title': _title.text, 'body': _body.text, 'image': _image.text, 'timestamp': ServerValue.timestamp,
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification Sent!')));
    _title.clear(); _body.clear(); _image.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push Notifications'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Notification Title')),
          const SizedBox(height: 16),
          TextField(controller: _body, decoration: const InputDecoration(labelText: 'Message Content'), maxLines: 3),
          const SizedBox(height: 16),
          TextField(controller: _image, decoration: const InputDecoration(labelText: 'Image URL')),
          const Spacer(),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(
            onPressed: _send,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('SEND NOTIFICATION', style: TextStyle(fontWeight: FontWeight.bold)),
          )),
        ]),
      ),
    );
  }
}

class GlobalSettingsManager extends StatefulWidget {
  const GlobalSettingsManager({super.key});

  @override
  State<GlobalSettingsManager> createState() => _GlobalSettingsManagerState();
}

class _GlobalSettingsManagerState extends State<GlobalSettingsManager> {
  final _db = FirebaseDatabase.instance.ref();
  int _userCount = 0;
  final _whatsapp = TextEditingController();
  final _telegram = TextEditingController();
  final _share = TextEditingController();

  @override
  void initState() {
    super.initState();
    _db.child('totalUsers').onValue.listen((event) => setState(() => _userCount = (event.snapshot.value as int? ?? 0)));
    _db.child('settings').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        _whatsapp.text = data['whatsappLink'] ?? '';
        _telegram.text = data['telegramLink'] ?? '';
        _share.text = data['shareLink'] ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats & Settings'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(children: [
          Card(color: Colors.red.withOpacity(0.1), child: ListTile(leading: const Icon(Icons.people_alt_rounded, color: Colors.red), title: const Text('Total App Users'), trailing: Text('$_userCount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 32),
          TextField(controller: _whatsapp, decoration: const InputDecoration(labelText: 'WhatsApp Link')),
          TextField(controller: _telegram, decoration: const InputDecoration(labelText: 'Telegram Link')),
          TextField(controller: _share, decoration: const InputDecoration(labelText: 'Share App Link')),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () {
            _db.child('settings').update({'whatsappLink': _whatsapp.text, 'telegramLink': _telegram.text, 'shareLink': _share.text});
          }, child: const Text('SAVE SETTINGS')),
        ]),
      ),
    );
  }
}
