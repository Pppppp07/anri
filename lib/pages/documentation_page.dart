import 'package:flutter/material.dart';

// --- PERBAIKAN DI SINI: Menggunakan prefix 'as' untuk mengatasi konflik ---
// Kita memberikan "nama panggilan" unik untuk setiap file tab.
import 'documentation/tabs/user_guide_tab.dart' as user_guide;
import 'documentation/tabs/technical_guide_tab.dart' as tech_guide;
import 'documentation/tabs/release_guide_tab.dart' as release_guide;

class DocumentationPage extends StatefulWidget {
  const DocumentationPage({super.key});

  @override
  State<DocumentationPage> createState() => _DocumentationPageState();
}

class _DocumentationPageState extends State<DocumentationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumentasi'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.person_outline),
              text: 'Pengguna',
            ),
            Tab(
              icon: Icon(Icons.code),
              text: 'Teknis',
            ),
            Tab(
              icon: Icon(Icons.rocket_launch_outlined),
              text: 'Rilis',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        // Sekarang kita memanggil widget menggunakan prefix yang telah kita definisikan.
        children: [
          const user_guide.UserGuideTab(),
          const tech_guide.TechnicalGuideTab(),
          const release_guide.ReleaseGuideTab(),
        ],
      ),
    );
  }
}