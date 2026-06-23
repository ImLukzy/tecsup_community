import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapaScreen extends StatefulWidget {
  final SupabaseClient supabase;
  const MapaScreen({Key? key, required this.supabase}) : super(key: key);

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  // Coordenadas del centro del Campus Tecsup por defecto
  final LatLng _centroTecsup = const LatLng(-16.4262, -71.5185);

  @override
  Widget build(BuildContext context) {
    final myUid = widget.supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // Escucha en tiempo real CUALQUIER cambio de coordenadas en los chats
        stream: widget.supabase.from('chats').stream(primaryKey: ['id']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF3F69FF)));
          }

          // Filtramos chats donde el alumno actual participe y se esté compartiendo geolocalización
          final chatsActivos = snapshot.data?.where((chat) {
            final participa = chat['comprador_id'] == myUid || chat['vendedor_id'] == myUid;
            final compartiendo = (chat['comprador_compartiendo'] == true) || (chat['vendedor_compartiendo'] == true);
            return participa && compartiendo;
          }).toList() ?? [];

          List<Marker> marcadores = [];

          for (var chat in chatsActivos) {
            // Pin del Comprador
            if (chat['comprador_compartiendo'] == true && chat['comprador_lat'] != null) {
              marcadores.add(
                Marker(
                  width: 50,
                  height: 50,
                  point: LatLng((chat['comprador_lat'] as num).toDouble(), (chat['comprador_lng'] as num).toDouble()),
                  child: const Icon(Icons.person_pin_circle_rounded, color: Colors.blueAccent, size: 42),
                ),
              );
            }
            // Pin del Vendedor
            if (chat['vendedor_compartiendo'] == true && chat['vendedor_lat'] != null) {
              marcadores.add(
                Marker(
                  width: 50,
                  height: 50,
                  point: LatLng((chat['vendedor_lat'] as num).toDouble(), (chat['vendedor_lng'] as num).toDouble()),
                  child: const Icon(Icons.store_mall_directory_rounded, color: Colors.greenAccent, size: 42),
                ),
              );
            }
          }

          return FlutterMap(
            options: MapOptions(
              initialCenter: marcadores.isNotEmpty ? marcadores.first.point : _centroTecsup,
              initialZoom: 17.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                // Filtro oscuro para que el mapa combine con tu tema negro premium
                tileBuilder: (context, tileWidget, tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      0,       0,       0,       1, 0,
                    ]),
                    child: tileWidget,
                  );
                },
              ),
              if (marcadores.isNotEmpty) MarkerLayer(markers: marcadores),
              if (marcadores.isEmpty)
                Positioned(
                  top: 50,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF21242D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Los pines aparecerán aquí cuando concretes un trato y compartas tu GPS desde el Chat.",
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}