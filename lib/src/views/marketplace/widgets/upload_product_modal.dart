import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadProductModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onUpload;

  const UploadProductModal({Key? key, required this.onUpload}) : super(key: key);

  @override
  State<UploadProductModal> createState() => _UploadProductModalState();
}

class _UploadProductModalState extends State<UploadProductModal> {
  final _supabase = Supabase.instance.client;
  final _tituloController = TextEditingController();
  final _precioController = TextEditingController();
  final _descripcionController = TextEditingController();

  Uint8List? _webImageBytes; // Guarda la imagen en memoria para Web
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _tituloController.dispose();
    _precioController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _webImageBytes = bytes;
        });
      }
    } catch (e) {
      print("Error al seleccionar imagen: $e");
    }
  }

  Future<void> _mostrarOpcionesImagen() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF21242D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded, color: Color(0xFF3F69FF)),
                  title: const Text('Tomar foto', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarImagen(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF3F69FF)),
                  title: const Text('Elegir de galeria', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarImagen(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _guardarProducto() async {
    final user = _supabase.auth.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Debes iniciar sesión para publicar.')),
      );
      return;
    }

    if (_tituloController.text.trim().isEmpty || _precioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ El título y el precio son obligatorios.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? imageUrl;

      // 1. Subir imagen a Supabase Storage si seleccionó una
      if (_webImageBytes != null) {
        final String fileExt = 'jpg';
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_product.$fileExt';

        // Asegúrate de tener creado un bucket público llamado 'productos' en Supabase Storage
        await _supabase.storage.from('productos').uploadBinary(
          fileName,
          _webImageBytes!,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );

        imageUrl = _supabase.storage.from('productos').getPublicUrl(fileName);
      }

      // 2. Insertar los datos estructurados en la tabla
      final nuevoProducto = {
        'usuario_id': user.id,
        'titulo': _tituloController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'precio': double.tryParse(_precioController.text.trim()) ?? 0.0,
        'image_url': imageUrl,
        'cantidad': 1,
        'latitud': -16.43,
        'longitud': -71.51,
      };

      final data = await _supabase.from('marketplace').insert(nuevoProducto).select().single();

      if (!mounted) return;
      widget.onUpload(data); // Ejecuta el callback para actualizar la lista
      Navigator.pop(context); // Cierra el modal

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📦 ¡Producto publicado con éxito!')),
      );
    } catch (e) {
      print("Error detallado al guardar producto: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al subir producto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF21242D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nuevo Producto',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Selector de Imagen
              GestureDetector(
                onTap: _mostrarOpcionesImagen,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF181A20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: _webImageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_webImageBytes!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: Colors.grey, size: 40),
                            SizedBox(height: 8),
                            Text('Añadir Foto del Artículo', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Campo Título
              TextField(
                controller: _tituloController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Título del producto',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF181A20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),

              // Campo Precio
              TextField(
                controller: _precioController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Precio (S/.)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF181A20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),

              // Campo Descripción
              TextField(
                controller: _descripcionController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Descripción del artículo',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF181A20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              // Botón de Guardar
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F69FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isSaving ? null : _guardarProducto,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Publicar Producto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
