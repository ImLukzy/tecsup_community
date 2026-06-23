import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';


class ProductDetailModal extends StatelessWidget {
  final Map<String, dynamic> prod;
  final bool esMio;
  final bool tieneLike;
  final VoidCallback onLikePressed;
  final VoidCallback onActionPressed;


  const ProductDetailModal({
    Key? key,
    required this.prod,
    required this.esMio,
    required this.tieneLike,
    required this.onLikePressed,
    required this.onActionPressed,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    final String imageUrl = prod['image_url'] ?? '';


    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Contenedor de la Imagen Adaptada (Soporta red y archivos locales/cámara)
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF181A20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.startsWith('http')
                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey, size: 50))
                    : (kIsWeb
                        ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey, size: 50))
                        : Image.file(File(imageUrl), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey, size: 50))),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    prod['titulo'] ?? 'Sin título',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    tieneLike ? Icons.favorite : Icons.favorite_border,
                    color: tieneLike ? Colors.red : Colors.grey,
                  ),
                  onPressed: onLikePressed,
                ),
              ],
            ),
            Text(
              "S/. ${prod['precio'] ?? '0.00'}",
              style: const TextStyle(color: Color(0xFF3F69FF), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              prod['descripcion'] ?? 'Sin descripción disponible.',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onActionPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: esMio ? Colors.redAccent : const Color(0xFF3F69FF),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                esMio ? "Eliminar Publicación" : "Contactar Vendedor",
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
