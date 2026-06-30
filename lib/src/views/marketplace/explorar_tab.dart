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
  bool _cargando = false;
  List<Map<String, dynamic>> _productos = [];

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _inicializarDatos() async {
    setState(() => _cargando = true);
    await _cargarFavoritos();
    await _cargarProductosDesdeBD();
    setState(() => _cargando = false);
  }

  Future<void> _cargarProductosDesdeBD() async {
    try {
      // 🟩 UNIFICADO: Tabla 'marketplace'
      final data = await widget.supabase
          .from('marketplace')
          .select()
          .order('created_at', ascending: false);
      
      _productos = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("Error cargando productos en catálogo: $e");
    }
  }

  Future<void> _cargarFavoritos() async {
    final miUid = widget.supabase.auth.currentUser?.id;
    if (miUid == null) return;
    try {
      final res = await widget.supabase
          .from('favoritos')
          .select('producto_id')
          .eq('usuario_id', miUid);
          
      _favoritosLocales.clear();
      for (var item in res) {
        _favoritosLocales.add(item['producto_id']);
      }
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
      final existente = await widget.supabase
          .from('favoritos')
          .select()
          .eq('usuario_id', miUid)
          .eq('producto_id', productoId)
          .maybeSingle();
          
      if (existente == null) {
        await widget.supabase.from('favoritos').insert({
          'usuario_id': miUid, 
          'producto_id': productoId
        });
      } else {
        await widget.supabase
            .from('favoritos')
            .delete()
            .eq('usuario_id', miUid)
            .eq('producto_id', productoId);
      }
    } catch (e) {
      print('Error interactuando con favoritos: $e');
    }
  }

  Future<void> _eliminarProducto(dynamic id) async {
    try {
      final productoId = id is String ? int.tryParse(id) ?? id : id;

      // 🟩 UNIFICADO: Borrado de la tabla 'marketplace'
      await widget.supabase
          .from('marketplace')
          .delete()
          .eq('id', productoId);

      await _cargarProductosDesdeBD();

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Producto eliminado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
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
    final vendedorId = prod['usuario_id'];
    final esMio = vendedorId == miUid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF21242D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
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
    final vendedorId = prod['usuario_id'];
    if (miUid == null || vendedorId == null) return;

    try {
      final dynamic productoIdCorrecto = prod['id'] is String 
          ? int.tryParse(prod['id']) ?? prod['id'] 
          : prod['id'];

      final habitacionExistente = await widget.supabase
          .from('chats')
          .select()
          .eq('producto_id', productoIdCorrecto)
          .eq('comprador_id', miUid)
          .maybeSingle();

      Map<String, dynamic> chatReal;

      if (habitacionExistente != null) {
        chatReal = habitacionExistente;
      } else {
        chatReal = await widget.supabase.from('chats').insert({
          'producto_id': productoIdCorrecto,
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
      print("Error detallado al abrir/crear chat: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al conectar con el vendedor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    int columnas = size.width > 1200 ? 4 : (size.width > 750 ? 3 : 2);

    List<Map<String, dynamic>> productosFiltrados = _productos;
    if (_filtroBusqueda.isNotEmpty) {
      productosFiltrados = productosFiltrados
          .where((p) => (p['titulo'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_filtroBusqueda))
          .toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      body: RefreshIndicator(
        color: const Color(0xFF3F69FF),
        onRefresh: _cargarProductosDesdeBD,
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
              child: _cargando
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF3F69FF)))
                  : productosFiltrados.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(
                              child: Text(
                                'No se encontraron artículos.', 
                                style: TextStyle(color: Colors.grey)
                              ),
                            ),
                          ],
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(14),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columnas,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.74,
                          ),
                          itemCount: productosFiltrados.length,
                          itemBuilder: (context, index) {
                            final prod = productosFiltrados[index];
                            return ProductCard(
                              prod: prod,
                              onTap: () => _mostrarDetalles(prod),
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