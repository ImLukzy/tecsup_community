import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/product_card.dart';
import 'widgets/product_detail_modal.dart';
import 'chat_screen.dart';

class GuardadosTab extends StatefulWidget {
  final SupabaseClient supabase;
  const GuardadosTab({Key? key, required this.supabase}) : super(key: key);

  @override
  State<GuardadosTab> createState() => _GuardadosTabState();
}

class _GuardadosTabState extends State<GuardadosTab> {
  final Set<dynamic> _favoritosLocales = {};

  // Manejador del desmarcado o "Unlike" desde la pestaña de guardados
  Future<void> _quitarFavorito(dynamic productoId) async {
    final miUid = widget.supabase.auth.currentUser?.id;
    if (miUid == null) return;

    setState(() => _favoritosLocales.remove(productoId));

    try {
      await widget.supabase
          .from('favoritos')
          .delete()
          .eq('usuario_id', miUid)
          .eq('producto_id', productoId);
    } catch (e) {
      print('Error al quitar de favoritos: $e');
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
      builder: (context) => ProductDetailModal(
        prod: prod,
        esMio: esMio,
        tieneLike: true, // Si está en esta pestaña, evidentemente tiene like
        onLikePressed: () {
          Navigator.pop(context);
          _quitarFavorito(prod['id']);
        },
        onActionPressed: () {
          Navigator.pop(context);
          if (!esMio) _iniciarOAbrirChat(prod);
        },
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
    final miUid = widget.supabase.auth.currentUser?.id;
    if (miUid == null) return const Center(child: Text('Inicia sesión para ver tus guardados.', style: TextStyle(color: Colors.grey)));

    final size = MediaQuery.of(context).size;
    int columnas = size.width > 1200 ? 4 : (size.width > 750 ? 3 : 2);

    return Container(
      color: const Color(0xFF181A20),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        // Escuchamos la tabla favoritos filtrando por el alumno actual
        stream: widget.supabase
            .from('favoritos')
            .stream(primaryKey: ['id'])
            .eq('usuario_id', miUid),
        builder: (context, snapshotSnapshot) {
          if (snapshotSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF3F69FF)));
          }

          final listaFavoritos = snapshotSnapshot.data ?? [];
          if (listaFavoritos.isEmpty) {
            return const Center(child: Text('No tienes productos guardados.', style: TextStyle(color: Colors.grey)));
          }

          // Extraemos todos los IDs de productos que tienen like
          final idsFavoritos = listaFavoritos.map((fav) => fav['producto_id']).toList();

          return StreamBuilder<List<Map<String, dynamic>>>(
            // Traemos en tiempo real los productos cuyos IDs coincidan con tus favoritos
            stream: widget.supabase
                .from('marketplace')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false),
            builder: (context, productosSnapshot) {
              if (productosSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF3F69FF)));
              }

              // Filtramos localmente para renderizar solo los artículos guardados válidos
              final todosLosProductos = productosSnapshot.data ?? [];
              final productosGuardados = todosLosProductos
                  .where((p) => idsFavoritos.contains(p['id']))
                  .toList();

              if (productosGuardados.isEmpty) {
                return const Center(child: Text('No tienes productos guardados.', style: TextStyle(color: Colors.grey)));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columnas,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.74,
                ),
                itemCount: productosGuardados.length,
                itemBuilder: (context, index) {
                  final prod = productosGuardados[index];
                  return ProductCard(
                    prod: prod,
                    onTap: () => _mostrarDetalles(prod),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
