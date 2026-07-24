import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../providers/app_provider.dart';
import '../services/openai_service.dart';

class ChatbotScreen extends StatefulWidget {
  /// null  → general Jordan building chatbot (from drawer)
  /// value → context-aware chatbot tied to a specific building (from RenderScreen)
  final String? buildingContext;

  const ChatbotScreen({super.key, this.buildingContext});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _textCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ChatMessage>          _messages = [];
  List<Map<String, dynamic>> _sessions = [];
  bool _sending = false;

  String get _storageKey =>
      widget.buildingContext != null ? 'chatbot_context' : 'chatbot_general';
  String get _sessionsKey =>
      widget.buildingContext != null ? 'chatbot_sessions_context' : 'chatbot_sessions_general';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadSessions();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        if (mounted) setState(() => _messages = ChatMessage.decodeList(raw));
        _scrollToBottom();
      } catch (_) {}
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, ChatMessage.encodeList(_messages));
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_sessionsKey);
    if (raw != null && mounted) {
      final list = jsonDecode(raw) as List<dynamic>;
      setState(() => _sessions = List<Map<String, dynamic>>.from(list));
    }
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionsKey, jsonEncode(_sessions));
  }

  void _newChat() {
    if (_messages.isEmpty) return;
    final session = {
      'ts': DateTime.now().millisecondsSinceEpoch,
      'messages': _messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
    };
    setState(() {
      _sessions.insert(0, session);
      if (_sessions.length > 10) _sessions = _sessions.sublist(0, 10);
      _messages = [];
    });
    _saveSessions();
    SharedPreferences.getInstance().then((p) => p.remove(_storageKey));
  }

  void _showHistory(bool isAr, bool isDark) {
    if (_sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isAr ? 'لا توجد محادثات سابقة' : 'No previous chats'),
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A2E1A) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setInner) => DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, sc) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(children: [
                  const Icon(Icons.history, color: Color(0xFF1A73E8), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isAr ? 'المحادثات السابقة' : 'Previous Chats',
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF2F4F4F),
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  itemCount: _sessions.length,
                  itemBuilder: (_, i) {
                    final s  = _sessions[i];
                    final ts = DateTime.fromMillisecondsSinceEpoch(s['ts'] as int);
                    final label =
                        '${ts.day}/${ts.month}/${ts.year}  ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}';
                    final msgs    = s['messages'] as List<dynamic>;
                    final preview = msgs.isNotEmpty ? msgs[0]['content'] as String : '';
                    return ListTile(
                      leading: const Icon(Icons.chat_bubble_outline,
                          color: Color(0xFF1A73E8), size: 20),
                      title: Text(label,
                          style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF2F4F4F),
                              fontSize: 13)),
                      subtitle: Text(preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _messages = msgs.map((m) => ChatMessage(
                                role: m['role'] as String,
                                content: m['content'] as String,
                              )).toList();
                        });
                        _scrollToBottom();
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 18),
                        onPressed: () {
                          setState(() => _sessions.removeAt(i));
                          setInner(() {});
                          _saveSessions();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    setState(() => _messages.clear());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _textCtrl.text).trim();
    if (text.isEmpty || _sending) return;

    final isAr = context.read<AppProvider>().locale.languageCode == 'ar';
    _textCtrl.clear();

    final historySnapshot = List<ChatMessage>.from(_messages);
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final reply = await OpenAIService.send(
        history: historySnapshot,
        userMessage: text,
        lang: isAr ? 'ar' : 'en',
        buildingContext: widget.buildingContext,
      );
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: reply));
        _sending = false;
      });
    } catch (_) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: isAr
              ? 'عذراً، حدث خطأ. تحقق من الإنترنت وحاول مجدداً.'
              : 'Sorry, an error occurred. Check your internet and try again.',
        ));
        _sending = false;
      });
    }
    await _saveHistory();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<AppProvider>();
    final isDark    = provider.isDarkMode;
    final isAr      = provider.locale.languageCode == 'ar';
    final isContext = widget.buildingContext != null;

    const bgDark      = Color(0xFF1A2E1A);
    const bgLight     = Color(0xFFFFFAFA);
    const cardDark    = Color(0xFF243D24);
    const cardLight   = Color(0xFFDCDCDC);
    const headerDark  = Color(0xFF101E10);
    const headerLight = Color(0xFF2F4F4F);

    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      appBar: AppBar(
        backgroundColor: isDark ? headerDark : headerLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.psychology_rounded, color: Color(0xFF1A73E8), size: 20),
            const SizedBox(width: 8),
            Text(
              isContext
                  ? (isAr ? 'مساعد البناء' : 'Building Assistant')
                  : (isAr ? 'المساعد الذكي' : 'AI Assistant'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white70),
            tooltip: isAr ? 'المحادثات السابقة' : 'Chat history',
            onPressed: () => _showHistory(isAr, isDark),
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white70),
            tooltip: isAr ? 'محادثة جديدة' : 'New chat',
            onPressed: _messages.isNotEmpty ? _newChat : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Building context banner ────────────────────────────────────────
          if (isContext)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1A73E8).withOpacity(0.10),
              child: Row(
                children: [
                  const Icon(Icons.domain_rounded, color: Color(0xFF1A73E8), size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'مساعدة خاصة بـ: ${widget.buildingContext}'
                          : 'Context: ${widget.buildingContext}',
                      style: const TextStyle(
                          color: Color(0xFF1A73E8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // ── Messages or empty state ────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(
                    isDark: isDark,
                    isAr: isAr,
                    onSuggestion: _send,
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (_sending && i == _messages.length) {
                        return _TypingIndicator(isDark: isDark);
                      }
                      return _Bubble(
                        msg: _messages[i],
                        isDark: isDark,
                        cardDark: cardDark,
                        cardLight: cardLight,
                      );
                    },
                  ),
          ),

          // ── Input bar ──────────────────────────────────────────────────────
          _InputBar(
            ctrl: _textCtrl,
            isDark: isDark,
            isAr: isAr,
            sending: _sending,
            cardDark: cardDark,
            cardLight: cardLight,
            onSend: () => _send(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Empty state with suggested questions
// ═══════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final bool isDark;
  final bool isAr;
  final void Function(String) onSuggestion;

  const _EmptyState({
    required this.isDark,
    required this.isAr,
    required this.onSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = isAr
        ? [
            'ما هي أسعار الأسمنت في الأردن؟',
            'أين أشتري البلاط بسعر رخيص في عمّان؟',
            'كم تكلفة بناء بيت في الأردن؟',
            'ما هي التراخيص المطلوبة للبناء في الأردن؟',
          ]
        : [
            'What are cement prices in Jordan?',
            'Where to buy cheap tiles in Amman?',
            'How much does it cost to build a house in Jordan?',
            'What building permits are required in Jordan?',
          ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Color(0xFF1A73E8), size: 44),
          ),
          const SizedBox(height: 16),
          Text(
            isAr ? 'مساعد البناء في الأردن' : 'Jordan Building Assistant',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF2F4F4F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'اسألني عن أسعار مواد البناء، أفضل الأسواق، التكاليف، والمزيد في الأردن'
                : 'Ask me about material prices, best markets, costs, and more in Jordan',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF696969), height: 1.4),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              isAr ? 'أسئلة مقترحة:' : 'Suggested questions:',
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1A73E8),
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          ...suggestions.map((q) => GestureDetector(
                onTap: () => onSuggestion(q),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF243D24)
                        : const Color(0xFFDCDCDC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            const Color(0xFF1A73E8).withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 12, color: Color(0xFF1A73E8)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          q,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF2F4F4F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Message bubble
// ═══════════════════════════════════════════════════════════════════════════════
class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isDark;
  final Color cardDark;
  final Color cardLight;

  const _Bubble({
    required this.msg,
    required this.isDark,
    required this.cardDark,
    required this.cardLight,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFF1A73E8),
              child: Icon(Icons.psychology_rounded,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF1A73E8)
                    : (isDark ? cardDark : cardLight),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFF696969).withOpacity(0.2)),
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : (isDark
                          ? const Color(0xFFDCDCDC)
                          : const Color(0xFF2F4F4F)),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Animated typing indicator
// ═══════════════════════════════════════════════════════════════════════════════
class _TypingIndicator extends StatefulWidget {
  final bool isDark;
  const _TypingIndicator({required this.isDark});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 15,
            backgroundColor: Color(0xFF1A73E8),
            child: Icon(Icons.psychology_rounded,
                size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF243D24)
                  : const Color(0xFFDCDCDC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final delay = i / 3;
                  final t = ((_ctrl.value - delay + 1) % 1.0);
                  final opacity = t < 0.5 ? t * 2 : (1 - t) * 2;
                  return Container(
                    width: 7,
                    height: 7,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A73E8)
                          .withOpacity(0.3 + opacity * 0.7),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Input bar
// ═══════════════════════════════════════════════════════════════════════════════
class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isDark;
  final bool isAr;
  final bool sending;
  final Color cardDark;
  final Color cardLight;
  final VoidCallback onSend;

  const _InputBar({
    required this.ctrl,
    required this.isDark,
    required this.isAr,
    required this.sending,
    required this.cardDark,
    required this.cardLight,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? cardDark : cardLight,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white12
                : const Color(0xFF696969).withOpacity(0.2),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                style: TextStyle(
                    color:
                        isDark ? Colors.white : const Color(0xFF2F4F4F),
                    fontSize: 14),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: isAr
                      ? 'اسأل عن البناء في الأردن...'
                      : 'Ask about building in Jordan...',
                  hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white38
                          : const Color(0xFF696969),
                      fontSize: 13),
                  filled: true,
                  fillColor:
                      isDark ? const Color(0xFF1A2E1A) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: sending ? null : onSend,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: sending
                      ? const Color(0xFF696969)
                      : const Color(0xFF1A73E8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  sending
                      ? Icons.hourglass_top_rounded
                      : Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
