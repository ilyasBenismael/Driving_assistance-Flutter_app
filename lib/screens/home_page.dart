import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import '../services/camera_service.dart';
import 'dart:convert';
import '../services/location_service.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:samaw/services/alert_service.dart';
import 'dart:isolate';
import 'dart:math' as math;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

//////////////////////////////////////// Our main class ////////////////////////////////////////////////

class HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  //////////////////////// Vars /////////////////////

  late AnimationController _rotationController;
  late double _speed = 0;
  int rotationSpeed = 5000;

  Map<String, String> msgs = {
    "vehicle": "Maintain a safe distance from vehicle ahead!",
    "pedestrian": "Slow down! pedestrian ahead!"
  };

  ////distance ranges :
  static final List<double> midSign = [0.15, 0.85]; // middle for signs
  static final List<double> mid35 = [0.325, 0.675]; // Middle 35%
  static final List<double> mid20 = [0.4, 0.6]; // Middle 20%
  static final List<double> mid15 = [0.425, 0.575]; // Middle 15%
  static final List<double> mid10 = [0.45, 0.55]; // Middle 10%

  //DateTime lastAlertDate = DateTime.now();
  late Future<int> cameraAndLocationState;
  Uint8List? myImage;
  Map<int, Uint8List?> picsList = {};
  late CameraService _cameraService;
  late LocationService _locationService;
  String errorMsg = '';
  String alertMsg = '';
  int recNbr = 0;
  int sentNbr = 0;
  String stateMsg = "";
  static late IOWebSocketChannel myChannel;
  late SendPort resizePort;

////////////////////////////////// Init state  //////////////////////////////////
  @override
  void initState() {
    super.initState();
    _cameraService = CameraService(this);
    _locationService = LocationService(context);
    //set up camera, if error return
    cameraAndLocationState = setUpEverything();
  }

//////////////////////////////// Dispose /////////////////////////////////////////////
  @override
  void dispose() {
    _cameraService.dispose();
    _rotationController.dispose();
    super.dispose();
  }

////////////////////////////////// Build /////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Safe Drive',
          style: TextStyle(color: Colors.white70),
        ),
        backgroundColor: Colors.black,
      ),
      body: FutureBuilder(
        future: cameraAndLocationState,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasData && snapshot.data == 1) {
            return Container(
              color: const Color(0xFF0E0E0E),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(width: 35),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height : 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(5, 0, 0, 5),
                            child: AnimatedBuilder(
                              animation: _rotationController,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle:
                                      _rotationController.value * 2.0 * math.pi,
                                  child: Image.asset(
                                    'assets/images/t1.png',
                                    width: 30,
                                    height: 30,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(_speed.toStringAsFixed(2),
                                  style: const TextStyle(
                                      fontSize: 23, color: Colors.white54))),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(2, 0, 0, 4),
                            child: Text('Km/h',
                                style: TextStyle(
                                    fontSize: 15, color: Colors.white54)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 420,
                        height: 210,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                          // Rounds the corners
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            // Semi-transparent border
                            width: 1,
                          ),
                        ),
                        child: myImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                // Rounds the image corners
                                child: Image.memory(
                                  myImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Container(),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Container(
                    //color: Colors.red,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 130,
                          height: 130,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 17),
                        Container(
                          height: 20,
                          width: 280,
                          alignment: Alignment.center,
                          // centers text horizontally
                          child: Text('',
                              textAlign: TextAlign.center,
                              // ensures text is centered within the text box
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                        ),
                        Container(height: 14, color: Colors.red),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Container(
              color: const Color(0xFF021E30),
              child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Text(
                      errorMsg,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: retry,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 12.0),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      child: const Text('Retry'),
                    )
                  ])),
            );
          }
        },
      ),
    );
  }

////////////////////////////////////////////// END OF BUILD ////////////////////////////////////////////////////////

///////////////////////////////////////////// SETUPEVERYTHING ////////////////////////////////////////////////////////

  Future<int> setUpEverything() async {
    try {
      //________________________________________________________________________
      //checking locations and setting up speed updates every 2sec
      int speedStatus = await _locationService.setUpSpeed((speed) {
        _speed = speed;
      });
      //if anything unusual happens we
      if (speedStatus != 1) {
        errorMsg = "Location Problem";
        return -1;
      }
      //________________________________________________________________________

      //set up camera, if error return
      //________________________________________________________________________
      int a = await _cameraService.setUpCamera();
      if (a != 1) {
        errorMsg = "camera setup prob";
        return -2;
      }
      //________________________________________________________________________

      //setting up the ch annel, using IOWebSocketChannel it's designed for non-browser apps
      //________________________________________________________________________
      myChannel =
          IOWebSocketChannel.connect('ws://d3ed-98-84-99-74.ngrok-free.app/ws/predict');
      //________________________________________________________________________

      // Set up the AnimationController to rotate 3 times per second
      //________________________________________________________________________
      _rotationController = AnimationController(
        vsync: this,
        duration: Duration(
            milliseconds:
                rotationSpeed), //the nbr o millisec each rotation takes
      )..repeat(); // Makes the rotation continuous
      //________________________________________________________________________

      //setup the listenning and captureimage response each time
      //________________________________________________________________________
      setUpCommunicationWithServer(myChannel);
      //________________________________________________________________________

      //takingPicsLoop();
      //________________________________________________________________________
      //_cameraService.captureImage();
      startSending();
      //________________________________________________________________________

      //if all good we return 1
      return 1;
    } catch (e) {
      print("main error : $e");
      errorMsg = "error : ${e.toString()}";
      return -3;
    }
  }

///////////////////////////////// setUpCommunicationWithServer ////////////////////////////////////////////////

  void setUpCommunicationWithServer(IOWebSocketChannel myChannel) {
    //whenever I get the rendered image from server, we show it and send back a new one,
    //if error or disconnection we show the msg
    myChannel.stream.listen(
      (message) {
        _handlingResponse(message);
      },
      onError: (error) {
        print("server error : $error");
        setState(() {
          stateMsg = "server error : $error";
        });
      },
      onDone: () {
        print("disconnected to server");
        setState(() {
          stateMsg = "Disconnected to server";
        });
      },
    );
  }

  /////////////////////////////////////// TAKING PICS LOOP ///////////////////////////////////////////////////
  Future<void> takingPicsLoop(//IOWebSocketChannel midasChannel
      ) async {
    while (true) {
      await _cameraService.captureImage();
    }
  }

  ////////////////////////////////////// SEND TO MYCHANNEL //////////////////////////////////////////////

  void sendToMychannel(Uint8List img) async {
    myChannel.sink.add(img);
    sentNbr++;
    picsList[sentNbr] = img;
    print("ilyas : just sent img ${DateTime.now()}");
  }

  /////////////////////////////////// HANDLING RESPONSE //////////////////////////////////////////////
  void _handlingResponse(dynamic message) {
    try {
      recNbr++;
      //print("ilyas : got resp : $recNbr : $message");
      alertMsg = "";
      myImage = picsList[sentNbr]!;

      //taking next pic
      ////______________________________________________________
      //_cameraService.captureImage();
      ////______________________________________________________

      //prepare objcts from response
      //______________________________________________________
      Map<String, dynamic> jsonResponse = {};
      jsonResponse = jsonDecode(message);
      List<dynamic> objects = jsonResponse['objects'];
      //______________________________________________________

      //get rendered img and update alert msg
      //______________________________________________________
      myImage = renderAndAlert(objects, picsList[recNbr]!);
      //______________________________________________________

      //update animation
      //______________________________________________________
      _updateRotCntrl();
      //______________________________________________________
    } catch (e) {
      print("error : e");
    }

    //in all cases i need to remove the img from piclist nd show the state msg
    //______________________________________________________
    picsList.remove(recNbr);
    // stateMsg = "Frame : $recNbr \n $alertMsg";
    setState(() {});
    //______________________________________________________
  }

  /////////////////////////////////////////// renderAndShowAlert ////////////////////////////////////////////////////////

  Uint8List? renderAndAlert(List<dynamic> objects, Uint8List myImg) {
    try {
      // prepare rendering color and the img image
      late img.ColorRgb8 theColor;
      img.Image myNewImage = img.decodeImage(myImg)!;
      int width = myNewImage.width;
      int height = myNewImage.height;
      List<List<dynamic>> totalAlerts = [];

      //*******************************************************************************

      // ///// Colors
      // img.Color greenColor = img.ColorRgb8(0, 255, 0); // Green
      // img.Color redColor = img.ColorRgb8(255, 0, 0); // Red
      // img.Color blueColor = img.ColorRgb8(0, 0, 255); // Blue
      // img.Color blackColor = img.ColorRgb8(0, 0, 0); // Black
      // img.Color whiteColor = img.ColorRgb8(255, 255, 255); // White
      //
      // ///////Getting points
      //
      // //white : midSign
      // int x1White = (width * midSign[0]).toInt();
      // int x2White = (width * midSign[1]).toInt();
      //
      // //green : mid25
      // int x1Green = (width * mid35[0]).toInt();
      // int x2Green = (width * mid35[1]).toInt();
      //
      // //red : mid20
      // int x1Red = (width * mid20[0]).toInt();
      // int x2Red = (width * mid20[1]).toInt();
      //
      // //blue : mid15
      // int x1Blue = (width * mid15[0]).toInt();
      // int x2Blue = (width * mid15[1]).toInt();
      //
      // //black : mid10
      // int x1Black = (width * mid10[0]).toInt();
      // int x2Black = (width * mid10[1]).toInt();
      //
      // ///////////////////////Drawing lines :
      // //White Lines
      // myNewImage = img.drawLine(myNewImage,
      //     x1: x1White, y1: 1, x2: x1White, y2: height - 1, color: whiteColor);
      // myNewImage = img.drawLine(myNewImage,
      //     x1: x2White, y1: 1, x2: x2White, y2: height - 1, color: whiteColor);
      //
      // //Green lines
      // myNewImage = img.drawLine(myNewImage,
      //     x1: x1Green, y1: 1, x2: x1Green, y2: height - 1, color: greenColor);
      // myNewImage = img.drawLine(myNewImage,
      //     x1: x2Green, y1: 1, x2: x2Green, y2: height - 1, color: greenColor);
      //
      // //Red lines
      // myNewImage = img.drawLine(myNewImage,
      //     x1: x1Red, y1: 1, x2: x1Red, y2: height - 1, color: redColor);
      // myNewImage = img.drawLine(myNewImage,
      //     x1: x2Red, y1: 1, x2: x2Red, y2: height - 1, color: redColor);
      //
      // //Blue lines
      // myNewImage = img.drawLine(myNewImage,
      //     x1: x1Blue, y1: 1, x2: x1Blue, y2: height - 1, color: blueColor);
      // myNewImage = img.drawLine(myNewImage,
      //     x1: x2Blue, y1: 1, x2: x2Blue, y2: height - 1, color: blueColor);
      //
      // //Black lines
      // myNewImage = img.drawLine(myNewImage,
      //     x1: x1Black, y1: 1, x2: x1Black, y2: height - 1, color: blackColor);
      // myNewImage = img.drawLine(myNewImage,
      //     x1: x2Black, y1: 1, x2: x2Black, y2: height - 1, color: blackColor);

      //*******************************************************************************

      for (var obj in objects) {
        // for each objct we get the infos
        //_____________________________________________________________________
        String className = obj['class'];
        int xmin = obj['features']['xmin'].toInt();
        int ymin = obj['features']['ymin'].toInt();
        int xmax = obj['features']['xmax'].toInt();
        int ymax = obj['features']['ymax'].toInt();
        int distance = obj['distance_estimated'].toInt();
        double x = (xmin + ((xmax - xmin) / 2));
        double y = (ymin + ((ymax - ymin) / 2));
        //_____________________________________________________________________

        // get the alert, set color and add the alert to totalAlerts
        //_____________________________________________________________________
        List<dynamic> alert =
            AlertService.getAlert(className, x, distance, width, _speed);
        if (alert.isEmpty) {
          theColor = img.ColorRgb8(0, 128, 0);
        } else {
          theColor = img.ColorRgb8(255, 0, 0);
          totalAlerts.add(alert);
        }
        //_____________________________________________________________________

        //show infos on the objct
        //____________________________________________________________________
        img.drawString(
            myNewImage,
            font: img.arial24,
            x: x.toInt(),
            y: y.toInt(),
            "$distance",
            color: img.ColorRgb8(255, 0, 0));
        //____________________________________________________________________

        //draw bounding boxes
        //____________________________________________________________________
        img.drawLine(myNewImage,
            x1: xmin,
            y1: ymin,
            x2: xmax,
            y2: ymin,
            color: theColor); // Top edge
        img.drawLine(myNewImage,
            x1: xmax,
            y1: ymin,
            x2: xmax,
            y2: ymax,
            color: theColor); // Right edge
        img.drawLine(myNewImage,
            x1: xmax,
            y1: ymax,
            x2: xmin,
            y2: ymax,
            color: theColor); // Bottom edge
        img.drawLine(myNewImage,
            x1: xmin,
            y1: ymax,
            x2: xmin,
            y2: ymin,
            color: theColor); // Left edge
        //____________________________________________________________________
      }

      //after processing all objcts we check if we got some alerts then we get the nearest one and run its audio
      if (totalAlerts.isNotEmpty) {
        String nearestAlertCategory = totalAlerts.reduce(
            (current, next) => current[1] < next[1] ? current : next)[0];
        AlertService.playAudio(nearestAlertCategory);
        alertMsg = msgs[nearestAlertCategory]!;
        //make animation
      }

      // return the final image
      //____________________________________________________________________
      Uint8List renderedImg = Uint8List.fromList(img.encodeJpg(myNewImage));
      return renderedImg;
      //____________________________________________________________________
    } catch (e) {
      print("error in renderImg : $e");
      return myImg;
    }
  }


  ////////////////////////////////////// Start sending //////////////////////////////////////////


   startSending() async {
    while(true){
        await Future.delayed(const Duration(milliseconds: 70));
       _cameraService.captureImage();
    }
  }


  ////////////////////////////////////// UPDATE ROTATION SPEED //////////////////////////////////////////////
  void _updateRotCntrl() {
    int durationInMillis =
        rotationSpeed = (20000 / (_speed + 1)).clamp(50, 3500).toInt();
    _rotationController.duration = Duration(milliseconds: durationInMillis);
    _rotationController.repeat();
    print("ilyas : rotation updated / speed : $_speed");
  }

  ////////////////////////////////////////////// RETRY //////////////////////////////////////////////////

  void retry() {
    cameraAndLocationState = setUpEverything();
    setState(() {});
  }

  /////////////////////////////////////////////// RESET ///////////////////////////////////////////////////

  void reset() {
    _cameraService.dispose();
    //???cancel location stream
    //???cancel channel stream and close connection
    stateMsg = '__';
    errorMsg = "";
  }
}

/////////////////////////////////////////////// end of class /////////////////////////////////////////////////////////////
