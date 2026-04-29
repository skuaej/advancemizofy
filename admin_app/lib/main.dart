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

  void _confirmDeleteCategory(String id) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Confirm Delete'),
      content: const Text('Are you sure you want to delete this category and ALL its channels?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () {
          _db.child('categories/$id').remove();
          // Optionally delete channels in this category
          Navigator.pop(context);
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('DELETE')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Content Management'), backgroundColor: Colors.transparent, actions: [IconButton(icon: const Icon(Icons.add_box_rounded, color: Colors.red), onPressed: _addCategory)]),
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
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: _selectedCategoryId == cat['id'] ? Colors.red : const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                  child: Center(child: Row(
                    children: [
                      Text(cat['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      GestureDetector(onTap: () => _confirmDeleteCategory(cat['id']), child: const Icon(Icons.close, size: 14, color: Colors.white24)),
                    ],
                  )),
                ),
              )).toList(),
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(child: _selectedCategoryId == null ? const Center(child: Text("Select a Category to Manage Channels")) : ChannelListManager(categoryId: _selectedCategoryId!, categoryName: _categories.firstWhere((c) => c['id'] == _selectedCategoryId)['name'])),
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

  void _importM3U() {
    final controller = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('M3U Import'),
      content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Paste M3U URL here')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () async {
          try {
            final res = await http.get(Uri.parse(controller.text));
            if (res.statusCode == 200) {
              final lines = res.body.split('\n');
              for (int i = 0; i < lines.length; i++) {
                if (lines[i].startsWith('#EXTINF:')) {
                  // Advanced M3U Parsing for logos
                  final title = lines[i].split(',').last.trim();
                  final logoMatch = RegExp(r'tvg-logo="([^"]+)"').firstMatch(lines[i]);
                  final logo = logoMatch?.group(1) ?? 'https://via.placeholder.com/150';
                  final url = lines[i+1].trim();
                  if (url.startsWith('http')) {
                    _db.child('channels').push().set({
                      'title': title, 'url': url, 'categoryId': widget.categoryId, 
                      'category': widget.categoryName, 'thumbnail': logo, 'order': _channels.length + i
                    });
                  }
                }
              }
            }
          } catch (e) {}
          Navigator.pop(context);
        }, child: const Text('IMPORT')),
      ],
    ));
  }

  void _confirmDeleteChannel(String id) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete Channel'),
      content: const Text('Are you sure you want to delete this channel?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () { _db.child('channels/$id').remove(); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('DELETE')),
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
              Expanded(child: TextField(onChanged: (v) => setState(() => _search = v), decoration: InputDecoration(hintText: 'Search Channels in ${widget.categoryName}...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.cloud_download_rounded, color: Colors.blue), onPressed: _importM3U),
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
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFF1A1A1A),
              child: ListTile(
                leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(ch['thumbnail'] ?? '', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.tv))),
                title: Text(ch['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(ch['url'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => showDialog(context: context, builder: (context) => ChannelEditDialog(channel: ch, categoryName: widget.categoryName))),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDeleteChannel(ch['id'])),
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

  void _save() {
    if (widget.channel != null) {
      FirebaseDatabase.instance.ref().child('channels/${widget.channel!['id']}').update({
        'title': _title.text, 'url': _url.text, 'thumbnail': _thumb.text,
      });
    } else {
      FirebaseDatabase.instance.ref().child('channels').push().set({
        'title': _title.text, 'url': _url.text, 'thumbnail': _thumb.text, 'categoryId': widget.categoryId, 'category': widget.categoryName,
      });
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.channel != null ? 'Edit Channel' : 'Add Channel'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Channel Title')),
        TextField(controller: _url, decoration: const InputDecoration(labelText: 'Stream URL (m3u8, mpd, ts)')),
        TextField(controller: _thumb, decoration: const InputDecoration(labelText: 'Thumbnail/Logo URL')),
      ])),
      actions: [ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('SAVE'))],
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
        TextField(controller: title, decoration: const InputDecoration(hintText: 'Banner Title')),
        TextField(controller: image, decoration: const InputDecoration(hintText: 'Image URL')),
        TextField(controller: url, decoration: const InputDecoration(hintText: 'Stream URL')),
      ]),
      actions: [ElevatedButton(onPressed: () { _db.child('banners').push().set({'title': title.text, 'imageUrl': image.text, 'url': url.text}); Navigator.pop(context); }, child: const Text('ADD'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banner Slides (Max 5)'), backgroundColor: Colors.transparent, actions: [IconButton(icon: const Icon(Icons.add_circle, color: Colors.red), onPressed: _addBanner)]),
      body: ListView.builder(
        itemCount: _banners.length,
        itemBuilder: (context, i) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1A1A1A),
          child: ListTile(
            leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_banners[i]['imageUrl'] ?? '', width: 80, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.image))),
            title: Text(_banners[i]['title'] ?? ''),
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

  void _send() {
    if (_title.text.isEmpty || _body.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill title and body')));
      return;
    }
    FirebaseDatabase.instance.ref().child('notifications').push().set({
      'title': _title.text, 'body': _body.text, 'image': _image.text, 'timestamp': ServerValue.timestamp,
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification Sent Successfully!')));
    _title.clear(); _body.clear(); _image.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Notifications'), backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Engage your users with instant alerts', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 32),
          _buildField('Notification Title', 'e.g. IPL Final Starting Now!', _title),
          const SizedBox(height: 24),
          _buildField('Message Content', 'Enter the alert details...', _body, maxLines: 4),
          const SizedBox(height: 24),
          _buildField('Image URL (Optional)', 'https://image-link.com/img.jpg', _image),
          const SizedBox(height: 48),
          SizedBox(width: double.infinity, height: 60, child: ElevatedButton.icon(
            onPressed: _send,
            icon: const Icon(Icons.send_rounded),
            label: const Text('PUSH NOTIFICATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          )),
        ]),
      ),
    );
  }

  Widget _buildField(String label, String hint, TextEditingController ctrl, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white10),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
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
  final _marquee = TextEditingController();

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
    _db.child('globalConfig').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        _marquee.text = data['alertMsg'] ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Settings'), backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.red.withOpacity(0.3))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total Live Users', style: TextStyle(color: Colors.white54)),
                  Text('Active Installs', style: TextStyle(fontSize: 12, color: Colors.white24)),
                ]),
                Text('$_userCount', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildField('Marquee Alert Message', 'Scrolling text at top...', _marquee),
          _buildField('WhatsApp Support Link', 'https://wa.me/...', _whatsapp),
          _buildField('Telegram Channel Link', 'https://t.me/...', _telegram),
          _buildField('Share App Link', 'https://play.google.com/...', _share),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(
            onPressed: () {
              _db.child('settings').update({'whatsappLink': _whatsapp.text, 'telegramLink': _telegram.text, 'shareLink': _share.text});
              _db.child('globalConfig').update({'alertMsg': _marquee.text});
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings Saved!')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: const Text('UPDATE ALL SETTINGS', style: TextStyle(fontWeight: FontWeight.bold)),
          )),
        ]),
      ),
    );
  }

  Widget _buildField(String label, String hint, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(controller: ctrl, decoration: InputDecoration(hintText: hint, filled: true, fillColor: const Color(0xFF1A1A1A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
        ],
      ),
    );
  }
}
