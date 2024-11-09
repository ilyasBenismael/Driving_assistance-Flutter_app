import 'dart:isolate';
import 'package:samaw/main.dart';
import 'package:samaw/screens/home_page.dart';
import 'package:camera/camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart'; // For `compute`

class CameraService {
  final HomePageState homePageState;

  CameraService(this.homePageState);

  ///////////
  late CameraController _cameraController;
  Timer? _timer;
  late SendPort resizeIsolateSP;
  Completer<int> setUpCompleter = Completer<int>();

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

      //an3yto hna ela setisolate function li athandli lina hadchi kaml o an awaitiw fresponse dyal complete :
      setIsolate();
      int a = await setUpCompleter.future;
      if (a != 1) {
        return -1;
      }

      //andiru sendport khariji khas b isolate dyalna

      //we spawn isolate awl haja adar fih aysendi back sendport dyalu o ansetiw listen dyalu tahuwa (img:resizing
      //error,cancel:cho achdir)

      //so hna listeners wajdin mais mazal masift walo rahum bjuj kitsnto kitsnaw

      //mli atbda takingpicsloop anakhd pic each 300ms which send it via send port t isolate
      //the isolate ra finma atjih chi haja ayresiziha o yrdha listener li aysiftha fserver
      //kant img error atskipa, kan cancel msg rah aywgfo listeners

      return 1;
    } catch (e) {
      print("Error initializing camera: $e");
      return -1;
    }
  }

/////////////////////////////////////////// COMPRESS IMAGE //////////////////////////////////////////////////////

  // Future<Uint8List?> _compressImage(XFile image) async {
  //   Uint8List? compressedImage = await FlutterImageCompress.compressWithFile(
  //     image.path,
  //     quality: 70,
  //   );
  //   return compressedImage;
  // }

////////////////////////////////////////// IMAGE CAPTURE ////////////////////////////////////////////////////

//we capture image, resize it,
  Future<void> captureImage() async {
    try {
      final image = await _cameraController.takePicture();
      Uint8List imageBytes = await image.readAsBytes();
      resizeIsolateSP.send(imageBytes);
      //onImageCaptured(resizedImg);
    } catch (e) {
      print("error in captureImage : $e");
    }
  }

  /////////////////////////////////////////////// DISPOSE ///////////////////////////////////////////////////

  void dispose() {
    _timer?.cancel();
    _cameraController.dispose();
  }

/////////////////////////////////////// MAIN ISOLATE SETUP /////////////////////////////////////////////

//anwjdo receiveport dyalna li aylisteni ayjih : ya "sendport" bach ycompleti completer b 1 o yseti, lglobal sendport ,
//ya "-1:setuperror" bach ytcancella setup, ya "img 3adia" bach yresiziha y sendiha, ya chi error  atskipa
  setIsolate() {
    final mainRV = ReceivePort();
    mainRV.listen((msg) {
      try {
        if (msg is Uint8List) {
          homePageState.sendToMychannel(msg);
        } else if (msg == -1) {
          setUpCompleter.complete(-1);
        } else if (msg is SendPort) {
          resizeIsolateSP = msg;
          setUpCompleter.complete(1);
        }
      } catch (e) {
        print("error : $e");
      }
    });
    Isolate.spawn(startIsolate, mainRV.sendPort);
  }
}

//////////////////////////////////////// END OF CLASS ///////////////////////////////////////////////////////

////////////////////////////////////////// RES ISOLATE SETUP //////////////////////////////////////////////

void startIsolate(SendPort mainSP) {
  try {
    final isoRV = ReceivePort();
    isoRV.listen((msg) async {
      try {
        if (msg is Uint8List) {
          Uint8List? result = await resize(msg, mainSP);
          mainSP.send(result);
        } else {
          print(msg);
        }
      } catch (e) {
        print("error : $e");
      }
    });
    mainSP.send(isoRV.sendPort);
  } catch (e) {
    mainSP.send(-1);
    print("error in startIsolate : $e");
  }
}

//////////////////////////////////////////////RESIZE////////////////////////////////////////////////////

Future<Uint8List?> resize(Uint8List imageData, SendPort mainSP) async {
  try {
    // turn bytes image to img image
    img.Image originalImage = img.decodeImage(imageData)!;

    // Define the maximum width and height
    const int maxWidth = 1280;
    const int maxHeight = 640;

    // Resize the image if it's larger than the max dimensions
    if (originalImage.width > maxWidth || originalImage.height > maxHeight) {
      // Resize while maintaining aspect ratio
      originalImage = img.copyResize(
        originalImage,
        width: maxWidth,
        height: maxHeight,
        interpolation: img.Interpolation.cubic,
      );
    }
    // Encode the image back to bytes
    final resImg = Uint8List.fromList(img.encodeJpg(originalImage));
    return resImg;
  } catch (e) {
    print('merror in resizeImage : ${e.toString()}');
    return null;
  }
}
