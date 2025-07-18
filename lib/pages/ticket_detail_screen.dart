// lib/pages/ticket_detail_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:anri/config/api_config.dart';
import 'package:anri/models/reply_models.dart';
import 'package:anri/models/ticket_model.dart';
import 'package:anri/pages/login_page.dart';
import 'package:anri/pages/ticket_detail/widgets/reply_history_tab_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'attachment_viewer_page.dart';

class TicketDetailScreen extends StatefulWidget {
  final Ticket ticket;
  final List<String> allCategories;
  final List<String> allTeamMembers;
  final String currentUserName;

  const TicketDetailScreen({
    super.key,
    required this.ticket,
    required this.allCategories,
    required this.allTeamMembers,
    required this.currentUserName,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Ticket _currentTicket;
  bool _hasChanges = false;
  late String _selectedStatus;
  late String _selectedPriority;
  late String _selectedCategory;
  late String _assignedTo;
  late DateTime? _dueDate;
  late bool _isResolved;
  bool _isSaving = false;
  final _replyMessageController = TextEditingController();
  String _submitAsAction = 'Replied';
  bool _isSubmittingReply = false;
  bool _isLoadingDetails = true;
  List<Reply> _replies = [];
  List<File> _pickedFiles = [];
  Timer? _stopwatchTimer;
  bool _isStopwatchRunning = false;
  late Duration _workedDuration;

  Timer? _refreshTimer;

  final List<String> _statusOptions = [
    'New',
    'Waiting Reply',
    'Replied',
    'In Progress',
    'On Hold',
    'Resolved',
  ];
  final List<String> _priorityOptions = ['Critical', 'High', 'Medium', 'Low'];
  final List<String> _submitAsOptions = [
    'Replied',
    'In Progress',
    'On Hold',
    'Waiting Reply',
    'Resolved',
    'New',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentTicket = widget.ticket;
    _initializeState();
    _refreshTicketData();
    _startAutoRefresh();
  }

  void _initializeState() {
    _selectedStatus = _currentTicket.statusText;
    _selectedPriority = _currentTicket.priorityText;
    _selectedCategory = _currentTicket.categoryName;
    _assignedTo = _currentTicket.ownerName;
    _dueDate = _currentTicket.dueDate;
    _isResolved = _selectedStatus == 'Resolved';
    _workedDuration = _parseDuration(_currentTicket.timeWorked);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _replyMessageController.dispose();
    _stopwatchTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && !_isSaving && !_isSubmittingReply) {
        _checkForUpdates();
      }
    });
  }

  Future<void> _checkForUpdates() async {
    if (!mounted) return;

    try {
      final headers = await _getAuthHeaders();
      if (headers.isEmpty) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/get_ticket_details.php?id=${widget.ticket.id}'),
        headers: headers,
      ).timeout(const Duration(seconds: 4));

      if (!mounted || response.statusCode != 200) return;

      final data = json.decode(response.body);
      if (data['success'] == true && data['replies'] != null) {
        final List<dynamic> newRepliesData = data['replies'];
        
        // --- PERBAIKAN UTAMA DI SINI ---
        // Cek jika jumlah balasan BERBEDA (bisa bertambah atau berkurang)
        if (newRepliesData.length != _replies.length) {
          print('Perubahan riwayat balasan terdeteksi! Memperbarui tampilan...');
          
          final List<Attachment> attachments = (data['attachments'] as List)
              .map((attJson) => Attachment.fromJson(attJson))
              .toList();
          final newTicketData = Ticket.fromJson(data['ticket_details'], attachments: attachments);
          
          setState(() {
            _currentTicket = newTicketData;
            _replies = newRepliesData.map((data) => Reply.fromJson(data)).toList();
            _initializeState(); 
          });
        }
      }
    } catch (e) {
      print('Auto-refresh gagal secara diam-diam: $e');
    }
  }

  Duration _parseDuration(String time) {
    final parts = time.split(':');
    if (parts.length == 3) {
      return Duration(
        hours: int.tryParse(parts[0]) ?? 0,
        minutes: int.tryParse(parts[1]) ?? 0,
        seconds: int.tryParse(parts[2]) ?? 0,
      );
    }
    return Duration.zero;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      if (mounted) _logout(message: 'Sesi tidak valid. Silakan login kembali.');
      return {};
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> _logout({String? message}) async {
    if (!mounted) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool rememberMe = prefs.getBool('rememberMe') ?? false;
    final String? username = prefs.getString('user_username');

    await prefs.clear();

    if (rememberMe && username != null) {
      await prefs.setBool('rememberMe', true);
      await prefs.setString('user_username', username);
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _refreshTicketData() async {
    if (mounted) setState(() => _isLoadingDetails = true);

    final headers = await _getAuthHeaders();
    if (headers.isEmpty) {
      if (mounted) setState(() => _isLoadingDetails = false);
      return;
    }
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/get_ticket_details.php?id=${widget.ticket.id}',
    );

    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;

      if (response.statusCode == 401) {
        _logout(message: 'Sesi tidak valid.');
        return;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['ticket_details'] != null) {
          final List<Attachment> attachments = (data['attachments'] as List)
              .map((attJson) => Attachment.fromJson(attJson))
              .toList();

          final newTicketData = Ticket.fromJson(
            data['ticket_details'],
            attachments: attachments,
          );
          final repliesData = data['replies'] as List;

          setState(() {
            _currentTicket = newTicketData;
            _replies = repliesData.map((data) => Reply.fromJson(data)).toList();
            _initializeState();
          });
        } else {
          throw Exception(data['message'] ?? 'Gagal memuat detail dari API.');
        }
      } else {
        throw Exception(
          'Gagal terhubung ke server (Kode: ${response.statusCode})',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saat refresh: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    final headers = await _getAuthHeaders();
    if (headers.isEmpty) {
      setState(() => _isSaving = false);
      return;
    }
    final body = {
      'ticket_id': _currentTicket.id.toString(),
      'status': _selectedStatus,
      'priority': _selectedPriority,
      'category_name': _selectedCategory,
      'owner_name': _assignedTo,
      'time_worked': _formatDuration(_workedDuration),
      'due_date': _dueDate != null
          ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_dueDate!)
          : '',
    };
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/update_ticket.php'),
        headers: headers,
        body: body,
      );
      if (!mounted) return;
      final data = json.decode(response.body);
      if (data['success'] == true) {
        setState(() => _hasChanges = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perubahan berhasil disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshTicketData();
      } else {
        throw Exception(data['message'] ?? 'Gagal menyimpan perubahan.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submitReply() async {
    if (_replyMessageController.text.trim().isEmpty && _pickedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesan balasan atau lampiran tidak boleh kosong.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isSubmittingReply = true);

    final headers = await _getAuthHeaders();
    if (headers.isEmpty) {
      setState(() => _isSubmittingReply = false);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final int staffId = prefs.getInt('user_id') ?? 1;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/add_reply.php'),
    );
    request.headers.addAll(headers);

    request.fields.addAll({
      'ticket_id': _currentTicket.id.toString(),
      'message': _replyMessageController.text,
      'new_status': _submitAsAction,
      'staff_id': staffId.toString(),
      'staff_name': widget.currentUserName,
    });

    for (var file in _pickedFiles) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'attachments[]',
          file.path,
        ),
      );
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      final data = json.decode(response.body);
      if (data['success'] == true) {
        setState(() {
          _hasChanges = true;
          _pickedFiles.clear();
        });
        _replyMessageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Balasan berhasil dikirim!'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshTicketData();
      } else {
        throw Exception(data['message'] ?? 'Gagal mengirim balasan.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReply = false);
    }
  }

  void _toggleStopwatch() {
    setState(() {
      if (_isStopwatchRunning) {
        _stopwatchTimer?.cancel();
      } else {
        _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() => _workedDuration += const Duration(seconds: 1));
        });
      }
      _isStopwatchRunning = !_isStopwatchRunning;
    });
  }

  void _assignToMe() {
    if (_assignedTo == widget.currentUserName) return;
    setState(() => _assignedTo = widget.currentUserName);
    _saveChanges();
  }

  Future<void> _markAsResolved() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Penyelesaian Tiket'),
          content: const Text(
            'Apakah Anda yakin ingin menandai tiket ini sebagai "Resolved"?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ya, Selesaikan'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _selectedStatus = 'Resolved';
        _isResolved = true;
      });
      _saveChanges();
    }
  }

  Future<void> _launchAttachmentUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka file: $url')),
        );
      }
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null) {
      setState(() {
        _pickedFiles.addAll(result.paths.map((path) => File(path!)).toList());
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _pickedFiles.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final pageBackgroundDecoration = BoxDecoration(
      gradient: LinearGradient(
        colors: isDarkMode
            ? [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).scaffoldBackgroundColor,
              ]
            : [
                Colors.white,
                const Color(0xFFE0F2F7),
                const Color(0xFFBBDEFB),
                Colors.blueAccent,
              ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.of(context).pop(_hasChanges);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop(_hasChanges);
            },
          ),
          title: const Text('Detail Tiket'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.info_outline), text: "Detail & Tindakan"),
              Tab(icon: Icon(Icons.forum_outlined), text: "Riwayat & Balas"),
            ],
          ),
        ),
        body: Container(
          decoration: pageBackgroundDecoration,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDetailTabContent(),
              ReplyHistoryTabView(
                isLoadingDetails: _isLoadingDetails,
                replies: _replies,
                isResolved: _isResolved,
                replyForm: _buildReplyForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTabContent() {
    if (_isLoadingDetails) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isResolved) ...[
            _buildResolvedBanner(),
            const SizedBox(height: 16),
          ],
          _buildTitledCard(
            icon: Icons.person_pin_circle_outlined,
            title: "Informasi Kontak & Status",
            child: _buildInfoCardContent(),
          ),
          const SizedBox(height: 16),
          _buildDescriptionCard(),
          const SizedBox(height: 16),
          _buildAttachmentsCard(),
          if (_currentTicket.attachments.isNotEmpty) const SizedBox(height: 16),
          _buildTitledCard(
            icon: Icons.list_alt_outlined,
            title: "Detail Tiket",
            child: _buildTicketDetailsContent(),
          ),
          if (!_isResolved) ...[
            const SizedBox(height: 16),
            _buildTitledCard(
              icon: Icons.construction_outlined,
              title: "Properti & Tindakan",
              child: _buildTindakanContent(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard() {
    if (_currentTicket.attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    String formatBytes(int bytes, int decimals) {
      if (bytes <= 0) return "0 B";
      const suffixes = ["B", "KB", "MB", "GB", "TB"];
      var i = (log(bytes) / log(1024)).floor();
      return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
    }

    return _buildTitledCard(
      icon: Icons.attach_file,
      title: "Lampiran (${_currentTicket.attachments.length})",
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _currentTicket.attachments.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final attachment = _currentTicket.attachments[index];
          final name = attachment.realName.toLowerCase();
          final isImage = [
            '.jpg',
            '.jpeg',
            '.png',
            '.gif',
            '.bmp',
            '.webp',
          ].any((ext) => name.endsWith(ext));
          final isPdf = name.endsWith('.pdf');

          void handleTap() {
            if (isImage || isPdf) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AttachmentViewerPage(attachment: attachment),
                ),
              );
            } else {
              _launchAttachmentUrl(attachment.url);
            }
          }

          if (isImage) {
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: handleTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.network(
                      attachment.url,
                      fit: BoxFit.cover,
                      height: 150,
                      width: double.infinity,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const SizedBox(
                              height: 150,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                      errorBuilder: (context, error, stack) => const SizedBox(
                        height: 150,
                        child: Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        attachment.realName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return Card(
              child: ListTile(
                leading: Icon(
                  isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.description_outlined,
                ),
                title: Text(
                  attachment.realName,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(formatBytes(attachment.size, 2)),
                trailing: const Icon(Icons.open_in_new),
                onTap: handleTap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildTitledCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black.withAlpha(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildResolvedBanner() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color successColor = isDarkMode
        ? Colors.greenAccent.shade400
        : Colors.green.shade800;
    final Color backgroundColor = isDarkMode
        ? Colors.green.withAlpha(25)
        : Colors.green.shade50;
    final Color borderColor = isDarkMode
        ? Colors.green.withAlpha(50)
        : Colors.green.shade200;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, color: successColor),
          const SizedBox(width: 12),
          Text(
            'Tiket ini telah diselesaikan.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: successColor,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCardContent() {
    return Column(
      children: [
        _buildInfoRow(
          Icons.bookmark_border,
          'Status:',
          _currentTicket.statusText,
          statusColor: _getStatusColor(_currentTicket.statusText),
        ),
        _buildInfoRow(
          Icons.person_outline,
          'Contact:',
          _currentTicket.requesterName,
        ),
        _buildInfoRow(
          Icons.business_outlined,
          'Unit Kerja:',
          _currentTicket.custom1,
        ),
        _buildInfoRow(
          Icons.phone_outlined,
          'No Ext/Hp:',
          _currentTicket.custom2,
        ),
      ],
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      elevation: 1,
      shadowColor: Colors.black.withAlpha(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          maintainState: true,
          initiallyExpanded: true,
          title: Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              const SizedBox(width: 16),
              const Text(
                "Deskripsi Permasalahan",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          children: [
            const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subject: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          _currentTicket.subject,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Html(
                    data: _currentTicket.message,
                    style: {
                      "body": Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        fontSize: FontSize(15.0),
                        lineHeight: LineHeight.em(1.4),
                      ),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketDetailsContent() {
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
    return Column(
      children: [
        _buildStaticInfoRow("Tracking ID:", _currentTicket.trackid),
        _buildStaticInfoRow(
          "Dibuat pada:",
          dateFormat.format(_currentTicket.creationDate),
        ),
        _buildStaticInfoRow(
          "Diperbarui:",
          dateFormat.format(_currentTicket.lastChange),
        ),
        _buildStaticInfoRow("Balasan:", _currentTicket.replies.toString()),
        _buildStaticInfoRow(
          "Balasan terakhir:",
          _currentTicket.lastReplierText,
        ),
      ],
    );
  }

  Widget _buildTimeWorkedBar() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: 28,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waktu Pengerjaan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDuration(_workedDuration),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                _isStopwatchRunning
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 32,
              ),
              onPressed: _isResolved ? null : _toggleStopwatch,
              tooltip: _isStopwatchRunning ? 'Stop Timer' : 'Start Timer',
              color: _isStopwatchRunning
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionShortcuts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isResolved)
          ElevatedButton.icon(
            onPressed: _markAsResolved,
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text('Tandai Selesai'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        if (!_isResolved && _assignedTo != widget.currentUserName) ...[
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _assignToMe,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
            label: const Text('Tugaskan ke Saya'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTindakanContent() {
    return Column(
      children: [
        _buildTimeWorkedBar(),
        const SizedBox(height: 16),
        _buildActionShortcuts(),
        const Divider(height: 32),
        _buildDropdownRow(
          label: 'Status tiket:',
          value: _selectedStatus,
          items: _statusOptions,
          onChanged: (v) => setState(() => _selectedStatus = v!),
          isStatus: true,
        ),
        _buildDropdownRow(
          label: 'Prioritas:',
          value: _selectedPriority,
          items: _priorityOptions,
          onChanged: (v) => setState(() => _selectedPriority = v!),
          isPriority: true,
        ),
        _buildDropdownRow(
          label: 'Kategori:',
          value: _selectedCategory,
          items: widget.allCategories,
          onChanged: (v) => setState(() => _selectedCategory = v!),
        ),
        _buildDropdownRow(
          label: 'Ditugaskan ke:',
          value: _assignedTo,
          items: widget.allTeamMembers,
          onChanged: (v) => setState(() => _assignedTo = v!),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            icon: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: _isSaving
                ? const SizedBox.shrink()
                : const Text("Simpan Perubahan"),
            onPressed: _isSaving ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool isStatus = false,
    bool isPriority = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          Expanded(
            flex: 2,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: items.map((String item) {
                  Widget child;
                  if (isPriority) {
                    child = Row(
                      children: [
                        Image.asset(
                          _getPriorityIconPath(item),
                          height: 16,
                          width: 16,
                          color: _getPriorityColor(item),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item,
                          style: TextStyle(
                            color: _getPriorityColor(item),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  } else if (isStatus) {
                    child = Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _getStatusColor(item),
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  } else {
                    child = Text(item, overflow: TextOverflow.ellipsis);
                  }
                  return DropdownMenuItem<String>(value: item, child: child);
                }).toList(),
                onChanged: _isResolved ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pickedFiles.isNotEmpty) ...[
          Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: _pickedFiles.length,
              itemBuilder: (context, index) {
                final file = _pickedFiles[index];
                return ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    file.path.split('/').last,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _removeFile(index),
                  ),
                );
              },
            ),
          ),
        ],
        TextFormField(
          controller: _replyMessageController,
          decoration: const InputDecoration(
            hintText: 'Ketik balasan Anda...',
            border: OutlineInputBorder(),
          ),
          maxLines: 6,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _submitAsAction,
                items: _submitAsOptions
                    .map(
                      (v) => DropdownMenuItem<String>(
                        value: v,
                        child: Text(
                          v,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _getStatusColor(v),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  if (v != null) _submitAsAction = v;
                }),
                decoration: const InputDecoration(
                  labelText: 'Submit sebagai',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _pickFiles,
              tooltip: 'Lampirkan File',
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(),
            ),
            ElevatedButton(
              onPressed: _isSubmittingReply ? null : _submitReply,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                minimumSize: const Size(0, 58),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: _isSubmittingReply
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ],
    );
  }

  String _getPriorityIconPath(String priority) {
    switch (priority) {
      case 'Critical':
        return 'assets/images/label-critical.png';
      case 'High':
        return 'assets/images/label-high.png';
      case 'Medium':
        return 'assets/images/label-medium.png';
      case 'Low':
        return 'assets/images/label-low.png';
      default:
        return 'assets/images/label-medium.png';
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return Colors.red.shade400;
      case 'High':
        return Colors.orange.shade400;
      case 'Medium':
        return Colors.lightGreen.shade400;
      case 'Low':
        return Colors.lightBlue.shade400;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'New':
        return const Color(0xFFD32F2F);
      case 'Waiting Reply':
        return const Color(0xFFE65100);
      case 'Replied':
        return const Color(0xFF1976D2);
      case 'In Progress':
        return const Color(0xFF673AB7);
      case 'On Hold':
        return const Color(0xFFC2185B);
      case 'Resolved':
        return const Color(0xFF388E3C);
      default:
        return Colors.grey.shade700;
    }
  }
}