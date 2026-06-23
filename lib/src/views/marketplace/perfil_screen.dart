import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/upload_product_modal.dart';

class PerfilScreen extends StatefulWidget {
  final SupabaseClient supabase;

  const PerfilScreen({Key? key, required this.supabase}) : super(key: key);

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  List<Map<String, dynamic>> _misProductos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarMisProductos();
  }

  Future<void> _cargarMisProductos() async {
    final user = widget.supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await widget.supabase
          .from('productos')
          .select()
          .eq('vendedor_id', user.id)
          .order('id', ascending: false);

      if (mounted) {
        setState(() {
          _misProductos = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error al cargar productos del usuario: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _eliminarProducto(dynamic id) async {
    try {
      await widget.supabase.from('productos').delete().eq('id', id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📦 Publicación eliminada con éxito.')),
      );
      _cargarMisProductos(); 
    } catch (e) {
      print("Error al eliminar producto: $e");
    }
  }

  void _abrirModalSubirProducto() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UploadProductModal(
        // Se envuelve en una función anónima que acepta el Map que pide la firma
        onUpload: (nuevoProducto) => _cargarMisProductos(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mis publicaciones en venta',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: Color(0xFF3F69FF)),
                    ),
                  )
                : _misProductos.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No tienes productos en venta actualmente.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _misProductos.length,
                        itemBuilder: (context, index) {
                          final prod = _misProductos[index];
                          final double precio = (prod['precio'] is num) 
                              ? (prod['precio'] as num).toDouble() 
                              : 0.0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF21242D),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: (prod['image_url'] != null && (prod['image_url'] as String).isNotEmpty)
                                      ? Image.network(prod['image_url'], fit: BoxFit.cover)
                                      : Container(
                                          color: const Color(0xFF181A20), 
                                          child: const Icon(Icons.image, color: Colors.grey, size: 20),
                                        ),
                                ),
                              ),
                              title: Text(
                                prod['titulo'] ?? 'Artículo',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                              subtitle: Text(
                                'S/. ${precio.toStringAsFixed(2)}',
                                style: const TextStyle(color: Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                onPressed: () => _eliminarProducto(prod['id']),
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3F69FF),
        onPressed: _abrirModalSubirProducto,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}