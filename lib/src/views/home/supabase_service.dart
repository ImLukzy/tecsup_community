import 'package:supabase_flutter/supabase_flutter.dart';


class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;


  // ==================== AUTH & USUARIOS ====================
 
  // Registrar un alumno en la tabla relacional 'usuarios'
  Future<void> registrarUsuarioInDB({
    required String uid,
    required String nombre,
    required String correo,
    required String carrera,
  }) async {
    await _client.from('usuarios').insert({
      'id': uid,
      'nombre': nombre,
      'correo': correo,
      'carrera': carrera,
      'reputacion': 100, // Inician con reputación perfecta
    });
  }


  // ==================== FOROS (COMUNIDAD) ====================


  // Crear un nuevo hilo de discusión
  Future<void> crearHiloForo({
    required String titulo,
    required String contenido,
    required String categoria,
    required String autorId,
  }) async {
    await _client.from('foros').insert({
      'titulo': titulo,
      'contenido': contenido,
      'categoria': categoria,
      'autor_id': autorId,
    });
  }


  // Stream en tiempo real (Sockets) para escuchar nuevos hilos de foros
  Stream<List<Map<String, dynamic>>> obtenerForosStream() {
    return _client
        .from('foros')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }


  // ==================== ENCUESTAS ====================


  // Emitir un voto en tiempo real y asegurar consistencia
  Future<void> emitirVoto({
    required int encuestaId,
    required String usuarioId,
    required int opcionId,
  }) async {
    await _client.from('votos').insert({
      'encuesta_id': encuestaId,
      'usuario_id': usuarioId,
      'opcion_id': opcionId,
    });
  }
}
