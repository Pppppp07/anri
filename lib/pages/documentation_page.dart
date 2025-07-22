import 'package:flutter/material.dart';
import 'documentation/tabs/release_guide_tab.dart';
import 'documentation/tabs/technical_guide_tab.dart';
import 'documentation/tabs/user_guide_tab.dart';
// Import 'animated_widgets.dart' tidak diperlukan di sini, jadi kita hapus.

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
        // --- PERBAIKAN DI SINI ---
        // Hapus wrapper 'AnimatedContent' dan keyword 'const'.
        // Widget animasi (StaggeredListView) sudah ada di dalam setiap Tab.
        children: const [
          UserGuideTab(),
          TechnicalGuideTab(),
          ReleaseGuideTab(),
        ],
      ),
    );
  }
}