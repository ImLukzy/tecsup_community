import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tecsup_community/src/views/marketplace/chat_screen.dart';
import 'package:tecsup_community/src/views/marketplace/widgets/product_card.dart';
import 'package:tecsup_community/src/views/marketplace/widgets/product_detail_modal.dart';

class ExplorarTab extends StatefulWidget {
  final SupabaseClient supabase;
  const ExplorarTab({Key? key, required this.supabase}) : super(key: key);

  @override
  State<ExplorarTab> createState() => _ExplorarTabState();
}

class _ExplorarTabState extends State<ExplorarTab> {
  final _busquedaController = TextEditingController();
  String _filtroBusqueda = "";
  final Set<dynamic> _favoritosLocales = {};

  @override
  void initState() {
    super.initState();
    _cargarFavoritos();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarFavoritos() async {
    final miUid = widget.supabase.auth.currentUser?.id;
    if (miUid == null) return;
    try {
      final res = await widget.supabase.from('favoritos').select('producto_id').eq('usuario_id', miUid);
      setState(() {
        _favoritosLocales.clear();
        for (var item in res) {
          _favoritosLocales.add(item['producto_id']);
        }
      });
    } catch (e) {
      print("Error cargando favoritos: $e");
    }
  }

  Future<void> _manejarLike(dynamic productoId, StateSetter? modalState) async {
    final miUid = widget.supabase.auth.currentUser?.id;
    if (miUid == null) return;

    final cambiarEstado = () {
      if (_favoritosLocales.contains(productoId)) {
        _favoritosLocales.remove(productoId);
      } else {
        _favoritosLocales.add(productoId);
      }
    };

    setState(cambiarEstado);
    if (modalState != null) modalState(cambiarEstado);

    try {
      final existente = await widget.supabase.from('favoritos').select().eq('usuario_id', miUid).eq('producto_id', productoId).maybeSingle();
      if (existente == null) {
        await widget.supabase.from('favoritos').insert({'usuario_id': miUid, 'producto_id': productoId});
      } else {
        await widget.supabase.from('favoritos').delete().eq('usuario_id', miUid).eq('producto_id', productoId);
      }
    } catch (e) {
      print('Error interactuando con favoritos: $e');
    }
  }

  Future<void> _eliminarProducto(dynamic id) async {
    try {
      // Nos aseguramos de castear el id correctamente por si viaja como texto o int
      final productoId = id is String ? int.tryParse(id) ?? id : id;

      // Eliminamos el registro de la tabla correcta 'productos'
      await widget.supabase
          .from('productos')
          .delete()
          .eq('id', productoId);

      if (!mounted) return;
      
      // Cerramos el modal inferior de detalles
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Producto eliminado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error detallado al eliminar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ No se pudo eliminar el producto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarDetalles(Map<String, dynamic> prod) {
    final miUid = widget.supabase.auth.currentUser?.id;
    final vendedorId = prod['vendedor_id'] ?? prod['usuario_id'];
    final esMio = vendedorId == miUid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF21242D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setBottomSheetState) => ProductDetailModal(
          prod: prod,
          esMio: esMio,
          tieneLike: _favoritosLocales.contains(prod['id']),
          onLikePressed: () => _manejarLike(prod['id'], setBottomSheetState),
          onActionPressed: () {
            if (esMio) {
              _eliminarProducto(prod['id']);
            } else {
              Navigator.pop(context);
              _iniciarOAbrirChat(prod);
            }
          },
        ),
      ),
    );
  }

  Future<void> _iniciarOAbrirChat(Map<String, dynamic> prod) async {
    final miUid = widget.supabase.auth.currentUser?.id;
    final vendedorId = prod['vendedor_id'] ?? prod['usuario_id'];
    if (miUid == null || vendedorId == null) return;

    try {
      final habitacionExistente = await widget.supabase
          .from('chats')
          .select()
          .eq('producto_id', prod['id'])
          .eq('comprador_id', miUid)
          .maybeSingle();

      Map<String, dynamic> chatReal;

      if (habitacionExistente != null) {
        chatReal = habitacionExistente;
      } else {
        chatReal = await widget.supabase.from('chats').insert({
          'producto_id': prod['id'],
          'comprador_id': miUid,
          'vendedor_id': vendedorId,
        }).select().single();
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatReal['id'],
            productoTitulo: prod['titulo'] ?? 'Producto',
          ),
        ),
      );
    } catch (e) {
      print("Error al abrir chat: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    int columnas = size.width > 1200 ? 4 : (size.width > 750 ? 3 : 2);

    return Container(
      color: const Color(0xFF181A20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF21242D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _busquedaController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Buscar en Marketplace...",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (val) => setState(() => _filtroBusqueda = val.toLowerCase()),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.supabase.from('productos').stream(primaryKey: ['id']).order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF3F69FF)));
                }
                
                var productos = snapshot.data ?? [];

                if (_filtroBusqueda.isNotEmpty) {
                  productos = productos.where((p) => (p['titulo'] ?? '').toString().toLowerCase().contains(_filtroBusqueda)).toList();
                }

                if (productos.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron artículos.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnas,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.74,
                  ),
                  itemCount: productos.length,
                  itemBuilder: (context, index) {
                    final prod = productos[index];
                    return ProductCard(
                      prod: prod,
                      onTap: () => _mostrarDetalles(prod),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}