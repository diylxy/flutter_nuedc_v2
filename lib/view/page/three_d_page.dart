import 'package:flutter/material.dart';
import 'package:flutter_nuedc_v2/controller/threed_controller.dart';
import 'package:flutter_nuedc_v2/view/widget/minecraft_sword.dart';

class ThreedPage extends StatelessWidget {
  const ThreedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("3D视图")),
      body: Center(
        child: FractionallySizedBox(
          widthFactor: 1.0,
          heightFactor: 1.0,
          child: MinecraftSword3D(controller: ThreedController.to.controller),
        ),
      ),
    );
  }
}
