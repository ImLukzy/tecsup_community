import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart'; // RUTA CORREGIDA: Busca el archivo en la misma carpeta

class ChatsTab extends StatelessWidget {
  final SupabaseClient supabase;
  const ChatsTab({Key? key, required this.supabase}) : super(key: key);

  // Función para traer el nombre del usuario desde la tabla perfiles
  Future<String> _obtenerNombrePerfil(String userId) async {
    try {
      final data = await supabase
          .from('perfiles')
          .select('nombre_completo')
          .eq('id', userId)
          .maybeSingle();
      return data?['nombre_completo'] ?? "Usuario Alumno";
    } catch (e) {
      return "Usuario Alumno";
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = supabase.auth.currentUser?.id;
    if (myUid == null) {
      return const Center(
        child: Text("Inicia sesión para ver tus chats", style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      color: const Color(0xFF181A20),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('chats')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF3F69FF)));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text("No tienes chats activos.", style: TextStyle(color: Colors.grey)),
            );
          }

          // Filtramos en caliente que pertenezcas a la conversación (como comprador o vendedor)
          final misChats = snapshot.data!.where((chat) {
            return chat['comprador_id'] == myUid || chat['vendedor_id'] == myUid;
          }).toList();

          if (misChats.isEmpty) {
            return const Center(
              child: Text("No tienes chats activos.", style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: misChats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final chat = misChats[index];
              final esVendedor = chat['vendedor_id'] == myUid;
              final contraparteId = esVendedor ? chat['comprador_id'] : chat['vendedor_id'];

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF21242D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FutureBuilder<String>(
                  future: _obtenerNombrePerfil(contraparteId),
                  builder: (context, nameSnapshot) {
                    final nombreMostrado = nameSnapshot.data ?? "Cargando...";

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF3F69FF).withOpacity(0.15),
                        child: Icon(
                          esVendedor ? Icons.sell_rounded : Icons.shopping_bag_rounded,
                          color: const Color(0xFF3F69FF),
                        ),
                      ),
                      title: Text(
                        nombreMostrado,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        chat['estado'] == 'concretado' 
                            ? '📍 Ubicación activa para encuentro' 
                            : 'Trato en negociación',
                        style: TextStyle(
                          color: chat['estado'] == 'concretado' ? Colors.greenAccent : Colors.grey, 
                          fontSize: 13,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              chatId: chat['id'],
                              productoTitulo: "Negociación",
                            ),
                          ),
                        );
                      },
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