import 'package:flutter/material.dart';
import '../chat_screen.dart';


class ProductCard extends StatelessWidget {
  final Map<String, dynamic> prod;
  final VoidCallback onTap;


  const ProductCard({
    Key? key,
    required this.prod,
    required this.onTap,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // ¡CORREGIDO! Clip.antiAlias va dentro del contenedor principal
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF21242D), // El color exacto de tus foros
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: const Color(0xFF181A20),
                child: Image.network(
                  prod['image_url'] ?? 'https://images.unsplash.com/photo-1531403009284-440f080d1e12?w=500',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "S/. ${prod['precio'] ?? '0'}",
                    style: const TextStyle(color: Color(0xFF3F69FF), fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prod['titulo'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(Icons.location_on_outlined, color: Colors.grey, size: 12),
                      SizedBox(width: 4),
                      Text(
                        "Arequipa, AR",
                        // ¡CORREGIDO! Se cambió 'size' por 'fontSize'
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
