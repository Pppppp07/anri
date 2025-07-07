import 'dart:async';
import 'dart:convert';
import 'package:anri/models/reply_models.dart';
import 'package:anri/home_page.dart';
import 'package:anri/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anri/config/api_config.dart';

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

  final _scrollController = ScrollController();
  Timer? _stopwatchTimer;
  bool _isStopwatchRunning = false;
  late Duration _workedDuration;

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

  final List<String> _statusOptions = [
    'New',
    'In Progress',
    'Waiting Reply',
    'Replied',
    'On Hold',
    'Resolved',
  ];
  final List<String> _priorityOptions = ['Critical', 'High', 'Medium', 'Low'];
  final List<String> _submitAsOptions = [
    'Replied',
    'Waiting Reply',
    'Resolved',
    'In Progress',
    'On Hold',
    'New',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _selectedStatus = widget.ticket.statusText;
    _selectedPriority = widget.ticket.priorityText;
    _selectedCategory = widget.ticket.categoryName;
    _assignedTo = widget.ticket.ownerName;
    _dueDate = widget.ticket.dueDate;
    _isResolved = _selectedStatus == 'Resolved';
    _workedDuration = _parseDuration(widget.ticket.timeWorked);
    _fetchTicketDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _replyMessageController.dispose();
    _scrollController.dispose();
    _stopwatchTimer?.cancel();
    super.dispose();
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
    String twoDigitHours = twoDigits(duration.inHours);
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _toggleStopwatch() {
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
    setState(() => _isStopwatchRunning = !_isStopwatchRunning);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
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
    });
  }

  Future<void> _fetchTicketDetails() async {
    setState(() => _isLoadingDetails = true);
    final headers = await _getAuthHeaders();

    if (headers.isEmpty) {
      setState(() => _isLoadingDetails = false);
      return;
    }
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/get_ticket_details.php?id=${widget.ticket.id}',
    );

    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        if (response.statusCode == 401) {
          _logout(message: 'Sesi tidak valid.');
          return;
        }
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            final repliesData = data['replies'] as List;
            setState(() {
              _replies = repliesData
                  .map((data) => Reply.fromJson(data))
                  .toList();
              _isLoadingDetails = false;
            });
          } else {
            throw Exception('Gagal memuat detail dari API.');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
      'ticket_id': widget.ticket.id.toString(),
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
        Uri.parse('http://192.168.1.2/update_ticket.php'),
        headers: headers,
        body: body,
      );
      if (mounted) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perubahan berhasil disimpan!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          throw Exception(data['message'] ?? 'Gagal menyimpan perubahan.');
        }
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
    if (_replyMessageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesan balasan tidak boleh kosong.'),
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
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/add_reply.php'),
        headers: headers,
        body: {
          'ticket_id': widget.ticket.id.toString(),
          'message': _replyMessageController.text,
          'new_status': _submitAsAction,
          'staff_id': '1',
          'staff_name': widget.currentUserName,
        },
      );
      if (mounted) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Balasan berhasil dikirim!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          throw Exception(data['message'] ?? 'Gagal mengirim balasan.');
        }
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

  void _showTimeWorkedEditor() async {
    if (_isStopwatchRunning) _toggleStopwatch();

    final parts = _formatDuration(_workedDuration).split(':');
    final hoursController = TextEditingController(text: parts[0]);
    final minutesController = TextEditingController(text: parts[1]);
    final secondsController = TextEditingController(text: parts[2]);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Time Worked',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTimeInput(controller: hoursController, label: 'Hours'),
            const SizedBox(height: 8),
            _buildTimeInput(controller: minutesController, label: 'Minutes'),
            const SizedBox(height: 8),
            _buildTimeInput(controller: secondsController, label: 'Seconds'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    child: const Text('Save'),
                    onPressed: () {
                      final h = int.tryParse(hoursController.text) ?? 0;
                      final m = int.tryParse(minutesController.text) ?? 0;
                      final s = int.tryParse(secondsController.text) ?? 0;
                      setState(
                        () => _workedDuration = Duration(
                          hours: h,
                          minutes: m,
                          seconds: s,
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInput({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _showDueDateEditor() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate ?? DateTime.now()),
    );
    if (pickedTime != null) {
      setState(
        () => _dueDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        ),
      );
    }
  }

  void _assignToMe() {
    if (_assignedTo == widget.currentUserName) return;
    setState(() => _assignedTo = widget.currentUserName);
    _saveChanges();
  }

  void _markAsResolved() {
    setState(() {
      _selectedStatus = 'Resolved';
      _isResolved = true;
    });
    _saveChanges();
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

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return const Color(0xFFD32F2F);
      case 'High':
        return const Color(0xFFEF6C00);
      case 'Medium':
        return const Color(0xFF689F38);
      case 'Low':
        return const Color(0xFF0288D1);
      default:
        return Colors.grey;
    }
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Color(0xFFE0F2F7),
            Color(0xFFBBDEFB),
            Colors.blueAccent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.4, 0.7, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: Text(widget.ticket.subject, overflow: TextOverflow.ellipsis),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.info_outline), text: "Detail & Tindakan"),
              Tab(icon: Icon(Icons.forum_outlined), text: "Riwayat & Balas"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildDetailTab(), _buildReplyHistoryTab()],
        ),
      ),
    );
  }

  Widget _buildDetailTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTicketHeader(),
          const SizedBox(height: 16),
          _buildTicketDetailsCard(),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              // <-- TAMBAHKAN KEMBALI THEME INI
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                maintainState: true,
                initiallyExpanded: true,
                title: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      "Deskripsi Permasalahan",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                children: [
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Html(
                      data: widget.ticket.message,
                      style: {
                        "body": Style(
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                          fontSize: FontSize(15.0),
                          lineHeight: LineHeight.em(1.4),
                        ),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTitledCard(
            icon: Icons.construction_outlined,
            title: "Properti & Tindakan",
            child: _buildTindakanContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            // 1. Pastikan Theme ini ada untuk menghilangkan garis atas
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                maintainState: true,
                initiallyExpanded: true,
                // 2. Title diubah menjadi Row
                title: Row(
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Riwayat Balasan (${_replies.length})",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                // 3. Children diawali dengan Divider manual
                children: [
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _isLoadingDetails
                        ? const Center(child: CircularProgressIndicator())
                        : _replies.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                'Belum ada balasan.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _replies.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 24),
                            itemBuilder: (context, index) {
                              final reply = _replies[index];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        reply.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'd MMM yy, HH:mm',
                                        ).format(reply.date),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Html(data: reply.message),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          if (!_isResolved)
            _buildTitledCard(
              icon: Icons.reply,
              title: "Balas Tiket",
              child: _buildReplyForm(),
            ),
        ],
      ),
    );
  }

  Widget _buildTindakanContent() {
    if (_isResolved) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Tiket ini sudah selesai.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        _buildTimeWorkedBar(),
        const SizedBox(height: 16),
        _buildActionShortcuts(),
        const Divider(height: 24),
        _buildStatusEditorRow(),
        const SizedBox(height: 8),
        _buildDropdownRow(
          label: 'Priority:',
          value: _selectedPriority,
          items: _priorityOptions,
          onChanged: (v) => setState(() => _selectedPriority = v!),
        ),
        _buildDropdownRow(
          label: 'Category:',
          value: _selectedCategory,
          items: widget.allCategories,
          onChanged: (v) => setState(() => _selectedCategory = v!),
        ),
        _buildDropdownRow(
          label: 'Assigned to:',
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
                ? const SizedBox.shrink()
                : const Icon(Icons.save_outlined),
            label: _isSaving
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : const Text("Simpan Perubahan"),
            onPressed: _isSaving ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketHeader() {
    return _buildTitledCard(
      icon: Icons.person_pin_circle_outlined,
      title: "Informasi Kontak & Status",
      child: Column(
        children: [
          _buildDetailRowWithIcon(
            Icons.bookmark_border,
            'Status',
            _selectedStatus,
            statusColor: _getStatusColor(_selectedStatus),
          ),
          _buildDetailRowWithIcon(
            Icons.person_outline,
            'Contact',
            widget.ticket.requesterName,
          ),
          _buildDetailRowWithIcon(
            Icons.business_outlined,
            'Unit Kerja',
            widget.ticket.custom1,
          ),
          _buildDetailRowWithIcon(
            Icons.phone_outlined,
            'No Ext/Hp',
            widget.ticket.custom2,
          ),
        ],
      ),
    );
  }

  Widget _buildReplyForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
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
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isSubmittingReply ? null : _submitReply,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(110, 58),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 4,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
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

  Widget _buildTitledCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithIcon(
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
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableInfoRow({
    required String label,
    required String value,
    VoidCallback? onTap,
    VoidCallback? onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          InkWell(
            onTap: _isResolved ? null : onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  if (onClear != null && !_isResolved)
                    IconButton(
                      icon: const Icon(
                        Icons.clear,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onPressed: onClear,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: onTap != null && !_isResolved
                          ? Theme.of(context).primaryColor
                          : null,
                      decoration: onTap != null && !_isResolved
                          ? TextDecoration.underline
                          : null,
                      decorationStyle: TextDecorationStyle.dotted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeWorkedBar() {
    return Container(
      // Kita gunakan InkWell agar ada efek saat ditekan untuk edit
      child: InkWell(
        onTap: _isResolved ? null : _showTimeWorkedEditor,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, size: 28, color: Colors.black54),
              const SizedBox(width: 12),
              // ===== PERUBAHAN UTAMA DI SINI =====
              // Mengelompokkan label dan waktu dalam satu Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Waktu Pengerjaan', // Tanda ':' dihilangkan dari sini
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(_workedDuration),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              // ===== AKHIR PERUBAHAN =====
              const Spacer(),
              // Tombol start/stop timer
              IconButton(
                icon: Icon(
                  _isStopwatchRunning
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: 32, // Sedikit diperbesar agar mudah ditekan
                ),
                onPressed: _isResolved ? null : _toggleStopwatch,
                tooltip: _isStopwatchRunning ? 'Stop Timer' : 'Start Timer',
                color: _isStopwatchRunning
                    ? Colors.orange.shade700
                    : Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionShortcuts() {
    // Ganti Wrap dengan Column untuk memastikan tidak ada overflow horizontal
    return Column(
      // Gunakan crossAxisAlignment untuk membuat tombol memenuhi lebar
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedStatus != 'Resolved')
          ElevatedButton.icon(
            onPressed: _markAsResolved,
            icon: Icon(Icons.check_circle_outline, size: 20),
            label: const Text('Tandai Selesai'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        // Tambahkan spasi antar tombol jika keduanya muncul
        if (_selectedStatus != 'Resolved' &&
            _assignedTo != widget.currentUserName)
          const SizedBox(height: 8),

        if (_assignedTo != widget.currentUserName)
          ElevatedButton.icon(
            onPressed: _assignToMe,
            icon: Icon(Icons.person_add_alt_1_outlined, size: 20),
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
    );
  }

  Widget _buildStatusEditorRow() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Ticket status:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        Expanded(
          flex: 2,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedStatus,
              isExpanded: true,
              items: _statusOptions
                  .map(
                    (String item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        style: TextStyle(
                          color: _getStatusColor(item),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedStatus = v);
              },
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
  }) {
    Widget dropdownContent;

    if (label == 'Priority:') {
      dropdownContent = DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          selectedItemBuilder: (BuildContext context) {
            return items.map<Widget>((String item) {
              return Row(
                children: [
                  Image.asset(
                    _getPriorityIconPath(item),
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(item),
                ],
              );
            }).toList();
          },
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Image.asset(
                    _getPriorityIconPath(item),
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(item),
                ],
              ),
            );
          }).toList(),
          onChanged: _isResolved ? null : onChanged,
        ),
      );
    } else {
      dropdownContent = DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: _isResolved ? null : onChanged,
        ),
      );
    }

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
          Expanded(flex: 2, child: dropdownContent),
        ],
      ),
    );
  }

  Widget _buildTicketDetailsCard() {
    return _buildTitledCard(
      icon: Icons.list_alt_outlined,
      title: "Detail Tiket",
      child: Column(
        children: [
          _buildDetailRow('Tracking ID:', widget.ticket.trackid),
          _buildDetailRow(
            'Created on:',
            DateFormat(
              'yyyy-MM-dd HH:mm:ss',
            ).format(widget.ticket.creationDate),
          ),
          _buildDetailRow(
            'Updated:',
            DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.ticket.lastChange),
          ),
          _buildDetailRow('Replies:', widget.ticket.replies.toString()),
          _buildDetailRow('Last replier:', widget.ticket.lastReplierText),
          _buildEditableInfoRow(
            label: 'Time worked:',
            value: _formatDuration(_workedDuration),
            onTap: _showTimeWorkedEditor,
          ),
          _buildEditableInfoRow(
            label: 'Due date:',
            value: _dueDate != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(_dueDate!)
                : 'None',
            onTap: _showDueDateEditor,
            onClear: _dueDate != null
                ? () => setState(() => _dueDate = null)
                : null,
          ),
        ],
      ),
    );
  }
}
