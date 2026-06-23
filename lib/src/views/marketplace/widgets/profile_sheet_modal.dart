import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class ProfileSheetModal extends StatelessWidget {
  final SupabaseClient supabase;


  const ProfileSheetModal({Key? key, required this.supabase}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final email = user?.email ?? 'anonimo@tecsup.edu.pe';
    final uid = user?.id;


    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF21242D), // Color de tus tarjetas
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF3F69FF).withOpacity(0.15),
                  child: const Icon(Icons.school, color: Color(0xFF3F69FF), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Estudiante Tecsup", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.white.withOpacity(0.08), thickness: 1),
            const SizedBox(height: 10),
            const Text("Mis publicaciones en venta", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),


            Expanded(
              child: uid == null
                  ? const Center(child: Text("Inicia sesión para ver tus artículos.", style: TextStyle(color: Colors.grey)))
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: supabase.from('marketplace').stream(primaryKey: ['id']).eq('usuario_id', uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF3F69FF)));
                        }
                        final misProductos = snapshot.data ?? [];


                        if (misProductos.isEmpty) {
                          return const Center(
                            child: Text("Aún no tienes artículos en venta.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                          );
                        }


                        return ListView.builder(
                          controller: scrollController,
                          itemCount: misProductos.length,
                          itemBuilder: (context, index) {
                            final item = misProductos[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF181A20), // Fondo interior oscuro
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(item['image_url'] ?? '', width: 48, height: 48, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                ),
                                title: Text(item['titulo'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                                subtitle: Text("S/. ${item['precio']}", style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () async {
                                    await supabase.from('marketplace').delete().eq('id', item['id']);
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
