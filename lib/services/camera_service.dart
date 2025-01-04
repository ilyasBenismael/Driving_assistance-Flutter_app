import 'dart:isolate';
import 'package:samaw/screens/home_page.dart';
import 'package:camera/camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // For `compute`

class CameraService {
  final HomePageState homePageState;

  CameraService(this.homePageState);

  ///////////
  late CameraController _cameraController;
  Timer? _timer;

  //late SendPort resizeIsolateSP;
  //Completer<int> setUpCompleter = Completer<int>();

  ////////////////////////////////////////// SETUP CAMERA ////////////////////////////////////////////////////

  //return 1 only if setup is good
  Future<int> setUpCamera() async {
    try {
      //get available cameras and choose the rear camera
      final cameras = await availableCameras();
      final rearCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      //make the camera controller and initialize it
      _cameraController = CameraController(
        rearCamera,
        ResolutionPreset.medium,
      );
      await _cameraController.initialize();
      await _cameraController.setFlashMode(FlashMode.off);

      ////an3yto hna ela setisolate function li athandli lina hadchi kaml o an awaitiw fresponse dyal complete :
      // setIsolate();
      // int a = await setUpCompleter.future;
      // if (a != 1) {
      //   return -1;
      // }
      return 1;
    } catch (e) {
      print("Error initializing camera: $e");
      return -1;
    }
  }

////////////////////////////////////////// IMAGE CAPTURE ////////////////////////////////////////////////////

//we capture image, compress it and resize it,
  Future<void> captureImage() async {
    try {
      final image = await _cameraController.takePicture();
      print("ilyas - 2- after taking pic : ${DateTime.now()}");
      Uint8List? compressImage = await _compressImage(image);
      print("ilyas - 3- after compressing : ${DateTime.now()}");
      Uint8List? finalImgBytes = await cropImg(compressImage!);
      print("ilyas - 4- after cropping : ${DateTime.now()}");
      homePageState.sendToMychannel(finalImgBytes!);

      ///u might need those
      //resizeIsolateSP.send(compressImage);
      //Uint8List imageBytes = await image.readAsBytes();
    } catch (e) {
      print("error in captureImage : $e");
    }
  }

/////////////////////////////////////////// COMPRESS IMAGE //////////////////////////////////////////////////////

  Future<Uint8List?> _compressImage(XFile image) async {
    Uint8List? compressedImage = await FlutterImageCompress.compressWithFile(
      image.path,
      quality: 50,
    );
    return compressedImage;
  }

//////////////////////////////////////////// CropImg ////////////////////////////////////////////////////

  Future<Uint8List?> cropImg(Uint8List imageData
      //, SendPort mainSP
      ) async {
    try {
      // Decode the image data into an image object
      img.Image originalImage = img.decodeImage(imageData)!;

      print(
          "frist width : ${originalImage.width} // first height : ${originalImage.height}");

      // Define the maximum width and height
      const int maxWidth = 1280;
      const int maxHeight = 640;

      // Check if the image size exceeds the max dimensions
      if (originalImage.width > maxWidth || originalImage.height > maxHeight) {
        // Calculate the new width and height for cropping
        int newWidth = originalImage.width;
        int newHeight = originalImage.height;

        // If the width is larger than maxWidth, crop it
        if (newWidth > maxWidth) {
          newWidth = maxWidth;
        }
        // If the height is larger than maxHeight, crop it
        if (newHeight > maxHeight) {
          newHeight = maxHeight;
        }

        // Calculate the crop position (top-left corner of the crop box)
        int xOffset =
            (originalImage.width - newWidth) ~/ 2; // Center crop horizontally
        int yOffset =
            (originalImage.height - newHeight) ~/ 2; // Center crop vertically

        // Crop the image based on calculated offset and new dimensions
        originalImage = img.copyCrop(originalImage,
            x: xOffset, y: yOffset, width: newWidth, height: newHeight);
      }
      print(
          "after width : ${originalImage.width} // after height : ${originalImage.height}");

      // Encode the cropped image back to bytes
      final croppedImageBytes =
          Uint8List.fromList(img.encodeJpg(originalImage));
      return croppedImageBytes;
    } catch (e) {
      print('Error while cropping image: ${e.toString()}');
      return null;
    }
  }

/////////////////////////////////////////////// DISPOSE ///////////////////////////////////////////////////

  void dispose() {
    _timer?.cancel();
    _cameraController.dispose();
  }
}
//////////////////////////////////////// END OF CLASS ///////////////////////////////////////////////////////

///////////////////////////////////// MAIN ISOLATE SETUP /////////////////////////////////////////////

// //anwjdo receiveport dyalna li aylisteni ayjih : ya "sendport" bach ycompleti completer b 1 o yseti, lglobal sendport ,
// //ya "-1:setuperror" bach ytcancella setup, ya "img 3adia" bach yresiziha y sendiha, ya chi error  atskipa
//   setIsolate() {
//     final mainRV = ReceivePort();
//     mainRV.listen((msg) {
//       try {
//         if (msg is Uint8List) {
//           homePageState.sendToMychannel(msg);
//         } else if (msg == -1) {
//           setUpCompleter.complete(-1);
//         } else if (msg is SendPort) {
//           resizeIsolateSP = msg;
//           setUpCompleter.complete(1);
//         }
//       } catch (e) {
//         print("error : $e");
//       }
//     });
//     Isolate.spawn(startIsolate, mainRV.sendPort);
//   }

// end of class

// ////////////////////////////////////////// RES ISOLATE SETUP //////////////////////////////////////////////
//
// void startIsolate(SendPort mainSP) {
//   try {
//     final isoRV = ReceivePort();
//     isoRV.listen((msg) async {
//       try {
//         if (msg is Uint8List) {
//           print("ilyas - 4 - before resizing : ${DateTime.now()}");
//           Uint8List? result = await resize(msg, mainSP);
//           print("ilyas - 5 - after resizing : ${DateTime.now()}");
//           mainSP.send(result);
//         } else {
//           print(msg);
//         }
//       } catch (e) {
//         print("error : $e");
//       }
//     });
//     mainSP.send(isoRV.sendPort);
//   } catch (e) {
//     mainSP.send(-1);
//     print("error in startIsolate : $e");
//   }
// }
//
