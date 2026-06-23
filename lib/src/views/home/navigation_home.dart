import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tecsup_community/src/views/marketplace/marketplace_screen.dart';
import 'package:tecsup_community/src/views/marketplace/explorar_tab.dart'; 
import 'package:tecsup_community/src/views/marketplace/guardados_tab.dart';
import 'package:tecsup_community/src/views/marketplace/chats_tab.dart'; // Nueva importación de la pestaña de chats

class NavigationHome extends StatefulWidget {
  final SupabaseClient supabase;
  const NavigationHome({Key? key, required this.supabase}) : super(key: key);

  @override
  State<NavigationHome> createState() => _NavigationHomeState();
}

class _NavigationHomeState extends State<NavigationHome> {
  int _currentIndex = 0;

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
      
      // Pestaña 3: Mapa Campus (Se mantiene intacto)
      const Center(
        child: Text(
          'Pantalla de Mapa Campus',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    ];
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
              color: Colors.white.withOpacity(0.02),
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