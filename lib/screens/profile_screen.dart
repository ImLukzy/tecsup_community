import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  final SupabaseClient supabase;

  const ProfileScreen({Key? key, required this.supabase}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nombreController = TextEditingController();
  bool _isLoading = false;
  
  XFile? _imageFile;
  Uint8List? _webImageBytes;
  String? _avatarUrlActual;
  String _correoUsuario = "";
  Map<String, dynamic>? _columnasDisponibles;

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosPerfil() async {
    final user = widget.supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _correoUsuario = user.email ?? "";
    });

    try {
      final data = await widget.supabase
          .from('perfiles') 
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _columnasDisponibles = data;
          _nombreController.text = data['nombre'] ?? data['full_name'] ?? "";
          // Detectamos automáticamente cuál columna de imagen usas en tu BD
          _avatarUrlActual = data['avatar'] ?? data['foto_url'] ?? data['avatar_url'] ?? data['imagen'];
        });
      }
    } catch (e) {
      print("Error cargando perfil: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarImagen() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _webImageBytes = bytes;
            _imageFile = pickedFile;
          });
        } else {
          setState(() {
            _imageFile = pickedFile;
          });
        }
      }
    } catch (e) {
      print("Error al seleccionar imagen: $e");
    }
  }

  Future<String?> _subirAvatar(String userId) async {
    if (_imageFile == null) return _avatarUrlActual;

    try {
      final fileExt = _imageFile!.name.split('.').last;
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = fileName;

      if (kIsWeb && _webImageBytes != null) {
        await widget.supabase.storage.from('avatars').uploadBinary(
              filePath,
              _webImageBytes!,
              fileOptions: FileOptions(contentType: 'image/$fileExt', cacheControl: '3600'),
            );
      } else {
        final bytes = await _imageFile!.readAsBytes();
        await widget.supabase.storage.from('avatars').uploadBinary(filePath, bytes);
      }

      return widget.supabase.storage.from('avatars').getPublicUrl(filePath);
    } catch (e) {
      print("Error subiendo avatar a Storage: $e");
      return null;
    }
  }

  Future<void> _guardarCambios() async {
    final user = widget.supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      String? nuevaAvatarUrl = _avatarUrlActual;
      if (_imageFile != null) {
        nuevaAvatarUrl = await _subirAvatar(user.id);
      }

      // Estructuramos el mapa dinámicamente basándonos en lo que la base de datos acepta
      final Map<String, dynamic> datosAEnviar = {'id': user.id};

      if (_columnasDisponibles != null) {
        // Validación de columna de Nombre
        if (_columnasDisponibles!.containsKey('nombre')) datosAEnviar['nombre'] = _nombreController.text.trim();
        if (_columnasDisponibles!.containsKey('full_name')) datosAEnviar['full_name'] = _nombreController.text.trim();

        // Validación inteligente de columna de Imagen para evitar el error PGRST204
        if (_columnasDisponibles!.containsKey('avatar')) datosAEnviar['avatar'] = nuevaAvatarUrl;
        if (_columnasDisponibles!.containsKey('imagen')) datosAEnviar['imagen'] = nuevaAvatarUrl;
        if (_columnasDisponibles!.containsKey('foto_url')) datosAEnviar['foto_url'] = nuevaAvatarUrl;
        if (_columnasDisponibles!.containsKey('avatar_url')) datosAEnviar['avatar_url'] = nuevaAvatarUrl;
      } else {
        // Fallback clásico si el registro es completamente nuevo
        datosAEnviar['nombre'] = _nombreController.text.trim();
      }

      await widget.supabase.from('perfiles').upsert(datosAEnviar);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Perfil actualizado correctamente.'), backgroundColor: Colors.green),
      );

      setState(() {
        _avatarUrlActual = nuevaAvatarUrl;
        _imageFile = null;
        _webImageBytes = null;
      });
    } catch (e) {
      print("Error guardando cambios del perfil: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (_webImageBytes != null) {
      avatarImage = MemoryImage(_webImageBytes!);
    } else if (_avatarUrlActual != null && _avatarUrlActual!.isNotEmpty) {
      avatarImage = NetworkImage(_avatarUrlActual!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF21242D),
        elevation: 0,
        title: const Text('Mi Perfil', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3F69FF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _seleccionarImagen,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: const Color(0xFF3F69FF),
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? const Icon(Icons.school, size: 55, color: Colors.white)
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF3F69FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Haz clic para cambiar foto",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 32),
                  
                  _buildInputField(
                    label: "Correo Institucional (No editable)",
                    controller: TextEditingController(text: _correoUsuario),
                    enabled: false,
                  ),
                  const SizedBox(height: 20),
                  
                  _buildInputField(
                    label: "Nombre Completo",
                    controller: _nombreController,
                    enabled: true,
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _guardarCambios,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3F69FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Guardar Cambios',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInputField({required String label, required TextEditingController controller, required bool enabled}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF21242D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            style: TextStyle(color: enabled ? Colors.white : Colors.white60),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}