import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class ChatScreen extends StatefulWidget {
  // Cambiado a dynamic para aceptar tanto IDs numéricos (int) como UUIDs (String)
  final dynamic chatId; 
  final String productoTitulo;

  const ChatScreen({Key? key, required this.chatId, required this.productoTitulo}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _chatStreamSubscription;
  bool _compartiendoUbicacion = false;
  Map<String, dynamic>? _chatData;
  String _nombreContraparte = "Usuario";

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
    // Escuchamos los cambios del chat forzando el ID a su valor real
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

          // Evitamos fallos buscando el perfil de la contraparte de forma segura
          String nombreTemp = "Compañero Tecsup";
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

  Future<void> _conmutarUbicacion(bool valor) async {
    final myUid = _supabase.auth.currentUser?.id;
    if (myUid == null || _chatData == null) return;

    final esVendedor = _chatData!['vendedor_id'] == myUid;
    final campoCompartir = esVendedor ? 'vendedor_compartiendo' : 'comprador_compartiendo';
    final latCampo = esVendedor ? 'vendedor_lat' : 'comprador_lat';
    final lngCampo = esVendedor ? 'vendedor_lng' : 'comprador_lng';

    if (valor) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      setState(() => _compartiendoUbicacion = true);

      try {
        Position pos = await Geolocator.getCurrentPosition();
        await _supabase.from('chats').update({
          campoCompartir: true,
          latCampo: pos.latitude,
          lngCampo: pos.longitude,
        }).eq('id', widget.chatId);
      } catch (e) {
        print("Error obteniendo ubicación: $e");
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

  Future<void> _concretarVenta() async {
    await _supabase.from('chats').update({'estado': 'concretado'}).eq('id', widget.chatId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Trato concretado! Ahora pueden activar el mapa del campus.')),
    );
  }

  Future<void> _eliminarChat() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF21242D),
        title: const Text('¿Eliminar chat?', style: TextStyle(color: Colors.white)),
        content: const Text('Esta acción borrará el historial por completo.', style: TextStyle(color: Colors.grey)),
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
    await _supabase.from('mensajes').insert({
      'chat_id': widget.chatId,
      'remitente_id': myUid,
      'contenido': texto,
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _supabase.auth.currentUser?.id;
    final esVendedor = _chatData != null && _chatData!['vendedor_id'] == myUid;
    final estaConcretado = _chatData != null && _chatData!['estado'] == 'concretado';

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
            Text(_nombreContraparte, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            Text(widget.productoTitulo, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
        actions: [
          if (esVendedor && !estaConcretado)
            TextButton.icon(
              onPressed: _concretarVenta,
              icon: const Icon(Icons.handshake_outlined, color: Colors.greenAccent, size: 16),
              label: const Text('Concretar', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
            onPressed: _eliminarChat,
          ),
        ],
      ),
      body: Column(
        children: [
          if (estaConcretado)
            Container(
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.share_location_rounded, color: Color(0xFF3F69FF), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Compartir mi ubicación en el Campus', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  Switch(
                    value: _compartiendoUbicacion,
                    activeColor: const Color(0xFF3F69FF),
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
                  .eq('chat_id', widget.chatId)
                  .order('created_at', ascending: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF3F69FF)));
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
                        hintText: "Escribe un mensaje...",
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