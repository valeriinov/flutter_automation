import 'package:image/image.dart' as image;

/// {@category Utils}
///
/// Lays the system keyboard over a screenshot the driver took.
///
/// The driver renders the Flutter layer alone, so the keyboard that the OS
/// draws over it never reaches its screenshot. A screenshot of the whole device
/// holds the keyboard. Outside the keyboard and the status bar, both
/// screenshots show the same pixels. The function therefore takes the rows that
/// the keyboard covers from it.
abstract final class AutomationKeyboardComposite {
  /// Returns a copy of [screen] whose bottom [keyboardInset] rows are the rows
  /// of [deviceScreen].
  ///
  /// The [screen] parameter is the screenshot of the driver.
  /// The [deviceScreen] parameter is the screenshot of the device at the same
  /// moment, of the same size.
  /// The [keyboardInset] parameter is the height of the keyboard in physical
  /// pixels.
  static image.Image compose({
    required image.Image screen,
    required image.Image deviceScreen,
    required int keyboardInset,
  }) {
    if (!_haveSameSize(screen, deviceScreen)) {
      throw StateError(
        'The device screenshot is '
        '${deviceScreen.width}x${deviceScreen.height} px, the driver '
        'screenshot ${screen.width}x${screen.height} px.',
      );
    }

    final keyboardHeight = keyboardInset.clamp(0, screen.height);

    if (keyboardHeight == 0) {
      return screen.clone();
    }

    final keyboardTop = screen.height - keyboardHeight;
    final keyboard = image
        .copyCrop(
          deviceScreen,
          x: 0,
          y: keyboardTop,
          width: screen.width,
          height: keyboardHeight,
        )
        .convert(format: screen.format, numChannels: screen.numChannels);

    return image.compositeImage(
      screen.clone(),
      keyboard,
      dstY: keyboardTop,
      blend: image.BlendMode.direct,
    );
  }

  static bool _haveSameSize(image.Image first, image.Image second) {
    return first.width == second.width && first.height == second.height;
  }
}
