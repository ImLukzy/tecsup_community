import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String productoTitulo;

  const ChatScreen({Key? key, required this.chatId, required this.productoTitulo}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _enviarMensaje() async {
    final texto = _msgController.text.trim();
    if (texto.isEmpty) return;

    final myUid = _supabase.auth.currentUser?.id;
    if (myUid == null) return;

    _msgController.clear();

    try {
      await _supabase.from('mensajes').insert({
        'chat_id': widget.chatId,
        'remitente_id': myUid,
        'contenido': texto,
      });
    } catch (e) {
      print("Error enviando mensaje: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF21242D),
        elevation: 0,
        title: Text(widget.productoTitulo, style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('mensajes')
                  .stream(primaryKey: ['id'])
                  .eq('chat_id', widget.chatId)
                  .order('created_at', ascending: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF3F69FF)));
                }

                final mensajes = snapshot.data!;
                if (mensajes.isEmpty) {
                  return const Center(child: Text("¡Inicia la conversación preguntando por el producto!", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final msg = mensajes[index];
                    final esMio = msg['remitente_id'] == myUid;

                    return Align(
                      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: esMio ? const Color(0xFF3F69FF) : const Color(0xFF21242D),
                          borderRadius: BorderRadius.circular(12).copyWith(
                            bottomRight: esMio ? const Radius.circular(0) : const Radius.circular(12),
                            bottomLeft: esMio ? const Radius.circular(12) : const Radius.circular(0),
                          ),
                        ),
                        child: Text(
                          msg['contenido'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF21242D),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onSubmitted: (_) => _enviarMensaje(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF3F69FF)),
                  onPressed: _enviarMensaje,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}