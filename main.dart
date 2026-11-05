import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Серверіңізді орналастырған соң, осы мекенжайды ауыстырыңыз
const String kServerUrl = 'https://YOUR-SERVER-URL/chat';

void main() => runApp(const SmideApp());

class SmideApp extends StatelessWidget {
  const SmideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smide AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C4DFF),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C4DFF),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class Msg {
  final String role; // 'user' немесе 'assistant'
  final String text;
  Msg(this.role, this.text);
}

const modes = {
  'chat': 'Сөйлесу',
  'write': 'Мәтін жазу',
  'translate': 'Аудару',
  'summarize': 'Қысқарту',
  'fix': 'Түзету',
};

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<Msg> _messages = [];
  String _mode = 'chat';
  bool _loading = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _messages.add(Msg('user', text));
      _loading = true;
      _controller.clear();
    });
    _scrollDown();

    try {
      final res = await http
          .post(
            Uri.parse(kServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mode': _mode,
              'messages': _messages
                  .map((m) => {'role': m.role, 'content': m.text})
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 60));
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final reply = res.statusCode == 200
          ? data['reply'] as String
          : 'Қате: ${data['error'] ?? res.statusCode}';
      setState(() => _messages.add(Msg('assistant', reply)));
    } catch (e) {
      setState(() =>
          _messages.add(Msg('assistant', 'Байланыс қатесі. Интернетті тексеріңіз.')));
    } finally {
      setState(() => _loading = false);
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smide AI', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Жаңа чат',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => setState(_messages.clear),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: modes.entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(e.value),
                            selected: _mode == e.key,
                            onSelected: (_) => setState(() => _mode = e.key),
                          ),
                        ))
                    .toList(),
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Сәлем! Мен Smide AI.\nМәтін жазуға, аударуға, қысқартуға көмектесемін.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final mine = m.role == 'user';
                        return Align(
                          alignment:
                              mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.82),
                            decoration: BoxDecoration(
                              color: mine ? cs.primary : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SelectableText(
                              m.text,
                              style: TextStyle(
                                  color: mine ? cs.onPrimary : cs.onSurface),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Хабарлама жазыңыз...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _loading ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
