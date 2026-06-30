import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tecsup_community/src/views/marketplace/marketplace_screen.dart';
import 'package:tecsup_community/src/views/marketplace/chats_tab.dart'; // Nueva importación de la pestaña de chats
import 'package:tecsup_community/src/views/mapa/mapa_screen.dart';

class NavigationHome extends StatefulWidget {
  final SupabaseClient supabase;
  const NavigationHome({super.key, required this.supabase});

  @override
  State<NavigationHome> createState() => _NavigationHomeState();
}

class _NavigationHomeState extends State<NavigationHome> {
  int _currentIndex = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _mensajesSubscription;
  final Set<dynamic> _mensajesNotificados = {};
  bool _notificacionesInicializadas = false;

  // Lista de vistas principales de tu aplicación
  late final List<Widget> _paginas;

  @override
  void initState() {
    super.initState();
    _paginas = [
      // Pestaña 1: Marketplace (que internamente tiene Explorar, Guardados y Mis Productos)
      MarketplaceScreen(supabase: widget.supabase),
      
      // Pestaña 2: Chats Funcionales (Reemplaza al texto estático de Comunidad)
      ChatsTab(supabase: widget.supabase),
      
      // Pestaña 3: Mapa Campus
      MapaScreen(supabase: widget.supabase),
    ];
    _escucharNotificacionesDeMensajes();
  }

  @override
  void dispose() {
    _mensajesSubscription?.cancel();
    super.dispose();
  }

  void _escucharNotificacionesDeMensajes() {
    final myUid = widget.supabase.auth.currentUser?.id;
    if (myUid == null) return;

    _mensajesSubscription = widget.supabase
        .from('mensajes')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .listen((mensajes) {
      if (!mounted) return;

      if (!_notificacionesInicializadas) {
        for (final mensaje in mensajes) {
          final id = mensaje['id'];
          if (id != null) _mensajesNotificados.add(id);
        }
        _notificacionesInicializadas = true;
        return;
      }

      for (final mensaje in mensajes) {
        final id = mensaje['id'];
        if (id == null || _mensajesNotificados.contains(id)) continue;
        _mensajesNotificados.add(id);

        if (mensaje['remitente_id'] == myUid) continue;

        final texto = (mensaje['contenido'] ?? 'Nuevo mensaje').toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF21242D),
            content: Text(
              'Nuevo mensaje: $texto',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'Chats',
              textColor: const Color(0xFF3F69FF),
              onPressed: () => setState(() => _currentIndex = 1),
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      
      // Muestra la vista según el índice seleccionado en el menú inferior
      body: IndexedStack(
        index: _currentIndex,
        children: _paginas,
      ),

      // Barra de navegación inferior completamente integrada y con fondo compartido
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.02),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF181A20), 
          elevation: 0, 
          type: BottomNavigationBarType.fixed, 
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          
          selectedItemColor: const Color(0xFF3F69FF), // Azul eléctrico
          unselectedItemColor: Colors.grey[600], 
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            fontFamily: 'Roboto', 
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontFamily: 'Roboto',
          ),
          
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.shopping_bag_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.shopping_bag),
              ),
              label: 'Marketplace',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.chat_bubble_outline_rounded),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.chat_bubble_rounded),
              ),
              label: 'Chats', // Corregido el label de 'Comunidad' a 'Chats'
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.map_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.map),
              ),
              label: 'Mapa Campus',
            ),
          ],
        ),
      ),
    );
  }
}
