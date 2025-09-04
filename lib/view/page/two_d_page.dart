import 'package:flutter/material.dart';
import 'package:flutter_nuedc_v2/view/page/main_page.dart';

class TwodPage extends StatelessWidget {
  const TwodPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("2D视图")),
      body: Center(
        child: FractionallySizedBox(
          widthFactor: 1.0,
          heightFactor: 1.0,
          child: FractionalLiTexture((210 - 40) / (297 - 40), 1),
        ),
      ),
    );
  }
}
