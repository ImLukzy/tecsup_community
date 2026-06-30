import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final dynamic chatId;
  final String productoTitulo;

  const ChatScreen({super.key, required this.chatId, required this.productoTitulo});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _chatStreamSubscription;
  bool _compartiendoUbicacion = false;
  Map<String, dynamic>? _chatData;
  String _nombreContraparte = 'Usuario';

  @override
  void initState() {
    super.initState();
    _cargarDatosChat();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _chatStreamSubscription?.cancel();
    super.dispose();
  }

  void _cargarDatosChat() {
    _chatStreamSubscription = _supabase
        .from('chats')
        .stream(primaryKey: ['id'])
        .eq('id', widget.chatId)
        .listen((data) async {
      if (data.isEmpty || !mounted) return;

      final chat = data.first;
      final myUid = _supabase.auth.currentUser?.id;
      final esVendedor = chat['vendedor_id'] == myUid;
      final contraparteId = esVendedor ? chat['comprador_id'] : chat['vendedor_id'];

      String nombreTemp = 'Companero Tecsup';
      if (contraparteId != null) {
        try {
          final perfil = await _supabase
              .from('perfiles')
              .select('nombre_completo')
              .eq('id', contraparteId)
              .maybeSingle();
          if (perfil != null && perfil['nombre_completo'] != null) {
            nombreTemp = perfil['nombre_completo'];
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _chatData = chat;
          _nombreContraparte = nombreTemp;
          _compartiendoUbicacion = esVendedor
              ? (chat['vendedor_compartiendo'] ?? false)
              : (chat['comprador_compartiendo'] ?? false);
        });
      }
    });
  }

  String _estadoConfirmacionSolicitadaPor(bool esVendedor) {
    return esVendedor ? 'confirmacion_vendedor' : 'confirmacion_comprador';
  }

  bool _confirmacionSolicitadaPorMi(String? estado, bool esVendedor) {
    return estado == _estadoConfirmacionSolicitadaPor(esVendedor);
  }

  bool _puedoConfirmarVenta(String? estado, bool esVendedor) {
    return (estado == 'confirmacion_vendedor' && !esVendedor) ||
        (estado == 'confirmacion_comprador' && esVendedor);
  }

  bool _ventaPendiente(String? estado) {
    return estado == 'confirmacion_vendedor' || estado == 'confirmacion_comprador';
  }

  Future<void> _insertarMensajeSistema(String contenido) async {
    final myUid = _supabase.auth.currentUser?.id;
    if (myUid == null) return;

    await _supabase.from('mensajes').insert({
      'chat_id': widget.chatId,
      'remitente_id': myUid,
      'contenido': contenido,
    });
  }

  Future<void> _conmutarUbicacion(bool valor) async {
    final myUid = _supabase.auth.currentUser?.id;
    if (myUid == null || _chatData == null) return;
    if (_chatData!['estado'] != 'concretado') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero ambos deben confirmar la venta.')),
      );
      return;
    }

    final esVendedor = _chatData!['vendedor_id'] == myUid;
    final campoCompartir = esVendedor ? 'vendedor_compartiendo' : 'comprador_compartiendo';
    final latCampo = esVendedor ? 'vendedor_lat' : 'comprador_lat';
    final lngCampo = esVendedor ? 'vendedor_lng' : 'comprador_lng';

    if (valor) {
      final servicioActivo = await Geolocator.isLocationServiceEnabled();
      if (!servicioActivo) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activa el GPS del celular para compartir tu ubicacion.')),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicacion denegado.')),
        );
        return;
      }

      setState(() => _compartiendoUbicacion = true);

      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        await _supabase.from('chats').update({
          campoCompartir: true,
          latCampo: pos.latitude,
          lngCampo: pos.longitude,
        }).eq('id', widget.chatId);
      } catch (e) {
        if (!mounted) return;
        setState(() => _compartiendoUbicacion = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error obteniendo ubicacion: $e')),
        );
      }
    } else {
      setState(() => _compartiendoUbicacion = false);
      await _supabase.from('chats').update({
        campoCompartir: false,
        latCampo: null,
        lngCampo: null,
      }).eq('id', widget.chatId);
    }
  }

  Future<void> _solicitarConfirmacionVenta() async {
    final myUid = _supabase.auth.currentUser?.id;
    if (myUid == null || _chatData == null) return;

    final esVendedor = _chatData!['vendedor_id'] == myUid;
    final estado = _estadoConfirmacionSolicitadaPor(esVendedor);

    await _supabase.from('chats').update({'estado': estado}).eq('id', widget.chatId);
    await _insertarMensajeSistema(
      esVendedor
          ? 'El vendedor solicito confirmar la venta.'
          : 'El comprador solicito confirmar la compra.',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud enviada. La otra persona debe confirmar.')),
    );
  }

  Future<void> _confirmarVenta() async {
    await _supabase.from('chats').update({'estado': 'concretado'}).eq('id', widget.chatId);
    await _insertarMensajeSistema('Venta confirmada. Ahora ambos pueden compartir ubicacion en el campus.');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Venta confirmada. Ya pueden compartir ubicacion.')),
    );
  }

  Future<void> _cancelarConfirmacionVenta() async {
    await _supabase.from('chats').update({
      'estado': 'negociacion',
      'comprador_compartiendo': false,
      'comprador_lat': null,
      'comprador_lng': null,
      'vendedor_compartiendo': false,
      'vendedor_lat': null,
      'vendedor_lng': null,
    }).eq('id', widget.chatId);
    await _insertarMensajeSistema('La confirmacion de venta fue cancelada.');
  }

  Future<void> _mostrarOpcionesConcretar(bool esVendedor, String? estado) async {
    final puedeConfirmar = _puedoConfirmarVenta(estado, esVendedor);
    final pendientePorMi = _confirmacionSolicitadaPorMi(estado, esVendedor);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF21242D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    puedeConfirmar ? Icons.verified_rounded : Icons.handshake_outlined,
                    color: Colors.greenAccent,
                  ),
                  title: Text(
                    puedeConfirmar ? 'Confirmar venta' : 'Solicitar confirmar venta',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    puedeConfirmar
                        ? 'Al confirmar, se habilita compartir ubicacion para ambos.'
                        : pendientePorMi
                            ? 'Ya enviaste la solicitud. Espera la confirmacion.'
                            : 'La otra persona tendra que aceptar antes de compartir GPS.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  enabled: !pendientePorMi,
                  onTap: pendientePorMi
                      ? null
                      : () async {
                          Navigator.pop(context);
                          if (puedeConfirmar) {
                            await _confirmarVenta();
                          } else {
                            await _solicitarConfirmacionVenta();
                          }
                        },
                ),
                if (_ventaPendiente(estado))
                  ListTile(
                    leading: const Icon(Icons.close_rounded, color: Colors.redAccent),
                    title: const Text('Cancelar solicitud', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Vuelve el trato a negociacion.', style: TextStyle(color: Colors.grey)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _cancelarConfirmacionVenta();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _eliminarChat() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF21242D),
        title: const Text('Eliminar chat?', style: TextStyle(color: Colors.white)),
        content: const Text('Esta accion borrara el historial por completo.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _supabase.from('chats').delete().eq('id', widget.chatId);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _enviarMensaje() async {
    final texto = _msgController.text.trim();
    if (texto.isEmpty) return;
    final myUid = _supabase.auth.currentUser?.id;
    if (myUid == null) return;

    _msgController.clear();
    try {
      await _supabase.from('mensajes').insert({
        'chat_id': widget.chatId,
        'remitente_id': myUid,
        'contenido': texto,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar mensaje: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _supabase.auth.currentUser?.id;
    final esVendedor = _chatData != null && _chatData!['vendedor_id'] == myUid;
    final estadoChat = _chatData?['estado']?.toString();
    final estaConcretado = estadoChat == 'concretado';
    final ventaPendiente = _ventaPendiente(estadoChat);

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF21242D),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _nombreContraparte,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(widget.productoTitulo, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
        actions: [
          if (!estaConcretado && _chatData != null)
            TextButton.icon(
              onPressed: () => _mostrarOpcionesConcretar(esVendedor, estadoChat),
              icon: Icon(
                _puedoConfirmarVenta(estadoChat, esVendedor)
                    ? Icons.verified_rounded
                    : Icons.handshake_outlined,
                color: Colors.greenAccent,
                size: 16,
              ),
              label: Text(
                _puedoConfirmarVenta(estadoChat, esVendedor) ? 'Confirmar' : 'Concretar',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
            onPressed: _eliminarChat,
          ),
        ],
      ),
      body: Column(
        children: [
          if (ventaPendiente)
            Container(
              color: const Color(0xFF2D2F36),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions_rounded, color: Colors.amberAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _puedoConfirmarVenta(estadoChat, esVendedor)
                          ? 'La otra persona solicito concretar. Confirma para habilitar el GPS.'
                          : 'Solicitud enviada. Esperando confirmacion de la otra persona.',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  if (_puedoConfirmarVenta(estadoChat, esVendedor))
                    TextButton(
                      onPressed: _confirmarVenta,
                      child: const Text('Confirmar'),
                    ),
                ],
              ),
            ),
          if (estaConcretado)
            Container(
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.share_location_rounded, color: Color(0xFF3F69FF), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Compartir mi ubicacion en el Campus',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  Switch(
                    value: _compartiendoUbicacion,
                    activeThumbColor: const Color(0xFF3F69FF),
                    onChanged: _conmutarUbicacion,
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('mensajes')
                  .stream(primaryKey: ['id'])
                  .eq('chat_id', widget.chatId.toString())
                  .order('created_at', ascending: true),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF3F69FF)));
                }
                final mensajes = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final msg = mensajes[index];
                    final esMio = msg['remitente_id'] == myUid;
                    return Align(
                      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: esMio ? const Color(0xFF3F69FF) : const Color(0xFF21242D),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(msg['contenido'] ?? '', style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: const Color(0xFF21242D),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onSubmitted: (_) => _enviarMensaje(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF3F69FF)),
                    onPressed: _enviarMensaje,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
