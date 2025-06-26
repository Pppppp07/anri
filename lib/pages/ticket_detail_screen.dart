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

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _scrollController = ScrollController();
  final _replyFormKey = GlobalKey();

  // State untuk Stopwatch
  Timer? _stopwatchTimer;
  bool _isStopwatchRunning = false;
  late Duration _workedDuration;

  // State lainnya
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
    'New', 'In Progress', 'Waiting Reply', 'Replied', 'On Hold', 'Resolved'
  ];
  final List<String> _priorityOptions = ['Critical', 'High', 'Medium', 'Low'];
  final List<String> _submitAsOptions = [
    'Replied', 'Waiting Reply', 'Resolved', 'In Progress', 'On Hold', 'New'
  ];

  @override
  void initState() {
    super.initState();
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
    _replyMessageController.dispose();
    _scrollController.dispose();
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  // --- FUNGSI-FUNGSI LOGIC & KEAMANAN ---

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
        setState(() {
          _workedDuration += const Duration(seconds: 1);
        });
      });
    }
    setState(() {
      _isStopwatchRunning = !_isStopwatchRunning;
    });
  }
  
  void _scrollToReplyForm() {
    final context = _replyFormKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    if (token == null) {
      if (mounted) _logout(message: 'Sesi tidak valid. Silakan login kembali.');
      return {};
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> _logout({String? message}) async {
    if (!mounted) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
        }
      }
    });
  }

  Future<void> _fetchTicketDetails() async {
    setState(() => _isLoadingDetails = true);
    final headers = await _getAuthHeaders();
    if (headers.isEmpty) { setState(() => _isLoadingDetails = false); return; }

    final url = Uri.parse('http://127.0.0.1:8080/anri_helpdesk_api/get_ticket_details.php?id=${widget.ticket.id}');
    try {
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 15));
      if (mounted) {
        if (response.statusCode == 401) { _logout(message: 'Sesi tidak valid.'); return; }
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            final List<dynamic> repliesData = responseData['replies'];
            setState(() {
              _replies = repliesData.map((data) => Reply.fromJson(data)).toList();
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error memuat riwayat balasan: $e')));
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    final finalTimeWorked = _formatDuration(_workedDuration);
    final url = Uri.parse('http://127.0.0.1:8080/anri_helpdesk_api/update_ticket.php');
    final headers = await _getAuthHeaders();
    if (headers.isEmpty) { setState(() => _isSaving = false); return; }

    final Map<String, String> body = {
      'ticket_id': widget.ticket.id.toString(),
      'status': _selectedStatus,
      'priority': _selectedPriority,
      'category_name': _selectedCategory,
      'owner_name': _assignedTo,
      'time_worked': finalTimeWorked,
      'due_date': _dueDate != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_dueDate!) : '',
    };
    try {
      final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 15));
      if (mounted) {
        if (response.statusCode == 401) { _logout(message: 'Sesi tidak valid.'); return; }
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perubahan berhasil disimpan!'), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        } else {
          throw Exception(responseData['message'] ?? 'Gagal menyimpan perubahan.');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submitReply() async {
    if (_replyMessageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesan balasan tidak boleh kosong.'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isSubmittingReply = true);
    final url = Uri.parse('http://127.0.0.1:8080/anri_helpdesk_api/add_reply.php');
    final headers = await _getAuthHeaders();
    if (headers.isEmpty) { setState(() => _isSubmittingReply = false); return; }

    try {
      final response = await http.post(url, headers: headers, body: {
        'ticket_id': widget.ticket.id.toString(),
        'message': _replyMessageController.text,
        'new_status': _submitAsAction,
        'staff_id': '1',
        'staff_name': widget.currentUserName,
      }).timeout(const Duration(seconds: 20));
      if (mounted) {
        if (response.statusCode == 401) { _logout(message: 'Sesi tidak valid.'); return; }
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Balasan berhasil dikirim!'), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        } else {
          throw Exception(responseData['message'] ?? 'Gagal mengirim balasan.');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Time Worked', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTimeInput(controller: hoursController, label: 'Hours'),
            const SizedBox(height: 8),
            _buildTimeInput(controller: minutesController, label: 'Minutes'),
            const SizedBox(height: 8),
            _buildTimeInput(controller: secondsController, label: 'Seconds'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    child: const Text('Save'),
                    onPressed: () {
                      final h = int.tryParse(hoursController.text) ?? 0;
                      final m = int.tryParse(minutesController.text) ?? 0;
                      final s = int.tryParse(secondsController.text) ?? 0;
                      setState(() => _workedDuration = Duration(hours: h, minutes: m, seconds: s));
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
  
  Widget _buildTimeInput({required TextEditingController controller, required String label}) {
    return TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2)
        ],
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()));
  }

  Future<void> _showDueDateEditor() async {
    final pickedDate = await showDatePicker(
        context: context,
        initialDate: _dueDate ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030));
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dueDate ?? DateTime.now()));
    if (pickedTime != null) {
      setState(() => _dueDate = DateTime(pickedDate.year, pickedDate.month,
          pickedDate.day, pickedTime.hour, pickedTime.minute));
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
      case 'New': return const Color(0xFFD32F2F);
      case 'Waiting Reply': return const Color(0xFFE65100);
      case 'Replied': return const Color(0xFF1976D2);
      case 'In Progress': return const Color(0xFF673AB7);
      case 'On Hold': return const Color(0xFFC2185B);
      case 'Resolved': return const Color(0xFF388E3C);
      default: return Colors.grey.shade700;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical': return const Color(0xFFD32F2F);
      case 'High': return const Color(0xFFEF6C00);
      case 'Medium': return const Color(0xFF689F38);
      case 'Low': return const Color(0xFF0288D1);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket #${widget.ticket.trackid}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _isLoadingDetails ? null : _fetchTicketDetails,
          ),
          if (!_isResolved)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save Details',
              onPressed: _isSaving ? null : _saveChanges,
            ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTicketHeader(),
            const SizedBox(height: 16),
            _buildTicketDetailsCard(),
            const SizedBox(height: 16),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildCollapsibleDescription(),
                  if (_replies.isNotEmpty || !_isLoadingDetails)
                    const Divider(height: 1, thickness: 1),
                  _buildCollapsibleReplies(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_isResolved) ...[
              _buildTimeWorkedBar(),
              const SizedBox(height: 16),
              _buildActionShortcuts(),
              const SizedBox(height: 16),
              Container(
                key: _replyFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _replyMessageController,
                      decoration: const InputDecoration(
                          hintText: 'Type your message...',
                          border: OutlineInputBorder()),
                      maxLines: 8,
                      minLines: 5,
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
                                .map((v) => DropdownMenuItem<String>(
                                    value: v,
                                    child: Text(v,
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              if (v != null) _submitAsAction = v;
                            }),
                            decoration: const InputDecoration(
                                labelText: 'Submit as',
                                border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSubmittingReply ? null : _submitReply,
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(110, 58)),
                          child: _isSubmittingReply
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 3))
                              : const Text('Submit'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 32, thickness: 1),
              ExpansionTile(
                title: const Text('Change Ticket Details',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: false,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 8.0),
                    child: Column(
                      children: [
                        _buildStatusEditorRow(),
                        const SizedBox(height: 8),
                        _buildDropdownRow(
                            label: 'Category:',
                            value: _selectedCategory,
                            items: widget.allCategories,
                            onChanged: (v) => setState(() {
                                  if (v != null) _selectedCategory = v;
                                })),
                        _buildDropdownRow(
                            label: 'Priority:',
                            value: _selectedPriority,
                            items: _priorityOptions,
                            onChanged: (v) => setState(() {
                                  if (v != null) _selectedPriority = v;
                                }),
                            prefixIcon: Icon(Icons.flag,
                                color: _getPriorityColor(_selectedPriority),
                                size: 20)),
                        _buildDropdownRow(
                            label: 'Assigned to:',
                            value: _assignedTo,
                            items: widget.allTeamMembers,
                            onChanged: (v) => setState(() {
                                  if (v != null) _assignedTo = v;
                                })),
                      ],
                    ),
                  )
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200)),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Text('This ticket has been resolved.',
                        style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTicketHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status: $_selectedStatus',
          style: TextStyle(
              color: _getStatusColor(_selectedStatus),
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Contact: ${widget.ticket.requesterName}',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          'ID: #${widget.ticket.trackid}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }
  
  Widget _buildActionShortcuts() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: [
        if (_selectedStatus != 'Resolved')
          ActionChip(
            avatar: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Mark as Resolved'),
            onPressed: _markAsResolved,
            backgroundColor: Colors.green.shade50,
          ),
        if (_assignedTo != widget.currentUserName)
          ActionChip(
            avatar: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: const Text('Tugaskan ke Saya'),
            onPressed: _assignToMe,
            backgroundColor: Colors.orange.shade50,
          ),
      ],
    );
  }

  Widget _buildTicketDetailsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: const Text('Ticket Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        initiallyExpanded: true,
        children: [
          _buildDetailRow('Tracking ID:', widget.ticket.trackid),
          _buildDetailRow('Ticket number:', widget.ticket.id.toString()),
          _buildDetailRow('Created on:', DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.ticket.creationDate)),
          _buildDetailRow('Updated:', DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.ticket.lastChange)),
          _buildDetailRow('Replies:', widget.ticket.replies.toString()),
          _buildDetailRow('Last replier:', widget.ticket.lastReplierText),
          _buildEditableInfoRow(
            label: 'Time worked:',
            value: _formatDuration(_workedDuration),
            onTap: _showTimeWorkedEditor,
          ),
          _buildEditableInfoRow(
            label: 'Due date:',
            value: _dueDate != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_dueDate!) : 'None',
            onTap: _showDueDateEditor,
            onClear: _dueDate != null ? () => setState(() => _dueDate = null) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEditableInfoRow({required String label, required String value, VoidCallback? onTap, VoidCallback? onClear}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: InkWell(
        onTap: _isResolved ? null : onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade700)),
              Row(
                children: [
                  if(onClear != null && !_isResolved)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                      onPressed: onClear,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: onTap != null && !_isResolved ? Theme.of(context).primaryColor : null,
                      decoration: onTap != null && !_isResolved ? TextDecoration.underline : null,
                      decorationStyle: TextDecorationStyle.dotted,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCollapsibleDescription() {
    return ExpansionTile(
      title: Row(
        children: [
          Icon(Icons.description_outlined, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          const Text('Deskripsi Permasalahan', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      initiallyExpanded: true,
      children: [
        Align(
            alignment: Alignment.centerLeft,
            child: Html(
              data: widget.ticket.message,
              style: {"body": Style(fontSize: FontSize(15.0), lineHeight: LineHeight.em(1.4))},
            )),
      ],
    );
  }

  Widget _buildCollapsibleReplies() {
    return ExpansionTile(
      title: Row(
        children: [
          Icon(Icons.history_edu_outlined, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Text('Riwayat Balasan (${_replies.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        if (_isLoadingDetails)
          const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())
        else if (_replies.isEmpty)
          const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text('Belum ada balasan.', style: TextStyle(fontStyle: FontStyle.italic)))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _replies.length,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final reply = _replies[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reply by ${reply.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(DateFormat('d MMM yy, HH:mm').format(reply.date), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Html(
                    data: reply.message,
                    style: {"body": Style(fontSize: FontSize(15.0), lineHeight: LineHeight.em(1.4))},
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildTimeWorkedBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
      child: Row(
        children: [
          const Text('Time worked:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(_formatDuration(_workedDuration), style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
          const Spacer(),
          IconButton(icon: Icon(_isStopwatchRunning ? Icons.pause_circle_outline : Icons.play_circle_outline), onPressed: _isResolved ? null : _toggleStopwatch, tooltip: _isStopwatchRunning ? 'Stop Timer' : 'Start Timer', color: Theme.of(context).primaryColor),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _isResolved ? null : _showTimeWorkedEditor, tooltip: 'Edit Time Worked'),
        ],
      ),
    );
  }

  Widget _buildStatusEditorRow() {
    return Row(
      children: [
        const SizedBox(width: 110, child: Text('Ticket status:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedStatus,
              isExpanded: true,
              items: _statusOptions.map((String item) => DropdownMenuItem<String>(value: item, child: Text(item, style: TextStyle(color: _getStatusColor(item), fontWeight: FontWeight.bold)))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedStatus = v;
                    _isResolved = v == 'Resolved';
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownRow({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged, Widget? prefixIcon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
          if (prefixIcon != null) ...[
            prefixIcon,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: items.map((String item) => DropdownMenuItem<String>(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: _isResolved ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}