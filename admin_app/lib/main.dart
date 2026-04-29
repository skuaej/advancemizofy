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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid PIN')));
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
              const Icon(Icons.lock_outline_rounded, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text('Admin Access', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(controller: _passController, obscureText: true, decoration: InputDecoration(hintText: 'Password', filled: true, fillColor: Colors.black, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _login, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('LOGIN'))),
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
          BottomNavigationBarItem(icon: Icon(Icons.photo_library_rounded), label: 'Banners'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active_rounded), label: 'Push'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_suggest_rounded), label: 'Settings'),
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
      title: const Text('New Category'),
      content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () { _db.child('categories').push().set({'name': controller.text, 'order': _categories.length}); Navigator.pop(context); }, child: const Text('ADD')),
      ],
    ));
  }

  void _editCategory(String id, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Edit Category'),
      content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'New Name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () { _db.child('categories/$id').update({'name': controller.text}); Navigator.pop(context); }, child: const Text('UPDATE')),
      ],
    ));
  }

  void _confirmDeleteCategory(String id) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete Category?'),
      content: const Text('Warning: This will remove the category permanently.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () { _db.child('categories/$id').remove(); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('DELETE')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Content'), backgroundColor: Colors.transparent, actions: [IconButton(icon: const Icon(Icons.add_circle, color: Colors.red), onPressed: _addCategory)]),
      body: Column(
        children: [
          SizedBox(
            height: 70,
            child: ReorderableRow(
              onReorder: (oldI, newI) {
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
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: _selectedCategoryId == cat['id'] ? Colors.red : const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                  child: Center(child: Row(
                    children: [
                      Text(cat['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      GestureDetector(onTap: () => _editCategory(cat['id'], cat['name']), child: const Icon(Icons.edit, size: 14, color: Colors.blue)),
                      const SizedBox(width: 8),
                      GestureDetector(onTap: () => _confirmDeleteCategory(cat['id']), child: const Icon(Icons.delete, size: 14, color: Colors.red)),
                    ],
                  )),
                ),
              )).toList(),
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(child: _selectedCategoryId == null ? const Center(child: Text("Select Category")) : ChannelListManager(categoryId: _selectedCategoryId!, categoryName: _categories.firstWhere((c) => c['id'] == _selectedCategoryId)['name'])),
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
          _channels.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
        });
      }
    });
  }

  void _addChannel() {
    showDialog(context: context, builder: (context) => ChannelEditDialog(categoryId: widget.categoryId, categoryName: widget.categoryName));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _channels.where((ch) => ch['title'].toString().toLowerCase().contains(_search.toLowerCase())).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(child: TextField(onChanged: (v) => setState(() => _search = v), decoration: InputDecoration(hintText: 'Search in ${widget.categoryName}...', prefixIcon: const Icon(Icons.search, size: 20), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: _addChannel),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView(
            onReorder: (oldI, newI) {
              setState(() {
                final item = _channels.removeAt(oldI);
                _channels.insert(newI, item);
                for (int i = 0; i < _channels.length; i++) {
                  _db.child('channels/${_channels[i]['id']}').update({'order': i});
                }
              });
            },
            children: filtered.map((ch) => Card(
              key: ValueKey(ch['id']),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: const Color(0xFF1A1A1A),
              child: ListTile(
                leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(ch['thumbnail'] ?? '', width: 45, height: 45, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.tv))),
                title: Text(ch['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), onPressed: () => showDialog(context: context, builder: (context) => ChannelEditDialog(channel: ch, categoryName: widget.categoryName))),
                  IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () {
                    _db.child('channels/${ch['id']}').remove();
                  }),
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
  final String categoryName;
  const ChannelEditDialog({super.key, this.channel, this.categoryId, required this.categoryName});

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.channel != null ? 'Edit Channel' : 'New Channel'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
        TextField(controller: _url, decoration: const InputDecoration(labelText: 'Stream URL')),
        TextField(controller: _thumb, decoration: const InputDecoration(labelText: 'Logo URL')),
      ])),
      actions: [ElevatedButton(onPressed: () {
        final data = {'title': _title.text, 'url': _url.text, 'thumbnail': _thumb.text, 'categoryId': widget.categoryId ?? widget.channel!['categoryId'], 'category': widget.categoryName};
        if (widget.channel != null) {
          FirebaseDatabase.instance.ref().child('channels/${widget.channel!['id']}').update(data);
        } else {
          FirebaseDatabase.instance.ref().child('channels').push().set(data);
        }
        Navigator.pop(context);
      }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('SAVE'))],
    );
  }
}

class BannerManager extends StatefulWidget {
  const BannerManager({super.key});

  @override
  State<BannerManager> createState() => _BannerManagerState();
}

class _BannerManagerState extends State<BannerManager> {
  final _db = FirebaseDatabase.instance.ref();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banners'), backgroundColor: Colors.transparent, actions: [IconButton(icon: const Icon(Icons.add_circle, color: Colors.red), onPressed: () {
        if (_banners.length >= 5) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limit reached!'))); return; }
        final t = TextEditingController(); final u = TextEditingController(); final i = TextEditingController();
        showDialog(context: context, builder: (context) => AlertDialog(
          title: const Text('Add Banner'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: t, decoration: const InputDecoration(hintText: 'Title')),
            TextField(controller: i, decoration: const InputDecoration(hintText: 'Image URL')),
            TextField(controller: u, decoration: const InputDecoration(hintText: 'Stream URL')),
          ]),
          actions: [ElevatedButton(onPressed: () { _db.child('banners').push().set({'title': t.text, 'imageUrl': i.text, 'url': u.text}); Navigator.pop(context); }, child: const Text('ADD'))],
        ));
      })]),
      body: ListView.builder(
        itemCount: _banners.length,
        itemBuilder: (context, i) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: const Color(0xFF1A1A1A),
          child: ListTile(
            leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_banners[i]['imageUrl'] ?? '', width: 80, height: 45, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.image))),
            title: Text(_banners[i]['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _db.child('banners/${_banners[i]['id']}').remove()),
          ),
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

  void _send() async {
    if (_title.text.isEmpty || _body.text.isEmpty) return;
    await FirebaseDatabase.instance.ref().child('notifications').push().set({
      'title': _title.text, 'body': _body.text, 'image': _image.text, 'timestamp': ServerValue.timestamp,
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification Dispatched!')));
    _title.clear(); _body.clear(); _image.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Broadcast'), backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Alert Title')),
          const SizedBox(height: 16),
          TextField(controller: _body, decoration: const InputDecoration(labelText: 'Message'), maxLines: 3),
          const SizedBox(height: 16),
          TextField(controller: _image, decoration: const InputDecoration(labelText: 'Image Link')),
          const SizedBox(height: 40),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(onPressed: _send, icon: const Icon(Icons.send), label: const Text('PUSH NOW'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
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
  bool _forceUpdate = false;
  final _wa = TextEditingController(); final _tg = TextEditingController(); final _sh = TextEditingController(); final _mq = TextEditingController();
  final _ver = TextEditingController(); final _upd = TextEditingController();

  @override
  void initState() {
    super.initState();
    _db.child('totalUsers').onValue.listen((e) => setState(() => _userCount = (e.snapshot.value as int? ?? 0)));
    _db.child('settings').onValue.listen((e) {
      if (e.snapshot.value is Map) {
        final d = e.snapshot.value as Map;
        _wa.text = d['whatsappLink'] ?? ''; _tg.text = d['telegramLink'] ?? ''; _sh.text = d['shareLink'] ?? '';
      }
    });
    _db.child('globalConfig').onValue.listen((e) {
      if (e.snapshot.value is Map) {
        final d = e.snapshot.value as Map;
        _mq.text = d['alertMsg'] ?? '';
        _ver.text = d['version'] ?? '1.0.0';
        _upd.text = d['updateUrl'] ?? '';
        _forceUpdate = d['forceUpdate'] ?? false;
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Card(color: Colors.red.withOpacity(0.1), child: ListTile(title: const Text('Live User Count'), trailing: Text('$_userCount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)))),
          const SizedBox(height: 32),
          TextField(controller: _mq, decoration: const InputDecoration(labelText: 'Marquee Alert')),
          const SizedBox(height: 24),
          const Text('App Version Control', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          TextField(controller: _ver, decoration: const InputDecoration(labelText: 'Latest Version (e.g. 1.1.0)')),
          TextField(controller: _upd, decoration: const InputDecoration(labelText: 'Update Link (APK URL)')),
          SwitchListTile(title: const Text('Force Update'), value: _forceUpdate, activeColor: Colors.red, onChanged: (v) => setState(() => _forceUpdate = v)),
          const Divider(height: 40),
          TextField(controller: _wa, decoration: const InputDecoration(labelText: 'WhatsApp')),
          TextField(controller: _tg, decoration: const InputDecoration(labelText: 'Telegram')),
          TextField(controller: _sh, decoration: const InputDecoration(labelText: 'Share URL')),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () {
            _db.child('settings').update({'whatsappLink': _wa.text, 'telegramLink': _tg.text, 'shareLink': _sh.text});
            _db.child('globalConfig').update({'alertMsg': _mq.text, 'version': _ver.text, 'updateUrl': _upd.text, 'forceUpdate': _forceUpdate});
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings Saved!')));
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('SAVE ALL SETTINGS'))),
        ]),
      ),
    );
  }
}
