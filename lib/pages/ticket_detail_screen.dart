import 'dart:async';
import 'dart:convert';
import 'package:anri/config/api_config.dart';
import 'package:anri/models/reply_models.dart';
import 'package:anri/models/ticket_model.dart';
import 'package:anri/pages/login_page.dart';
import 'package:anri/pages/ticket_detail/widgets/detail_tab_view.dart';
import 'package:anri/pages/ticket_detail/widgets/reply_history_tab_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Timer? _stopwatchTimer;
  bool _isStopwatchRunning = false;
  late Duration _workedDuration;

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
    // Jangan tampilkan loading indicator jika hanya refresh biasa
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
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 15));
      if (!mounted) return;

      if (response.statusCode == 401) {
        _logout(message: 'Sesi tidak valid.');
        return;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['ticket_details'] != null) {
          // Buat objek tiket baru dari data yang di-fetch
          final newTicketData = Ticket.fromJson(data['ticket_details']);
          final repliesData = data['replies'] as List;

          setState(() {
            // Perbarui state dengan data baru
            _currentTicket = newTicketData;
            _replies = repliesData.map((data) => Reply.fromJson(data)).toList();
            // Panggil kembali initializeState untuk menyinkronkan UI (dropdown, dll)
            _initializeState();
          });
        } else {
          throw Exception(data['message'] ?? 'Gagal memuat detail dari API.');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saat refresh: $e')));
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
        Uri.parse('${ApiConfig.baseUrl}/update_ticket.php'),
        headers: headers,
        body: body,
      );
      if (!mounted) return;
      final data = json.decode(response.body);
      if (data['success'] == true) {
        setState(() => _hasChanges = true); // Tandai ada perubahan
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
    // 1. Ambil SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    // 2. Dapatkan user_id yang tersimpan (default ke 1 jika tidak ada)
    final int staffId = prefs.getInt('user_id') ?? 1;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/add_reply.php'),
        headers: headers,
        body: {
          'ticket_id': widget.ticket.id.toString(),
          'message': _replyMessageController.text,
          'new_status': _submitAsAction,
          'staff_id': staffId.toString(),
          'staff_name': widget.currentUserName,
        },
      );
      if (!mounted) return;
      final data = json.decode(response.body);
      if (data['success'] == true) {
        setState(() => _hasChanges = true);
        _replyMessageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Balasan berhasil dikirim!'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshTicketData(); // Refresh data di halaman ini
        // HAPUS BARIS INI: Navigator.pop(context, true);
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

  void _markAsResolved() {
    setState(() {
      _selectedStatus = 'Resolved';
      _isResolved = true;
    });
    _saveChanges();
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
      setState(() {
        _dueDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
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
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Waktu Pengerjaan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTimeInput(controller: hoursController, label: 'Jam'),
            const SizedBox(height: 8),
            _buildTimeInput(controller: minutesController, label: 'Menit'),
            const SizedBox(height: 8),
            _buildTimeInput(controller: secondsController, label: 'Detik'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    child: const Text('Simpan'),
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final pageBackgroundDecoration = BoxDecoration(
      gradient: isDarkMode
          ? null
          : const LinearGradient(
              colors: [
                Colors.white,
                Color(0xFFE0F2F7),
                Color(0xFFBBDEFB),
                Colors.blueAccent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
    );


     return PopScope(
      canPop: false, // Cegah pop otomatis
      onPopInvoked: (didPop) {
        if (didPop) return;
        // Kirim hasil `_hasChanges` saat pop manual
        Navigator.of(context).pop(_hasChanges);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 1,
          // DIUBAH: Tambahkan tombol kembali kustom
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
              DetailTabView(
                // --- PERBAIKAN DI SINI ---
                ticket: _currentTicket, // Gunakan baris ini
                // HAPUS BARIS INI: ticket: widget.ticket,
                isResolved: _isResolved,
                isSaving: _isSaving,
                workedDuration: _workedDuration,
                dueDate: _dueDate,
                selectedStatus: _selectedStatus,
                selectedPriority: _selectedPriority,
                selectedCategory: _selectedCategory,
                assignedTo: _assignedTo,
                statusOptions: _statusOptions,
                priorityOptions: _priorityOptions,
                categoryOptions: widget.allCategories,
                teamMemberOptions: widget.allTeamMembers,
                onStatusChanged: (val) {
                  if (val != null) setState(() => _selectedStatus = val);
                },
                onPriorityChanged: (val) {
                  if (val != null) setState(() => _selectedPriority = val);
                },
                onCategoryChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
                onOwnerChanged: (val) {
                  if (val != null) setState(() => _assignedTo = val);
                },
                onSaveChanges: _saveChanges,
                onTapTimeWorked: _showTimeWorkedEditor,
                onTapDueDate: _showDueDateEditor,
                onClearDueDate: () => setState(() => _dueDate = null),
                timeWorkedBar: _buildTimeWorkedBar(),
                actionShortcuts: _buildActionShortcuts(),
              ),
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

  Widget _buildTimeWorkedBar() {
    return InkWell(
      onTap: _isResolved ? null : _showTimeWorkedEditor,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          // --- PERBAIKAN 2: deprecated_member_use ---
          color: Theme.of(context).colorScheme.primaryContainer.withAlpha(77),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            // --- PERBAIKAN 3: deprecated_member_use ---
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(128),
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
        if (!_isResolved && _assignedTo != widget.currentUserName)
          const SizedBox(height: 8),
        if (!_isResolved && _assignedTo != widget.currentUserName)
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
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
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