import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:reorderables/reorderables.dart';
import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

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
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 20)]), child: const Icon(Icons.admin_panel_settings_rounded, size: 48, color: Colors.white)),
              const SizedBox(height: 24),
              Text('MIZOFY ADMIN', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 32),
              TextField(controller: _passController, obscureText: true, decoration: InputDecoration(hintText: 'Admin PIN', filled: true, fillColor: Colors.black, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _login, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('UNLOCK DASHBOARD'))),
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
    const HighlightManager(),
    const AdManager(),
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
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_rounded), label: 'Highlights'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign_rounded), label: 'Ads'),
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
      content: const Text('Warning: This will remove all channels in this category.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () { _db.child('categories/$id').remove(); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('DELETE')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('MIZOFY CONTENT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20)), backgroundColor: Colors.transparent, actions: [IconButton(icon: const Icon(Icons.add_circle, color: Colors.red), onPressed: _addCategory)]),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: _selectedCategoryId == cat['id'] ? Colors.red : const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10), boxShadow: _selectedCategoryId == cat['id'] ? [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 5)] : null),
                  child: Center(child: Row(
                    children: [
                      Text(cat['name']?.toUpperCase() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
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
          Expanded(child: _selectedCategoryId == null ? const Center(child: Text("SELECT A CATEGORY TO MANAGE CHANNELS")) : RefreshIndicator(onRefresh: () async => setState(() {}), child: Scrollbar(child: ChannelListManager(categoryId: _selectedCategoryId!, categoryName: _categories.firstWhere((c) => c['id'] == _selectedCategoryId)['name'])))),
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
               Expanded(child: TextField(onChanged: (v) => setState(() => _search = v), decoration: InputDecoration(hintText: 'Search in ${widget.categoryName}...', prefixIcon: const Icon(Icons.search, size: 20), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)))),
               const SizedBox(width: 10),
               FloatingActionButton.small(heroTag: 'm3u', onPressed: _showImportDialog, backgroundColor: Colors.blue, child: const Icon(Icons.upload_file, color: Colors.white)),
               const SizedBox(width: 8),
               FloatingActionButton.small(heroTag: 'add', onPressed: _addChannel, backgroundColor: Colors.red, child: const Icon(Icons.add, color: Colors.white)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              color: const Color(0xFF1A1A1A),
              child: ListTile(
                leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(ch['thumbnail'] ?? '', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.tv))),
                title: Text(ch['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(ch['isEmbed'] == true ? 'Embed Mode' : 'Stream Mode', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit_note_rounded, size: 24, color: Colors.blue), onPressed: () => showDialog(context: context, builder: (context) => ChannelEditDialog(channel: ch, categoryName: widget.categoryName))),
                  IconButton(icon: const Icon(Icons.delete_sweep_rounded, size: 24, color: Colors.red), onPressed: () => _db.child('channels/${ch['id']}').remove()),
                ]),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  void _showImportDialog() {
    final urlCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Bulk M3U Import'),
          content: loading ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())) : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: urlCtrl, decoration: const InputDecoration(hintText: 'M3U URL (http://...)')),
              const SizedBox(height: 16),
              const Text('OR', style: TextStyle(fontSize: 10, color: Colors.white38)),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () async {
                FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['m3u', 'm3u8']);
                if (res != null) {
                  setS(() => loading = true);
                  final content = utf8.decode(res.files.first.bytes ?? await File(res.files.first.path!).readAsBytes());
                  await _parseAndSaveM3U(content);
                  if (mounted) Navigator.pop(context);
                }
              }, icon: const Icon(Icons.file_open), label: const Text('PICK M3U FILE'))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            if (!loading) ElevatedButton(onPressed: () async {
              setS(() => loading = true);
              try {
                final r = await http.get(Uri.parse(urlCtrl.text));
                await _parseAndSaveM3U(r.body);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                setS(() => loading = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }, child: const Text('IMPORT URL')),
          ],
        ),
      ),
    );
  }

  Future<void> _parseAndSaveM3U(String content) async {
    final lines = content.split('\n');
    final db = FirebaseDatabase.instance.ref().child('channels');
    int count = 0;
    
    String? currentName;
    String? currentLogo;

    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('#EXTINF:')) {
        final logoMatch = RegExp(r'tvg-logo="([^"]+)"').firstMatch(line);
        currentLogo = logoMatch?.group(1);
        final nameParts = line.split(',');
        currentName = nameParts.last.trim();
      } else if (line.startsWith('http') && currentName != null) {
        await db.push().set({
          'categoryId': widget.categoryId,
          'title': currentName,
          'url': line,
          'thumbnail': currentLogo ?? '',
          'order': 999,
          'isEmbed': false,
        });
        count++;
        currentName = null;
        currentLogo = null;
      }
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully imported $count channels!')));
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
  bool _isEmbed = false;

  @override
  void initState() {
    super.initState();
    if (widget.channel != null) {
      _title.text = widget.channel!['title'] ?? '';
      _url.text = widget.channel!['url'] ?? '';
      _thumb.text = widget.channel!['thumbnail'] ?? '';
      _isEmbed = widget.channel!['isEmbed'] ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.channel != null ? 'EDIT CHANNEL' : 'NEW CHANNEL', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Channel Title', labelStyle: TextStyle(fontSize: 12))),
        TextField(controller: _url, decoration: InputDecoration(labelText: _isEmbed ? 'Embed URL (Iframe/Web)' : 'Stream URL (m3u8/mpd)', labelStyle: const TextStyle(fontSize: 12))),
        TextField(controller: _thumb, decoration: const InputDecoration(labelText: 'Thumbnail URL', labelStyle: TextStyle(fontSize: 12))),
        const SizedBox(height: 10),
        SwitchListTile(
          title: const Text('Embed Mode', style: TextStyle(fontSize: 12)),
          subtitle: const Text('Enable for Streamlabs/Web links', style: TextStyle(fontSize: 10)),
          value: _isEmbed,
          activeColor: Colors.red,
          onChanged: (v) => setState(() => _isEmbed = v),
        ),
      ])),
      actions: [ElevatedButton(onPressed: () {
        final data = {'title': _title.text, 'url': _url.text, 'thumbnail': _thumb.text, 'categoryId': widget.categoryId ?? widget.channel!['categoryId'], 'category': widget.categoryName, 'isEmbed': _isEmbed};
        if (widget.channel != null) {
          FirebaseDatabase.instance.ref().child('channels/${widget.channel!['id']}').update(data);
        } else {
          FirebaseDatabase.instance.ref().child('channels').push().set(data);
        }
        Navigator.pop(context);
      }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('SAVE CHANGES'))],
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
      appBar: AppBar(title: Text('MIZOFY BANNERS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20)), backgroundColor: Colors.transparent, actions: [IconButton(icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.red), onPressed: () {
        if (_banners.length >= 5) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MAX 5 BANNERS ALLOWED'))); return; }
        final t = TextEditingController(); final u = TextEditingController(); final i = TextEditingController();
        showDialog(context: context, builder: (context) => AlertDialog(
          title: const Text('ADD NEW BANNER'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: t, decoration: const InputDecoration(hintText: 'Display Title')),
            TextField(controller: i, decoration: const InputDecoration(hintText: 'Image Link')),
            TextField(controller: u, decoration: const InputDecoration(hintText: 'Stream/Action URL')),
          ]),
          actions: [ElevatedButton(onPressed: () { _db.child('banners').push().set({'title': t.text, 'imageUrl': i.text, 'url': u.text}); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('UPLOAD'))],
        ));
      })]),
      body: ListView.builder(
        itemCount: _banners.length,
        itemBuilder: (context, i) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF1A1A1A),
          child: ListTile(
            leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_banners[i]['imageUrl'] ?? '', width: 80, height: 45, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.image))),
            title: Text(_banners[i]['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(icon: const Icon(Icons.delete_forever_rounded, color: Colors.red), onPressed: () => _db.child('banners/${_banners[i]['id']}').remove()),
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('BROADCAST SENT!')));
    _title.clear(); _body.clear(); _image.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('MIZOFY BROADCAST', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20)), backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Notification Title', filled: true, fillColor: Colors.white10)),
          const SizedBox(height: 16),
          TextField(controller: _body, decoration: const InputDecoration(labelText: 'Alert Message', filled: true, fillColor: Colors.white10), maxLines: 4),
          const SizedBox(height: 16),
          TextField(controller: _image, decoration: const InputDecoration(labelText: 'Banner Image Link (Optional)', filled: true, fillColor: Colors.white10)),
          const SizedBox(height: 40),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(onPressed: _send, icon: const Icon(Icons.rocket_launch_rounded), label: const Text('SEND TO ALL USERS'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
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
  bool _unityTestMode = false;
  final _wa = TextEditingController(); final _tg = TextEditingController(); final _sh = TextEditingController(); final _mq = TextEditingController();
  final _ver = TextEditingController(); final _upd = TextEditingController(); final _notes = TextEditingController(); final _limit = TextEditingController();
  int _cacheVersion = 0;

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
        _notes.text = d['releaseNotes'] ?? '';
        _limit.text = (d['displayLimit'] ?? '50').toString();
        _forceUpdate = d['forceUpdate'] ?? false;
        _unityTestMode = d['unityTestMode'] ?? false;
        _cacheVersion = d['cacheVersion'] ?? 0;
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('MIZOFY GLOBAL SETTINGS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)), backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.withOpacity(0.2))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ACTIVE INSTALLS', style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)), Text('Real-time Metrics', style: TextStyle(fontSize: 10, color: Colors.white38))]),
              Text('$_userCount', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.red)),
            ]),
          ),
          const SizedBox(height: 32),
          TextField(controller: _mq, decoration: const InputDecoration(labelText: 'Home Marquee Alert')),
          const SizedBox(height: 24),
          const Align(alignment: Alignment.centerLeft, child: Text('FORCE UPDATE SYSTEM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.blueAccent))),
          const SizedBox(height: 12),
          TextField(controller: _ver, decoration: const InputDecoration(labelText: 'Latest App Version')),
          TextField(controller: _upd, decoration: const InputDecoration(labelText: 'Direct APK Download Link')),
          TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Release Notes / What\'s New'), maxLines: 2),
          TextField(controller: _limit, decoration: const InputDecoration(labelText: 'Initial Channels Display Limit (e.g. 50)')),
          SwitchListTile(title: const Text('Enable Mandatory Update'), subtitle: const Text('Blocks user until they update', style: TextStyle(fontSize: 10)), value: _forceUpdate, activeColor: Colors.red, onChanged: (v) => setState(() => _forceUpdate = v)),
          SwitchListTile(title: const Text('Unity Ads Test Mode'), subtitle: const Text('Use for testing only!', style: TextStyle(fontSize: 10)), value: _unityTestMode, activeColor: Colors.blue, onChanged: (v) => setState(() => _unityTestMode = v)),
          const Divider(height: 40, color: Colors.white10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('CATEGORY CACHE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text('Force refresh all users', style: TextStyle(fontSize: 10, color: Colors.white38))]),
                ElevatedButton.icon(
                  onPressed: () {
                    _db.child('globalConfig').update({'cacheVersion': _cacheVersion + 1});
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CACHE REFRESH SIGNAL SENT!')));
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('REFRESH NOW'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                )
              ],
            ),
          ),
          const SizedBox(height: 32),
          TextField(controller: _wa, decoration: const InputDecoration(labelText: 'WhatsApp Contact Link')),
          TextField(controller: _tg, decoration: const InputDecoration(labelText: 'Telegram Channel Link')),
          TextField(controller: _sh, decoration: const InputDecoration(labelText: 'App Sharing Message')),
          const SizedBox(height: 40),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () {
            _db.child('settings').update({'whatsappLink': _wa.text, 'telegramLink': _tg.text, 'shareLink': _sh.text});
            _db.child('globalConfig').update({'alertMsg': _mq.text, 'version': _ver.text, 'updateUrl': _upd.text, 'releaseNotes': _notes.text, 'forceUpdate': _forceUpdate, 'unityTestMode': _unityTestMode, 'displayLimit': int.tryParse(_limit.text) ?? 50});
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GLOBAL CONFIG SYNCHRONIZED!')));
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('SAVE ALL CONFIGURATIONS'))),
        ]),
      ),
    );
  }
}

class HighlightManager extends StatefulWidget {
  const HighlightManager({super.key});

  @override
  State<HighlightManager> createState() => _HighlightManagerState();
}

class _HighlightManagerState extends State<HighlightManager> {
  final _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _highlights = [];

  @override
  void initState() {
    super.initState();
    _db.child('highlights').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        setState(() {
          _highlights = data.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value)}).toList();
          _highlights.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
        });
      } else {
        setState(() => _highlights = []);
      }
    });
  }

  void _addEditHighlight([Map<String, dynamic>? highlight]) {
    final title = TextEditingController(text: highlight?['title'] ?? '');
    final image = TextEditingController(text: highlight?['imageUrl'] ?? '');
    final url = TextEditingController(text: highlight?['url'] ?? '');
    bool isEmbed = highlight?['isEmbed'] ?? false;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(highlight == null ? 'ADD HIGHLIGHT' : 'EDIT HIGHLIGHT'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: image, decoration: const InputDecoration(labelText: 'Image URL')),
                TextField(controller: url, decoration: const InputDecoration(labelText: 'Stream/Embed Link')),
                SwitchListTile(title: const Text('Is Embed?'), value: isEmbed, onChanged: (v) => setS(() => isEmbed = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(onPressed: () {
              final data = {'title': title.text, 'imageUrl': image.text, 'url': url.text, 'isEmbed': isEmbed, 'order': highlight?['order'] ?? _highlights.length};
              if (highlight == null) {
                _db.child('highlights').push().set(data);
              } else {
                _db.child('highlights/${highlight['id']}').update(data);
              }
              Navigator.pop(context);
            }, child: const Text('SAVE')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HIGHLIGHTS MANAGER'), actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _addEditHighlight())]),
      body: ReorderableListView(
        onReorder: (oldI, newI) {
          setState(() {
            final item = _highlights.removeAt(oldI);
            _highlights.insert(newI, item);
            for (int i = 0; i < _highlights.length; i++) {
              _db.child('highlights/${_highlights[i]['id']}').update({'order': i});
            }
          });
        },
        children: _highlights.map((h) => Card(
          key: ValueKey(h['id']),
          margin: const EdgeInsets.all(8),
          child: ListTile(
            leading: Image.network(h['imageUrl'] ?? '', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.image)),
            title: Text(h['title'] ?? ''),
            subtitle: Text(h['url'] ?? '', maxLines: 1),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _addEditHighlight(h)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _db.child('highlights/${h['id']}').remove()),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class AdManager extends StatefulWidget {
  const AdManager({super.key});

  @override
  State<AdManager> createState() => _AdManagerState();
}

class _AdManagerState extends State<AdManager> {
  final _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _ads = [];

  @override
  void initState() {
    super.initState();
    _db.child('ads').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        setState(() {
          _ads = data.entries.map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value)}).toList();
        });
      } else {
        setState(() => _ads = []);
      }
    });
  }

  void _addEditAd([Map<String, dynamic>? ad]) {
    final title = TextEditingController(text: ad?['title'] ?? '');
    final image = TextEditingController(text: ad?['imageUrl'] ?? '');
    final url = TextEditingController(text: ad?['url'] ?? '');

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(ad == null ? 'ADD ADVERTISEMENT' : 'EDIT ADVERTISEMENT'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Ad Title')),
            TextField(controller: image, decoration: const InputDecoration(labelText: 'Ad Image URL')),
            TextField(controller: url, decoration: const InputDecoration(labelText: 'Click Action URL')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () {
            final data = {'title': title.text, 'imageUrl': image.text, 'url': url.text, 'order': ad?['order'] ?? _ads.length};
            if (ad == null) {
              _db.child('ads').push().set(data);
            } else {
              _db.child('ads/${ad['id']}').update(data);
            }
            Navigator.pop(context);
          }, child: const Text('SAVE')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ADVERTISEMENT MANAGER'), actions: [IconButton(icon: const Icon(Icons.add_business_rounded), onPressed: () => _addEditAd())]),
      body: ReorderableListView(
        onReorder: (oldI, newI) {
          setState(() {
            final item = _ads.removeAt(oldI);
            _ads.insert(newI, item);
            for (int i = 0; i < _ads.length; i++) {
              _db.child('ads/${_ads[i]['id']}').update({'order': i});
            }
          });
        },
        children: _ads.map((ad) => Card(
          key: ValueKey(ad['id']),
          margin: const EdgeInsets.all(8),
          child: ListTile(
            leading: Image.network(ad['imageUrl'] ?? '', width: 60, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.campaign)),
            title: Text(ad['title'] ?? ''),
            subtitle: Text(ad['url'] ?? '', maxLines: 1),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _addEditAd(ad)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _db.child('ads/${ad['id']}').remove()),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}
