import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MapaScreen extends StatefulWidget {
  final SupabaseClient supabase;

  const MapaScreen({super.key, required this.supabase});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final LatLng _centroTecsup = const LatLng(-16.4262, -71.5185);
  final MapController _mapController = MapController();

  LatLng? _miUbicacion;
  bool _cargandoGps = true;
  String? _mensajeGps;
  StreamSubscription<Position>? _gpsSubscription;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacionActual();
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _obtenerUbicacionActual() async {
    setState(() {
      _cargandoGps = true;
      _mensajeGps = null;
    });

    try {
      final servicioActivo = await Geolocator.isLocationServiceEnabled();
      if (!servicioActivo) {
        _mostrarEstadoGps('Activa el GPS del celular para ver tu ubicacion.');
        return;
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }

      if (permiso == LocationPermission.denied) {
        _mostrarEstadoGps('Permiso de ubicacion denegado.');
        return;
      }

      if (permiso == LocationPermission.deniedForever) {
        _mostrarEstadoGps('Habilita el permiso de ubicacion desde ajustes.');
        return;
      }

      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final ubicacion = LatLng(posicion.latitude, posicion.longitude);

      if (!mounted) return;
      setState(() {
        _miUbicacion = ubicacion;
        _cargandoGps = false;
      });

      _centrarMapa(ubicacion, 18);
      _escucharUbicacionEnVivo();
    } catch (_) {
      _mostrarEstadoGps('No se pudo obtener tu ubicacion GPS.');
    }
  }

  void _escucharUbicacionEnVivo() {
    _gpsSubscription?.cancel();
    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((posicion) {
      if (!mounted) return;
      final ubicacion = LatLng(posicion.latitude, posicion.longitude);
      setState(() => _miUbicacion = ubicacion);
    });
  }

  void _centrarMapa(LatLng ubicacion, double zoom) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(ubicacion, zoom);
      }
    });
  }

  void _mostrarEstadoGps(String mensaje) {
    if (!mounted) return;
    setState(() {
      _mensajeGps = mensaje;
      _cargandoGps = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = widget.supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: widget.supabase.from('chats').stream(primaryKey: ['id']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _miUbicacion == null) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF3F69FF)));
          }

          final chatsActivos = snapshot.data?.where((chat) {
                final participa = chat['comprador_id'] == myUid || chat['vendedor_id'] == myUid;
                final compartiendo = (chat['comprador_compartiendo'] == true) ||
                    (chat['vendedor_compartiendo'] == true);
                return participa && compartiendo;
              }).toList() ??
              [];

          final marcadores = <Marker>[
            if (_miUbicacion != null)
              Marker(
                width: 54,
                height: 54,
                point: _miUbicacion!,
                child: const Icon(Icons.my_location_rounded, color: Color(0xFF3F69FF), size: 42),
              ),
          ];

          for (final chat in chatsActivos) {
            final compradorLat = chat['comprador_lat'];
            final compradorLng = chat['comprador_lng'];
            final vendedorLat = chat['vendedor_lat'];
            final vendedorLng = chat['vendedor_lng'];

            if (chat['comprador_compartiendo'] == true && compradorLat != null && compradorLng != null) {
              marcadores.add(
                Marker(
                  width: 50,
                  height: 50,
                  point: LatLng((compradorLat as num).toDouble(), (compradorLng as num).toDouble()),
                  child: const Icon(Icons.person_pin_circle_rounded, color: Colors.blueAccent, size: 42),
                ),
              );
            }

            if (chat['vendedor_compartiendo'] == true && vendedorLat != null && vendedorLng != null) {
              marcadores.add(
                Marker(
                  width: 50,
                  height: 50,
                  point: LatLng((vendedorLat as num).toDouble(), (vendedorLng as num).toDouble()),
                  child: const Icon(Icons.store_mall_directory_rounded, color: Colors.greenAccent, size: 42),
                ),
              );
            }
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _miUbicacion ?? (marcadores.isNotEmpty ? marcadores.first.point : _centroTecsup),
                  initialZoom: 17,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.tecsup_community',
                    tileBuilder: (context, tileWidget, tile) {
                      return ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          -0.2126, -0.7152, -0.0722, 0, 255,
                          -0.2126, -0.7152, -0.0722, 0, 255,
                          -0.2126, -0.7152, -0.0722, 0, 255,
                          0, 0, 0, 1, 0,
                        ]),
                        child: tileWidget,
                      );
                    },
                  ),
                  if (marcadores.isNotEmpty) MarkerLayer(markers: marcadores),
                ],
              ),
              Positioned(
                top: 18,
                left: 16,
                right: 16,
                child: _MapaStatusCard(
                  cargandoGps: _cargandoGps,
                  mensajeGps: _mensajeGps,
                  hayUbicacion: _miUbicacion != null,
                  hayPinesCompartidos: chatsActivos.isNotEmpty,
                ),
              ),
              Positioned(
                right: 16,
                bottom: 20,
                child: FloatingActionButton.small(
                  backgroundColor: const Color(0xFF3F69FF),
                  onPressed: _obtenerUbicacionActual,
                  child: _cargandoGps
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MapaStatusCard extends StatelessWidget {
  final bool cargandoGps;
  final String? mensajeGps;
  final bool hayUbicacion;
  final bool hayPinesCompartidos;

  const _MapaStatusCard({
    required this.cargandoGps,
    required this.mensajeGps,
    required this.hayUbicacion,
    required this.hayPinesCompartidos,
  });

  @override
  Widget build(BuildContext context) {
    final icono = mensajeGps != null
        ? Icons.location_disabled_rounded
        : hayUbicacion
            ? Icons.gps_fixed_rounded
            : Icons.info_outline_rounded;

    final texto = mensajeGps ??
        (hayPinesCompartidos
            ? 'GPS activo. Tambien se muestran ubicaciones compartidas por chat.'
            : 'GPS activo. Los pines de otros usuarios apareceran al compartir ubicacion desde el chat.');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF21242D).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (cargandoGps)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Color(0xFF3F69FF), strokeWidth: 2),
            )
          else
            Icon(icono, color: mensajeGps != null ? Colors.orangeAccent : const Color(0xFF3F69FF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              cargandoGps ? 'Obteniendo ubicacion GPS...' : texto,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
