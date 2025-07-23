import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'animated_widgets.dart'; // Import untuk widget animasi

/// Kartu utama untuk setiap bagian dokumentasi dengan ikon, judul, dan konten yang bisa diperluas.
class DocumentationTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  const DocumentationTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.initiallyExpanded = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // Penting untuk visual yang lebih rapi
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon, color: iconColor, size: 28),
        title: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        childrenPadding: EdgeInsets.zero, // Hapus padding default
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            // Menerapkan widget animasi ke semua children di dalam kartu
            child: AnimatedChildren(children: children),
          ),
        ],
      ),
    );
  }
}

/// Widget untuk menampilkan detail fitur dengan judul dan deskripsi.
class FeatureDetail extends StatelessWidget {
  final String title;
  final String description;

  const FeatureDetail({super.key, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(description, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Kartu untuk menampilkan informasi tentang tabel database.
class DatabaseTableCard extends StatelessWidget {
  final String tableName;
  final String description;

  const DatabaseTableCard({super.key, required this.tableName, required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface.withAlpha(128), // Perbaikan: withOpacity -> withAlpha
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor, width: 0.5),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tableName, style: theme.textTheme.titleSmall?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Kartu untuk menampilkan dokumentasi endpoint API.
class ApiEndpointCard extends StatelessWidget {
  final String method;
  final String endpoint;
  final String description;
  final String? params;
  final String? requestBody;
  final String responseBody;
  final bool isError;

  const ApiEndpointCard({
    super.key,
    required this.method,
    required this.endpoint,
    required this.description,
    this.params,
    this.requestBody,
    required this.responseBody,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color methodColor;
    if (isError) {
      methodColor = Colors.red.shade700;
    } else if (method == 'POST') {
      methodColor = Colors.orange.shade700;
    } else if (method == 'GET') {
      methodColor = Colors.green.shade700;
    } else {
      methodColor = Colors.grey.shade700;
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface.withAlpha(128), // Perbaikan: withOpacity -> withAlpha
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor, width: 0.5),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: methodColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    method,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    endpoint,
                    style: theme.textTheme.bodyLarge?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodyMedium),
            if (params != null) ...[
              const SizedBox(height: 8),
              _buildCodeBlock('Parameters:', params!, theme),
            ],
            if (requestBody != null) ...[
              const SizedBox(height: 8),
              _buildCodeBlock('Request Body:', requestBody!, theme),
            ],
            const SizedBox(height: 8),
            _buildCodeBlock('Response Body:', responseBody, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeBlock(String title, String code, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(204), // Perbaikan: withOpacity -> withAlpha
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// Kartu detail untuk menjelaskan peran setiap Provider dalam manajemen state.
class ProviderDetailCard extends StatelessWidget {
  final String providerName;
  final String description;

  const ProviderDetailCard({
    super.key,
    required this.providerName,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: theme.colorScheme.surface.withAlpha(128), // Perbaikan: withOpacity -> withAlpha
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              providerName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu untuk mendeskripsikan setiap komponen dalam arsitektur aplikasi.
class ArchitecturalComponentCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;

  const ArchitecturalComponentCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.dividerColor, width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget untuk menampilkan langkah dalam alur data dengan visual yang lebih baik.
class DataFlowStep extends StatelessWidget {
  final String step;
  final String actor;
  final String action;
  final IconData icon;
  final bool isLastStep;

  const DataFlowStep({
    super.key,
    required this.step,
    required this.actor,
    required this.action,
    required this.icon,
    this.isLastStep = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                radius: 16,
                child: Text(
                  step,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              if (!isLastStep)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.primary.withAlpha(77), // Perbaikan: withOpacity -> withAlpha
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      actor,
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 26, top: 4, bottom: 24),
                  child: Text(
                    action,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Item untuk checklist rilis.
class ReleaseChecklistItem extends StatelessWidget {
  final bool isDone;
  final String text;

  const ReleaseChecklistItem({super.key, required this.isDone, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(isDone ? Icons.check_box : Icons.check_box_outline_blank, color: isDone ? Colors.green : null),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : null))),
        ],
      ),
    );
  }
}

/// Tombol untuk menghubungi pengembang.
class ContactButton extends StatelessWidget {
  const ContactButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.email_outlined),
        label: const Text('Hubungi Pengembang'),
        onPressed: () async {
          final Uri emailLaunchUri = Uri(
            scheme: 'mailto',
            path: 'developer.email@example.com', // Ganti dengan email Anda
            query: 'subject=Tanya%20Seputar%20Aplikasi%20Helpdesk%20ANRI',
          );

          if (await canLaunchUrl(emailLaunchUri)) {
            await launchUrl(emailLaunchUri);
          } else {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tidak dapat membuka aplikasi email.')),
            );
          }
        },
      ),
    );
  }
}

// Menambahkan widget yang mungkin hilang sebelumnya untuk kelengkapan
/// Item untuk legenda visual.
class LegendItem extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String label;

  const LegendItem({super.key, required this.color, this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon ?? Icons.circle, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

/// Item untuk daftar FAQ.
class FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const FaqItem({super.key, required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Q: $question', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('A: $answer'),
        ],
      ),
    );
  }
}

/// Widget untuk menampilkan langkah-langkah bernomor (versi sederhana).
class StepTile extends StatelessWidget {
  final String step;
  final String title;
  final String description;

  const StepTile({super.key, required this.step, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu untuk menampilkan item dalam struktur folder proyek.
class ProjectStructureItem extends StatelessWidget {
  final String folderName;
  final String description;

  const ProjectStructureItem({
    super.key,
    required this.folderName,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.folder_outlined, color: theme.colorScheme.secondary, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folderName,
                  style: theme.textTheme.titleSmall?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu untuk menampilkan informasi tentang sebuah dependensi/package.
class DependencyCard extends StatelessWidget {
  final String packageName;
  final String description;

  const DependencyCard({
    super.key,
    required this.packageName,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface.withAlpha(128),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor, width: 0.5),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              packageName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}