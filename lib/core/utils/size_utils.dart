import 'dart:core';
import 'package:flutter/material.dart';

const num figmaDesignWidth = 430;
const num figmaDesignHeight = 932;
const num figmaDesignStatusBar = 0;

extension ResponsiveExtension on num {
  double get _width => SizeUtils.width;
  double get _height => SizeUtils.height;

  double get h => ((this * _width) / figmaDesignWidth);
  double get v => (this * _height) / (figmaDesignHeight - figmaDesignStatusBar);

  double get adaptSize {
    var height = v;
    var width = h;
    return height < width ? height.toDoubleValue() : width.toDoubleValue();
  }

  double get fSize => adaptSize;
}

extension FormatExtension on double {
  double toDoubleValue({int fractionDigits = 2}) {
    return double.parse(toStringAsFixed(fractionDigits));
  }

  double isNonZero({num defaultValue = 0.0}) {
    return this > 0 ? this : defaultValue.toDouble();
  }
}

enum DeviceType { mobile, tablet, desktop }

typedef ResponsiveBuild = Widget Function(
  BuildContext context,
  Orientation orientation,
  DeviceType deviceType,
);

class Sizer extends StatelessWidget {
  const Sizer({super.key, required this.builder});
  final ResponsiveBuild builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return OrientationBuilder(
          builder: (context, orientation) {
            SizeUtils.setScreenSize(constraints, orientation);
            return builder(context, orientation, SizeUtils.deviceType);
          },
        );
      },
    );
  }
}

class SizeUtils {
  // Initialize with default values instead of late
  static BoxConstraints boxConstraints = const BoxConstraints();
  static Orientation orientation = Orientation.portrait;
  static DeviceType deviceType = DeviceType.mobile;
  static double height = figmaDesignHeight.toDouble();
  static double width = figmaDesignWidth.toDouble();

  static void setScreenSize(
    BoxConstraints constraints,
    Orientation currentOrientation,
  ) {
    boxConstraints = constraints;
    orientation = currentOrientation;

    if (orientation == Orientation.portrait) {
      width = boxConstraints.maxWidth.isNonZero(defaultValue: figmaDesignWidth);
      height = boxConstraints.maxHeight.isNonZero(
        defaultValue: figmaDesignHeight,
      );
    } else {
      width = boxConstraints.maxHeight.isNonZero(
        defaultValue: figmaDesignWidth,
      );
      height = boxConstraints.maxWidth.isNonZero(
        defaultValue: figmaDesignHeight,
      );
    }
    deviceType = DeviceType.mobile;
  }
}

class Gap {
  // For horizontal spacing (width)
  static SizedBox h(double value) {
    return SizedBox(width: value.h);
  }

  // For vertical spacing (height)
  static SizedBox v(double value) {
    return SizedBox(height: value.v);
  }
}
