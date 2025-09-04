import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter_nuedc_v2/utils/input_image.dart';
import 'package:opencv_core/opencv.dart' as cv;

extension CvMatUiImageExtension on cv.Mat {
  Future<ui.Image> toUiImage({
    ui.PixelFormat format = ui.PixelFormat.bgra8888,
  }) async {
    cv.Mat rgbaMat;
    if (type == cv.MatType.CV_8UC4) {
      rgbaMat = this;
    } else if (type == cv.MatType.CV_8UC1) {
      rgbaMat = await cv.cvtColorAsync(this, cv.COLOR_GRAY2BGRA);
    } else if (type == cv.MatType.CV_8UC3) {
      rgbaMat = await cv.cvtColorAsync(this, cv.COLOR_BGR2BGRA);
    } else {
      throw UnsupportedError("Unsupported Image");
    }
    final immutable = await ui.ImmutableBuffer.fromUint8List(rgbaMat.data);
    ui.ImageDescriptor desc = ui.ImageDescriptor.raw(
      immutable,
      width: width,
      height: height,
      pixelFormat: format,
    );
    final codec = await desc.instantiateCodec();
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

extension CameraToCVExtension on CameraImage {
  Future<cv.Mat> _yuv420pToBGR(CameraImage image) async {
    final bytes = BytesBuilder();
    bytes.add(image.planes[0].bytes);
    bytes.add(image.planes[1].bytes);
    bytes.add(image.planes[2].bytes);
    cv.Mat mat = cv.Mat.fromList(
      image.height * 3 ~/ 2,
      image.width,
      cv.MatType.CV_8UC1,
      bytes.takeBytes(),
    );
    await cv.cvtColorAsync(mat, cv.COLOR_YUV2BGR_I420, dst: mat);
    return mat;
  }

  Future<cv.Mat> _nv21ToBGR(CameraImage image) async {
    throw UnimplementedError();
    // final bytes = BytesBuilder();
    // bytes.add(image.planes[0].bytes);
    // bytes.add(image.planes[1].bytes);
    // assert(image.planes.length == 2);
    // cv.Mat mat = cv.Mat.fromList(
    //   image.height * 3 ~/ 2,
    //   image.width,
    //   cv.MatType.CV_8UC1,
    //   bytes.takeBytes(),
    // );
    // await cv.cvtColorAsync(mat, cv.COLOR_YUV2BGR_NV21, dst: mat);
    // return mat;
  }

  Future<cv.Mat> toCV({int rotationCompensation = 90}) async {
    final format = InputImageFormatValue.fromRawValue(this.format.raw);
    assert(format != null);

    cv.Mat mat = switch (format) {
      InputImageFormat.yuv_420_888 => await _yuv420pToBGR(this),
      InputImageFormat.nv21 => await _nv21ToBGR(this),
      _ => throw UnimplementedError(),
    };

    // final sensorOrientation = controller?.description.sensorOrientation;
    // var rotationCompensation =
    //     _orientations[controller?.value.deviceOrientation];
    // if (rotationCompensation == null || sensorOrientation == null) return;
    // if (controller?.description.lensDirection == CameraLensDirection.front) {
    //   // front-facing
    //   rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    // } else {
    //   // back-facing
    //   rotationCompensation =
    //       (sensorOrientation - rotationCompensation + 360) % 360;
    // }
    switch (rotationCompensation) {
      case 90:
        await cv.rotateAsync(mat, cv.ROTATE_90_CLOCKWISE, dst: mat);
      case 180:
        await cv.rotateAsync(mat, cv.ROTATE_180, dst: mat);
      case 270:
        await cv.rotateAsync(mat, cv.ROTATE_90_COUNTERCLOCKWISE, dst: mat);
      default:
    }
    return mat;
  }
}

// Uint8List yuv420ToNV21(CameraImage image) {
//   final width = image.width;
//   final height = image.height;
//   // Planes from CameraImage
//   final yPlane = image.planes[0];
//   final uPlane = image.planes[1];
//   final vPlane = image.planes[2];
//   // Buffers from Y, U, and V planes
//   final yBuffer = yPlane.bytes;
//   final uBuffer = uPlane.bytes;
//   final vBuffer = vPlane.bytes;
//   // Total number of pixels in NV21 format
//   final numPixels = width * height + (width * height ~/ 2);
//   final nv21 = Uint8List(numPixels);
//   // Y (Luma) plane metadata
//   int idY = 0;
//   int idUV = width * height; // Start UV after Y plane
//   final uvWidth = width ~/ 2;
//   final uvHeight = height ~/ 2;
//   // Strides and pixel strides for Y and UV planes
//   final yRowStride = yPlane.bytesPerRow;
//   final yPixelStride = yPlane.bytesPerPixel ?? 1;
//   final uvRowStride = uPlane.bytesPerRow;
//   final uvPixelStride = uPlane.bytesPerPixel ?? 2;
//   // Copy Y (Luma) channel
//   for (int y = 0; y < height; ++y) {
//     final yOffset = y * yRowStride;
//     for (int x = 0; x < width; ++x) {
//       nv21[idY++] = yBuffer[yOffset + x * yPixelStride];
//     }
//   }
//   // Copy UV (Chroma) channels in NV21 format (YYYYVU interleaved)
//   for (int y = 0; y < uvHeight; ++y) {
//     final uvOffset = y * uvRowStride;
//     for (int x = 0; x < uvWidth; ++x) {
//       final bufferIndex = uvOffset + (x * uvPixelStride);
//       nv21[idUV++] = vBuffer[bufferIndex]; // V channel
//       nv21[idUV++] = uBuffer[bufferIndex]; // U channel
//     }
//   }
//   return nv21;
// }

// Uint8List yuv420ToRGBA8888(CameraImage image) {
//   final int width = image.width;
//   final int height = image.height;

//   final int uvRowStride = image.planes[1].bytesPerRow;
//   final int uvPixelStride = image.planes[1].bytesPerPixel!;

//   final int yRowStride = image.planes[0].bytesPerRow;
//   final int yPixelStride = image.planes[0].bytesPerPixel!;

//   final yBuffer = image.planes[0].bytes;
//   final uBuffer = image.planes[1].bytes;
//   final vBuffer = image.planes[2].bytes;

//   final rgbaBuffer = Uint8List(width * height * 4);

//   for (int y = 0; y < height; y++) {
//     for (int x = 0; x < width; x++) {
//       final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
//       final int index = y * width + x;

//       final yValue = yBuffer[y * yRowStride + x * yPixelStride];
//       final uValue = uBuffer[uvIndex];
//       final vValue = vBuffer[uvIndex];

//       final r = (yValue + 1.402 * (vValue - 128)).round();
//       final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round();
//       final b = (yValue + 1.772 * (uValue - 128)).round();

//       rgbaBuffer[index * 4 + 0] = r.clamp(0, 255);
//       rgbaBuffer[index * 4 + 1] = g.clamp(0, 255);
//       rgbaBuffer[index * 4 + 2] = b.clamp(0, 255);
//       rgbaBuffer[index * 4 + 3] = 255;
//     }
//   }
//   return rgbaBuffer;
// }

// Uint8List nv21ToRGBA8888(CameraImage image) {
//   final int width = image.width;
//   final int height = image.height;
//   final int frameSize = width * height;
//   final rgbaBuffer = Uint8List(frameSize * 4);

//   for (int y = 0; y < height; y++) {
//     for (int x = 0; x < width; x++) {
//       final int yIndex = y * width + x;
//       final int uvIndex = frameSize + (y >> 1) * width + (x >> 1) * 2;

//       final yValue = image.planes[0].bytes[yIndex];
//       final vValue = image.planes[2].bytes[uvIndex];
//       final uValue = image.planes[1].bytes[uvIndex + 1];

//       final r = (yValue + 1.402 * (vValue - 128)).round();
//       final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round();
//       final b = (yValue + 1.772 * (uValue - 128)).round();

//       final int index = yIndex * 4;
//       rgbaBuffer[index + 0] = r.clamp(0, 255);
//       rgbaBuffer[index + 1] = g.clamp(0, 255);
//       rgbaBuffer[index + 2] = b.clamp(0, 255);
//       rgbaBuffer[index + 3] = 255;
//     }
//   }

//   return rgbaBuffer;
// }

// Uint8List bgraToRgbaInPlace(Uint8List bgra) {
//     final out = Uint8List(bgra.length);
//     for (int i = 0; i < bgra.length; i += 4) {
//       out[i] = bgra[i + 2]; // R
//       out[i + 1] = bgra[i + 1]; // G
//       out[i + 2] = bgra[i]; // B
//       out[i + 3] = bgra[i + 3]; // A
//     }
//     return out;
//   }
