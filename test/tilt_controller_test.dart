import 'package:flutter_test/flutter_test.dart';

import 'package:gyro_maze/sensors/tilt_controller.dart';

void main() {
  test('controller starts in tilt mode', () {
    final controller = TiltController();
    expect(controller.inputMode.value, InputMode.tilt);
    expect(controller.input, Offset.zero);
    controller.dispose();
  });

  test('touch mode clamps input to the normalized range', () {
    final controller = TiltController();
    controller.setInputMode(InputMode.touch);
    controller.setTouchInput(const Offset(4, -3));
    expect(controller.input.dx, 1);
    expect(controller.input.dy, -1);
    controller.dispose();
  });
}
