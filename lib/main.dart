import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SpectreApp());
}

class SpectreApp extends StatelessWidget {
  const SpectreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPECTRE Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080D1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          surface: Color(0xFF111B38),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String serverUrl = 'http://212.68.34.166:8000';
  final String currentUser = 'spectre_admin';
  
  bool isOnline = false;
  String activePackage = 'Yükleniyor...';
  int remainingSeconds = 0;
  List<dynamic> tables = [];
  String actionMessage = '';
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    refreshData();
    refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => refreshData());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshData() async {
    try {
      final healthRes = await http.get(Uri.parse('$serverUrl/health')).timeout(const Duration(seconds: 3));
      final onlineStatus = healthRes.statusCode == 200;

      final lockRes = await http.get(Uri.parse('$serverUrl/api/user/locks/$currentUser'));
      Map<String, dynamic>? lockData;
      if (lockRes.statusCode == 200) {
        lockData = jsonDecode(lockRes.body);
      }

      final roomRes = await http.get(Uri.parse('$serverUrl/spectre-admin/api/oyun-gozlem/masalar'));
      List<dynamic> roomData = [];
      if (roomRes.statusCode == 200) {
        final parsed = jsonDecode(roomRes.body);
        roomData = parsed['records'] ?? [];
      }

      if (mounted) {
        setState(() {
          isOnline = onlineStatus;
          if (lockData != null) {
            activePackage = lockData['package'] ?? (lockData['has_active_license'] == true ? 'VIP' : 'Lisans Yok');
            remainingSeconds = lockData['remaining_seconds'] ?? 0;
          }
          tables = roomData;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isOnline = false);
    }
  }

  Future<void> triggerAction(String featName) async {
    setState(() => actionMessage = '$featName gönderiliyor...');
    try {
      final res = await http.post(
        Uri.parse('$serverUrl/api/action/execute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': currentUser, 'feature_name': featName}),
      );
      if (mounted) {
        if (res.statusCode == 200) {
          setState(() => actionMessage = '✓ Başarılı: $featName devrede');
        } else {
          setState(() => actionMessage = '✕ Kilitli: Yetki yetersiz');
        }
      }
    } catch (_) {
      if (mounted) setState(() => actionMessage = '✕ Bağlantı kurulamadı');
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = remainingSeconds ~/ 86400;
    final hours = (remainingSeconds % 86400) ~/ 3600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF040814),
        elevation: 0,
        title: Row(
          children: [
            const Text('◈ SPECTRE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFA29BFE))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline ? const Color(0x221DD1A1) : const Color(0x22EE5253),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isOnline ? const Color(0xFF1DD1A1) : const Color(0xFFEE5253)),
              ),
              child: Text(
                isOnline ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isOnline ? const Color(0xFF1DD1A1) : const Color(0xFFFF6B6B),
                ),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111B38),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E2B4F)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Operatör:', style: TextStyle(color: Colors.grey)),
                        Text(currentUser, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Paket:', style: TextStyle(color: Colors.grey)),
                        Text(activePackage, style: const TextStyle(color: Color(0xFFA29BFE), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kalan Süre:', style: TextStyle(color: Colors.grey)),
                        Text('$days Gün $hours Saat', style: const TextStyle(color: Color(0xFF7BED9F), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Hızlı Aksiyonlar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  _btn('⚡ Masa Kick', 'player_kick'),
                  _btn('🛡️ Koruma', 'player_save'),
                  _btn('🎯 Takip Et', 'player_follow'),
                  _btn('🎁 Hediye Gönder', 'room_group_gift'),
                  _btn('📦 Sandık Topla', 'lobby_chest'),
                  _btn('🔄 Otomasyon', 'room_automation'),
                ],
              ),
              if (actionMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    actionMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: actionMessage.startsWith('✓') ? const Color(0xFF7BED9F) : const Color(0xFFFF6B6B),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const Text('Canlı Masalar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (tables.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: const Color(0xFF0B132B), borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: Text('Aktif masa bulunmuyor.', style: TextStyle(color: Colors.grey))),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tables.length,
                  itemBuilder: (context, idx) {
                    final t = tables[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101A35),
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(left: BorderSide(color: Color(0xFF6C5CE7), width: 4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t['etiket'] ?? t['id'] ?? 'Masa', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${t['doluluk'] ?? 0}/${t['kapasite'] ?? 4}', style: const TextStyle(color: Color(0xFF7BED9F))),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(String title, String feat) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF121C38),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF22325C)),
        ),
      ),
      onPressed: () => triggerAction(feat),
      child: Text(title, style: const TextStyle(fontSize: 13)),
    );
  }
}
