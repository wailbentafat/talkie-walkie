import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56.0),
        child: AppBar(
          backgroundColor: Colors.deepPurple,
          title: const Text('Home'),
          
        ),
        
      ),
      body:  Center(
        child:GestureDetector(
          onLongPress: (){},
          onLongPressUp: (){},
          child:Icon(
            Icons.mic,
            size: 200,
            color: Colors.deepPurpleAccent,
          ) ,
          

        ),

      ),
    );
  }
}