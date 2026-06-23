import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForosScreen extends StatefulWidget {
  final SupabaseClient supabase;

  const ForosScreen({Key? key, required this.supabase}) : super(key: key);

  @override
  State<ForosScreen> createState() => _ForosScreenState();
}

class _ForosScreenState extends State<ForosScreen> {
  List<Map<String, dynamic>> _publicaciones = [];
  bool _isLoading = true;
  final _postController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarPublicaciones();
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _cargarPublicaciones() async {
    try {
      final data = await widget.supabase
          .from('foros')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _publicaciones = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error al cargar publicaciones del foro: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _crearPublicacion() async {
    final texto = _postController.text.trim();
    if (texto.isEmpty) return;

    final user = widget.supabase.auth.currentUser;
    if (user == null) return;

    final nombreUsuario = user.userMetadata?['full_name'] ?? 'Estudiante Anonimo';

    try {
      await widget.supabase.from('foros').insert({
        'autor_id': user.id,
        'autor_nombre': nombreUsuario,
        'contenido': texto,
      });

      _postController.clear();
      _cargarPublicaciones(); // Recargar el feed del foro
    } catch (e) {
      print("Error al publicar en el foro: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF21242D),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Comunidad Tecsup',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Caja superior para redactar un nuevo post
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF21242D),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF181A20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _postController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: "¿Qué está pasando en el campus?",
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _crearPublicacion,
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF3F69FF)),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF181A20),
                    padding: const EdgeInsets.all(12),
                  ),
                )
              ],
            ),
          ),
          
          // Listado de publicaciones del foro
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3F69FF)))
                : _publicaciones.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay ninguna publicación todavía. ¡Sé el primero!',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarPublicaciones,
                        color: const Color(0xFF3F69FF),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _publicaciones.length,
                          itemBuilder: (context, index) {
                            final post = _publicaciones[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF21242D),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Color(0xFF3F69FF),
                                        child: Icon(Icons.person, size: 16, color: Colors.white),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        post['autor_nombre'] ?? 'Estudiante',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    post['contenido'] ?? '',
                                    style: const TextStyle(
                                      color: Color(0xFFE0E0E0),
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}