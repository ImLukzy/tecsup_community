import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';

class ChatsTab extends StatelessWidget {
  final SupabaseClient supabase;
  const ChatsTab({Key? key, required this.supabase}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final myUid = supabase.auth.currentUser?.id;
    if (myUid == null) return const Center(child: Text("Inicia sesión para ver tus chats", style: TextStyle(color: Colors.grey)));

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('chats')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF3F69FF)));
          }

          // Filtramos solo los chats donde participa el usuario actual (comprador o vendedor)
          final misChats = snapshot.data!.where((chat) => chat['comprador_id'] == myUid || chat['vendedor_id'] == myUid).toList();

          if (misChats.isEmpty) {
            return const Center(
              child: Text(
                "No tienes chats abiertos.\n¡Pregunta por un artículo en Explorar!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: misChats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final chat = misChats[index];
              final esVendedor = chat['vendedor_id'] == myUid;

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF21242D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF3F69FF).withOpacity(0.2),
                    child: Icon(
                      esVendedor ? Icons.sell_rounded : Icons.shopping_bag_rounded,
                      color: const Color(0xFF3F69FF),
                    ),
                  ),
                  title: const Text(
                    "Interés en Producto",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    esVendedor ? "Un alumno te escribió por tu artículo" : "Le escribiste al vendedor",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          chatId: chat['id'],
                          productoTitulo: "Ver Conversación",
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}