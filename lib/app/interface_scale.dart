import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/secure/data_dir.dart';
import '../services/diag_log.dart';

const interfaceScales = [1.0, 1.25, 1.5, 1.75, 2.0];

bool get supportsInterfaceScale =>
    Platform.isLinux || Platform.isMacOS || Platform.isWindows;

class InterfaceScaleNotifier extends StateNotifier<double> {
  InterfaceScaleNotifier({File? file})
    : _file = file ?? File('${configDir()}/interface-scale'),
      super(1) {
    try {
      if (_file.existsSync()) {
        final value = double.tryParse(_file.readAsStringSync().trim());
        if (interfaceScales.contains(value)) state = value!;
      }
    } on FileSystemException catch (error, stack) {
      DiagLog.instance.error(
        'settings',
        'Cannot load interface scale',
        error,
        stack,
      );
    }
  }

  final File _file;

  void set(double scale) {
    if (!interfaceScales.contains(scale)) {
      throw ArgumentError.value(scale, 'scale');
    }
    try {
      _file.parent.createSync(recursive: true);
      _file.writeAsStringSync('$scale');
    } on FileSystemException catch (error, stack) {
      DiagLog.instance.error(
        'settings',
        'Cannot save interface scale',
        error,
        stack,
      );
    }
    state = scale;
  }
}

final interfaceScaleProvider =
    StateNotifierProvider<InterfaceScaleNotifier, double>(
      (_) => InterfaceScaleNotifier(),
    );

class InterfaceScale extends StatelessWidget {
  const InterfaceScale({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final size = constraints.biggest / scale;
      return FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: MediaQuery(
            data: media.copyWith(
              size: size,
              devicePixelRatio: media.devicePixelRatio * scale,
              padding: media.padding / scale,
              viewPadding: media.viewPadding / scale,
              viewInsets: media.viewInsets / scale,
              systemGestureInsets: media.systemGestureInsets / scale,
            ),
            child: child,
          ),
        ),
      );
    },
  );
}
