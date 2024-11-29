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

class HomePageState extends State<HomePage> with TickerProviderStateMixin {
  //////////////////////// Vars /////////////////////
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _fpsController = TextEditingController();

  late AnimationController _rotationController;
  late AnimationController _visibilityController;
  late AnimationController _sizeController;
  late AnimationController _typingController;
  late Animation<int> _textAnimation;
  late Animation<double> _sizeAnimation;
  late int frameInterval;
  bool _isTextVisible = false;
  late IconData alertIcon = Icons.directions_car;
  late double _speed = 0;
  String objctText = "";
  DateTime thisAlrtDate = DateTime(2023, 11, 22, 14, 30, 45);
  late DateTime lastAlrtDate;
  int rotationSpeed = 5000;

  Map<String, String> msgs = {
    "vehicle": "Maintain a safe distance from vehicle ahead!",
    "pedestrian": "Pedestrian ahead, Slow down!"
  };

  ////distance ranges :
  static final List<double> midSign = [0.15, 0.85];
  static final List<double> mid35 = [0.325, 0.675];
  static final List<double> mid20 = [0.4, 0.6];
  static final List<double> mid15 = [0.425, 0.575];
  static final List<double> mid10 = [0.45, 0.55];

  //DateTime lastAlertDate = DateTime.now();
  late Future<int> cameraAndLocationState;
  String serverUrl = "";
  Uint8List? myImage;
  Map<int, Uint8List?> picsList = {};
  late CameraService _cameraService;
  late LocationService _locationService;
  String errorMsg = '';
  String alertMsg = "Maintain a safe distance from vehicle ahead!";
  int recNbr = 0;
  int sentNbr = 0;
  String stateMsg = "";
  bool isConnected = false;
  static late IOWebSocketChannel myChannel;
  late SendPort resizePort;

////////////////////////////////// Init state  //////////////////////////////////
  @override
  void initState() {
    super.initState();
    _cameraService = CameraService(this);
    _locationService = LocationService(context);
    setAllAnimations();
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
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: FutureBuilder(
        future: cameraAndLocationState,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasData && snapshot.data == 1) {
            return Center(
                child: SizedBox(
                    //color: Colors.green,
                    width: screenWidth * 0.75,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Stack(
                            children: [
                              SizedBox(
                                width: screenWidth * 0.75,
                                height: screenWidth * 0.75 * 0.5,
                                child: myImage != null
                                    ? Image.memory(
                                        myImage!,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: Colors.black,
                                      ),
                              ),
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Container(
                                    decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.8),
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(2))),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 9,
                                            height: 9,
                                            child: AnimatedBuilder(
                                              animation: _visibilityController,
                                              builder: (context, child) {
                                                return Visibility(
                                                  visible: _visibilityController
                                                          .value >
                                                      0.5,
                                                  child: child!,
                                                );
                                              },
                                              child: Container(
                                                width: 9,
                                                height: 9,
                                                decoration: BoxDecoration(
                                                  color: isConnected
                                                      ? Colors.green
                                                      : Colors.red,
                                                  // Green color
                                                  shape: BoxShape
                                                      .circle, // Circular shape
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          // Text
                                          Text(
                                            isConnected
                                                ? "Connected"
                                                : "Disconnected",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors
                                                  .white70, // Customize color as needed
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ),

                              ///////////////////////DETECTED OBJECTS
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  width: 135,
                                  height: 105,
                                  color: Colors.black12.withOpacity(0.7),
                                  child: Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text("Detected objects :",
                                              style: TextStyle(
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12.5)),
                                          Text(objctText,
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.normal,
                                                  fontSize: 10.5))
                                        ],
                                      )),
                                ),
                              ),

                              ///////////////////////////////AUDIO CIRCLE
                              Positioned(
                                bottom: 0,
                                left: 0,
                                child: AnimatedBuilder(
                                  animation: _sizeAnimation,
                                  builder: (context, child) {
                                    return SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: Center(
                                            child: GestureDetector(
                                          onTap: () {
                                            _startAlert("vehicle");
                                          },
                                          child: Container(
                                              width: _sizeAnimation.value,
                                              height: _sizeAnimation.value,
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.white.withOpacity(1),
                                                // Green color
                                                shape: BoxShape
                                                    .circle, // Circular shape
                                              )),
                                        )));
                                  },
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(1))),
                                  child: Padding(
                                    padding: const EdgeInsets.all(5),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        AnimatedBuilder(
                                          animation: _rotationController,
                                          builder: (context, child) {
                                            return Transform.rotate(
                                              angle: _rotationController.value *
                                                  2.0 *
                                                  math.pi,
                                              child: Image.asset(
                                                'assets/images/t1.png',
                                                width: 20,
                                                height: 20,
                                                color: Colors.white70,
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 5),
                                        Text(_speed.toStringAsFixed(2),
                                            style: const TextStyle(
                                                fontSize: 15,
                                                color: Colors.white70)),
                                        const Text('Km/h',
                                            style: TextStyle(
                                                fontSize: 15,
                                                color: Colors.white70)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),
                          ////////////////////////////THE ALERT LINE
                          _isTextVisible
                              ? SizedBox(
                                  height: 30,
                                  child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const SizedBox(width: 6),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              0, 0, 0, 5),
                                          child: Icon(
                                            alertIcon,
                                            size: 20,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        AnimatedBuilder(
                                            animation: _textAnimation,
                                            builder: (context, child) {
                                              String displayedText =
                                                  alertMsg.substring(
                                                      0, _textAnimation.value);
                                              return Text(displayedText,
                                                  style: const TextStyle(
                                                    fontSize: 16.5,
                                                    color: Colors.white60,
                                                    fontWeight: FontWeight.bold,
                                                  ));
                                            })
                                      ]),
                                )
                              : Container(height: 30)
                        ])));
          } else {
            return SafeArea(
              child: SingleChildScrollView(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 100),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: screenWidth * 0.5,
                            child: TextField(
                              controller: _urlController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Server URL',
                                labelStyle:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                                // Light grey label text
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.013),
                          SizedBox(
                            width: screenWidth * 0.2,
                            child: TextField(
                              controller: _fpsController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Frames interval (ms)',
                                labelStyle:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                                // Light grey label text
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      // Button with white text
                      ElevatedButton(
                        onPressed: start,
                        style: ElevatedButton.styleFrom(
                          textStyle: const TextStyle(
                              fontSize: 16, color: Colors.white),
                        ),
                        child: const Text('Start'),
                      ),
                      const SizedBox(height: 25),
                      // Error message in white text
                      SizedBox(
                        height: 200,
                        child: Text(
                          errorMsg,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
      //get the url and fps values______________________________________________
      serverUrl = _urlController.text.toString().trim();
      String interval = _fpsController.text.toString().trim();
      if (serverUrl.isEmpty || interval.isEmpty) {
        errorMsg = "Would you please fill both fields";
        return -5;
      }
      frameInterval = int.parse(_fpsController.text.toString().trim());
      //________________________________________________________________________

      //_setting up the channel_________________________________________________
      String fullServer = "ws://$serverUrl:8000/ws/predict";
      Uri srvrUrl = Uri.parse(fullServer);
      myChannel = IOWebSocketChannel.connect(srvrUrl);
      //________________________________________________________________________

      //checking locations and setting up speed updates every 2sec______________
      int speedStatus = await _locationService.setUpSpeed((speed) {
        _speed = speed;
      });
      //if anything unusual happens we
      if (speedStatus != 1) {
        errorMsg = "Location Problem";
        return -1;
      }
      //________________________________________________________________________

      //set up camera, if error return__________________________________________
      int a = await _cameraService.setUpCamera();
      if (a != 1) {
        errorMsg = "camera setup prob";
        return -2;
      }
      //________________________________________________________________________

      //setup the listenning and captureimage response each time________________
      setUpCommunicationWithServer(myChannel);
      //________________________________________________________________________

      //the pics loop___________________________________________________________
      startSendingImgs();
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
        print("ilyas - just received : $message");
        _handlingResponse(message);
      },
      onError: (error) {
        print("ilyas : server error : $error");
        setState(() {
          stateMsg = "server error : $error";
        });
      },
      onDone: () {
        print("ilyas : disconnected to server");

        /// ??????????
        setState(() {
          isConnected = false;
        });
      },
    );
  }

  ////////////////////////////////////// Start sending //////////////////////////////////////////

  startSendingImgs() async {
    while (true) {
      await Future.delayed(Duration(milliseconds: frameInterval));
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
      myImage = picsList[sentNbr]!;
      isConnected = true;

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
    setState(() {});
    //______________________________________________________
  }

  img.Image renderObjct(img.Image myNewImage, int distance, img.Color theColor,
      int xmin, int xmax, int ymin, int ymax, double x, double y) {
    try {
      //show distance on objct
      img.drawString(
          myNewImage,
          font: img.arial24,
          x: x.toInt(),
          y: y.toInt(),
          distance.toString(),
          color: img.ColorRgb8(255, 0, 0));

      //draw bounding boxes
      img.drawLine(myNewImage,
          x1: xmin, y1: ymin, x2: xmax, y2: ymin, color: theColor); // Top edge
      img.drawLine(myNewImage,
          x1: xmax, y1: ymin, x2: xmax, y2: ymax, color: theColor);
      img.drawLine(myNewImage,
          x1: xmax, y1: ymax, x2: xmin, y2: ymax, color: theColor);
      img.drawLine(myNewImage,
          x1: xmin, y1: ymax, x2: xmin, y2: ymin, color: theColor);
      print("train , all good");// Left edge
      return myNewImage;
    } catch (e) {
      print("train errro $e");
      return myNewImage;
    }
  }

  //////////////////////////////////////// renderAndShowAlert ////////////////////////////////////////////////////////

  Uint8List? renderAndAlert(List<dynamic> objects, Uint8List myImg) {
    try {
      // prepare rendering color and the img image
      late img.ColorRgb8 theColor;
      img.Image myNewImage = img.decodeImage(myImg)!;
      int width = myNewImage.width;
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

      int v = 0;
      int p = 0;
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

        // make the detectedobjct text ________________________________________
        if (className == "car") {
          v++;
        } else if (className == "person") {
          p++;
        }
        objctText = prepareobjctsText(v, p);
        //______________________________________________________________________


        // get the alert, set color and add the alert to totalAlerts___________
        List<dynamic> alert =
            AlertService.getAlert(className, x, distance, width, _speed);
        if (alert.isEmpty) {
          theColor = img.ColorRgb8(0, 128, 0);
        } else {
          theColor = img.ColorRgb8(255, 0, 0);
          totalAlerts.add(alert);
        }
        //______________________________________________________________________

        //render the detected objct on the image________________________________
        myNewImage = renderObjct(
            myNewImage, distance, theColor, xmin, xmax, ymin, ymax, x, y);
        //______________________________________________________________________

      }

      //after processing all objcts we check if we got some alerts then we get the nearest one and run its audio
      if (totalAlerts.isNotEmpty) {
        String nearestAlertCategory = totalAlerts.reduce(
            (current, next) => current[1] < next[1] ? current : next)[0];
        //if last alert was in last 4 secs we skip
        lastAlrtDate = thisAlrtDate;
        thisAlrtDate = DateTime.now();
        Duration difference = lastAlrtDate.difference(thisAlrtDate);
        if (difference.inSeconds > 4) {
          _startAlert(nearestAlertCategory);
        }
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

  ////////////////////////////////////// UPDATE ROTATION SPEED //////////////////////////////////////////////
  void _updateRotCntrl() {
    int durationInMillis =
        rotationSpeed = (20000 / (_speed + 1)).clamp(50, 3500).toInt();
    _rotationController.duration = Duration(milliseconds: durationInMillis);
    _rotationController.repeat();
    print("ilyas : rotation updated / speed : $_speed");
  }

  ////////////////////////////////////////////// RETRY //////////////////////////////////////////////////

  void start() {
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

  /////////////////////////////////////////////// Animations ///////////////////////////////////////////////////

  void setAllAnimations() {
    //tire speed rotation_________________________________________________________
    _rotationController = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: rotationSpeed), //the nbr o millisec each rotation takes
    );
    _rotationController.repeat(); // Makes the rotation continuous
    //_____________________________________________________________________

    //lightning connect light______________________________________________
    _visibilityController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    //_______________________________________________________________________

    //white circle audio size________________________________________________
    _sizeController = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 400), // Duration for one full cycle
    );

    _sizeAnimation = Tween<double>(begin: 22.5, end: 30.0).animate(
      CurvedAnimation(parent: _sizeController, curve: Curves.easeInOut),
    );
    //________________________________________________________________________

    //typed alert animation___________________________________________________
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200), // Adjust typing speed
    );

    _textAnimation = IntTween(begin: 0, end: alertMsg.length).animate(
      CurvedAnimation(parent: _typingController, curve: Curves.easeInOut),
    );
    //________________________________________________________________________
  }

// Function to start typing animation
  void _startTypingAnimation() {
    setState(() {
      _isTextVisible = true; // Show text when button is pressed
    });
    _typingController.forward(); // Start typing animation
  }

  void _hideText() {
    setState(() {
      _isTextVisible = false; // Hide text
    });
    _typingController.reset(); // Reset typing animation
  }

  void _startAlert(String nearestAlertCategory) async {
    print("alert called");
    AlertService.playAudio(nearestAlertCategory);
    //alertMsg = msgs[nearestAlertCategory]!;
    alertMsg = "Maintain a safe distance from vehicle ahead!";
    if (nearestAlertCategory == "pedestrian") {
      alertIcon = Icons.directions_walk_rounded;
    } else if (nearestAlertCategory == "car") {
      alertIcon = Icons.directions_car_filled;
    }
    _startTypingAnimation();
    _sizeController.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 1700));
    _sizeController.stop();
    _hideText();
  }

  String prepareobjctsText(int v, int p) {
    String txt = "";
    if (p != 0) {
      txt = "$p pedestrians\n";
    }
    if (v != 0) {
      txt = "$txt$v vehicles\n";
    }
    return txt;
  }

/////////////////////////////////////////////
}

/////////////////////////////////////////////// end of class /////////////////////////////////////////////////////////////
