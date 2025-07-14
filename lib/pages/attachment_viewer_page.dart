import 'dart:io';
import 'package:anri/models/ticket_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http; // <-- Import yang sebelumnya hilang
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';

class AttachmentViewerPage extends StatefulWidget {
  final Attachment attachment;

  const AttachmentViewerPage({super.key, required this.attachment});

  @override
  State<AttachmentViewerPage> createState() => _AttachmentViewerPageState();
}

class _AttachmentViewerPageState extends State<AttachmentViewerPage> {
  String? localFilePath;
  bool isLoading = true;
  String? errorMessage;

  // Cek tipe file berdasarkan ekstensi
  bool get isImage => ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
      .any((ext) => widget.attachment.realName.toLowerCase().endsWith(ext));
  bool get isPdf => widget.attachment.realName.toLowerCase().endsWith('.pdf');

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    // Untuk gambar, PhotoView bisa memuatnya langsung dari URL, jadi tidak perlu diunduh
    if (isImage) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Untuk PDF, kita perlu mengunduhnya ke penyimpanan sementara di perangkat
    if (isPdf) {
       try {
        final uri = Uri.parse(widget.attachment.url);
        final response = await http.get(uri);

        if (response.statusCode == 200) {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/${widget.attachment.realName}');
          await file.writeAsBytes(response.bodyBytes);
          if (mounted) {
            setState(() {
              localFilePath = file.path;
              isLoading = false;
            });
          }
        } else {
          throw Exception('Gagal mengunduh PDF: Status ${response.statusCode}');
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            errorMessage = e.toString();
            isLoading = false;
          });
        }
      }
    } else {
      // Untuk tipe file lain yang tidak didukung viewer
      setState(() {
        isLoading = false;
        errorMessage = "Format file ini tidak dapat ditampilkan di dalam aplikasi.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.attachment.realName),
        elevation: 1,
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Gagal memuat file:\n$errorMessage', textAlign: TextAlign.center),
                  )
                : _buildViewer(),
      ),
    );
  }

  Widget _buildViewer() {
    if (isImage) {
      return PhotoView(
        imageProvider: NetworkImage(widget.attachment.url),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2.0,
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
        ),
      );
    }

    if (isPdf && localFilePath != null) {
      return PDFView(
        filePath: localFilePath!,
        onError: (error) {
          if(mounted) {
            setState(() {
              errorMessage = error.toString();
            });
          }
        },
      );
    }

    // Fallback jika format tidak didukung
    return const Center(child: Text("Format file tidak didukung untuk ditampilkan di aplikasi."));
  }
}