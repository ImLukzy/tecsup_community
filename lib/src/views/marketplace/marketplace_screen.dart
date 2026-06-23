import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'explorar_tab.dart';
import 'guardados_tab.dart'; // Regresa la pestaña original de guardados
import 'perfil_screen.dart';
import 'widgets/upload_product_modal.dart';
import '../../../screens/profile_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  final SupabaseClient supabase;

  const MarketplaceScreen({Key? key, required this.supabase}) : super(key: key);

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cerrarSesion() async {
    try {
      await widget.supabase.auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      print("Error al cerrar sesión: $e");
    }
  }

  void _mostrarModalSubirProducto() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UploadProductModal(
        onUpload: (nuevoProducto) {
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF21242D),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 24,
              child: Image.asset(
                'assets/logo.png', 
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.storefront_rounded, color: Color(0xFF3F69FF), size: 24);
                },
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Marketplace',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.white, size: 26),
            offset: const Offset(0, 45),
            color: const Color(0xFF2D2F36),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'perfil') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(supabase: widget.supabase),
                  ),
                );
              } else if (value == 'logout') {
                _cerrarSesion();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'perfil',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text('Ver perfil', style: TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text('Cerrar sesión', style: TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF3F69FF),
          labelColor: const Color(0xFF3F69FF),
          unselectedLabelColor: Colors.grey,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Explorar'),
            Tab(text: 'Guardados'), // Fiel al diseño original
            Tab(text: 'Mis Productos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ExplorarTab(supabase: widget.supabase),
          GuardadosTab(supabase: widget.supabase), // Tu lista original de favoritos
          PerfilScreen(supabase: widget.supabase),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3F69FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _mostrarModalSubirProducto,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}