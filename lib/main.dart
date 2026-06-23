import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tecsup_community/src/views/login/login_screen.dart';
import 'package:tecsup_community/src/views/login/register_screen.dart';
import 'package:tecsup_community/src/views/home/navigation_home.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  // Inicialización con las credenciales de tu proyecto de Supabase
  await Supabase.initialize(
    url: 'https://fbkcburyxzmrcarvgihe.supabase.co',
    anonKey: 'sb_publishable_1TjqFub1tg4tLH3S0SSkbQ_ioM-WYAx',
  );


  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    // Instanciamos el cliente una sola vez para pasarlo de forma limpia
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;


    return MaterialApp(
      title: 'Tecsup Community',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        useMaterial3: true,
      ),
      // ¡CORREGIDO! Pasamos el parámetro obligatorio a NavigationHome si hay sesión activa
      home: session != null
          ? NavigationHome(supabase: supabase)
          : LoginScreen(supabase: supabase),
      routes: {
        '/login': (context) => LoginScreen(supabase: supabase),
        '/register': (context) => RegisterScreen(supabase: supabase),
        // ¡CORREGIDO! Pasamos el parámetro aquí también para evitar errores al navegar mediante rutas nombradas
        '/home': (context) => NavigationHome(supabase: supabase),
      },
    );
  }
}
