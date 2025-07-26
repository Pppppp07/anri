import 'package:flutter/material.dart';

// Import semua file bagian yang baru dibuat
import 'technical_guide_sections/api_endpoints_section.dart';
import 'technical_guide_sections/architecture_section.dart';
import 'technical_guide_sections/database_structure_section.dart';
import 'technical_guide_sections/dependencies_section.dart';
import 'technical_guide_sections/error_handling_section.dart';
import 'technical_guide_sections/folder_structure_section.dart';
import 'technical_guide_sections/notification_flow_section.dart';
import 'technical_guide_sections/security_guide_section.dart';
import 'technical_guide_sections/state_management_section.dart';
import 'technical_guide_sections/theming_section.dart';

// Import widget umum yang dibutuhkan
import '../widgets/animated_widgets.dart';
import '../widgets/content_widgets.dart';
import '../widgets/header_card.dart';

// --- PERBAIKAN DI SINI ---
class TechnicalGuideTab extends StatelessWidget {
  const TechnicalGuideTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StaggeredListView(
      children: [
        const HeaderCard(
          title: 'Dokumentasi Teknis Mendalam',
          subtitle: 'Detail arsitektur, alur data, dan panduan teknis untuk pengembang.',
        ),
        
        // Memanggil setiap widget bagian
        const ArchitectureSection(),
        const NotificationFlowSection(),
        const FolderStructureSection(),
        const DependenciesSection(),
        const SecurityGuideSection(),
        const ThemingSection(),
        const StateManagementSection(),
        const DatabaseStructureSection(),
        const ApiEndpointsSection(),
        const ErrorHandlingSection(),

        // Widget penutup
        const SizedBox(height: 24),
        const ContactButton(),
        const SizedBox(height: 16),
      ],
    );
  }
}