
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vision_offline/provider.dart';

import 'chatscreen.dart';
void main(){
  runApp(
      ChangeNotifierProvider(
        create: (_)=>ChatProvider(),
        child:const MyApp(),
      )
  );
}
class MyApp extends StatelessWidget{
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Edu Vison",
      theme: ThemeData.dark(),
      home: const ChatScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}