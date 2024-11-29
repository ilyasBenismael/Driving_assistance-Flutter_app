import 'package:audioplayers/audioplayers.dart';

class AlertService {
  static const pedestrianText = "Pedestrian ahead, Slow Down!";
  static const vehicleText = "Maintain safe distance from vehicle ahead!";

  static final List<String> pedestrianType = [
    "person",
    "cat",
    "dog",
    "bycicle"
  ];
  static final List<String> carType = [
    "car",
    "van",
    "truck",
    "bus",
    "motorcycle"
  ];
  static final List<String> signType = ["stop sign", "traffic light"];
  static final List<String> animalType = ["cow", "horse", "sheep"];

  ////distance ranges :
  static final List<double> midSign = [0.15, 0.85]; // middle for signs
  static final List<double> mid35 = [0.325, 0.675]; // Middle 35%
  static final List<double> mid20 = [0.4, 0.6]; // Middle 20%
  static final List<double> mid15 = [0.425, 0.575]; // Middle 15%
  static final List<double> mid10 = [0.45, 0.55]; // Middle 10%

  static final AudioPlayer audioPlayer = AudioPlayer();

//////////////////////////////////////////// ALERT METHOD ///////////////////////////////////////////////

  static List<dynamic> getAlert(
      String className, double x, int distance, int width, double speed) {
    //if we are so slow just skip, if object is more than 40m away,
    try {
      if (speed < 10 || distance > 50) {
        return [];
      }

      // if vehicle in the bloc in front of me and safety distance isn't respected !
      if ((carType.contains(className)) &&
          inCarPedBloc(distance, x, width) &&
          carDanger(distance, speed)) {
        return ["car", distance];
      } else
      // if pedestrian in the bloc in front of me, and stop distance isn't respected !
      if ((pedestrianType.contains(className)) &&
          inCarPedBloc(distance, x, width) &&
          pedestrianDanger(distance, speed)) {
        return ["pedestrian", distance];
      } else
      //   Traffic Signs
      if ((signType.contains(className)) &&
          inSignBloc(distance, x, width) &&
          signDanger(distance, speed)) {
        return ["sign", distance];
      } else {
        return [];
      }
    } catch (e) {
      print("ilyas , alert error : $e");
      return [];
    }
  }

  /////////////////////////////////////////////// InCarBloc //////////////////////////////////////////////////

  static bool inCarPedBloc(int distance, double x, int width) {
    List ourMid = [];
    //only below 45 are taken in consid
    if (distance < 13) {
      ourMid = mid35;
    } else if (distance < 25) {
      ourMid = mid20;
    } else if (distance < 35) {
      ourMid = mid15;
    } else {
      ourMid = mid10;
    }
    if (x > (width * ourMid[0]) && x < (width * ourMid[1])) {
      return true;
    }
    return false;
  }

  /////////////////////////////////////////////// InSignBloc //////////////////////////////////////////////////

  static bool inSignBloc(int distance, double x, int width) {
    //only below 45 are taken in consid
    //for the moment we use one big bloc for all distances below 45
    if (x > (width * midSign[0]) && x < (width * midSign[1])) {
      return true;
    }
    return false;
  }

  /////////////////////////////////////// carSafety ///////////////////////////////////////////////

  static bool carDanger(int actualDistance, double speed) {
    //safe distance :  Remove the last digit then * 6
    int speedFactor = (speed ~/ 10);
    int estimatedSafeDistance = speedFactor * 6;
    return actualDistance < estimatedSafeDistance;
  }

  ////////////////////////////////////// personSafety ///////////////////////////////////////////////

  static bool pedestrianDanger(int actualDistance, double speed) {
    if (actualDistance > 30) {
      return false;
    }
    int baseSpeed = speed ~/ 10;
    int estimatedSafeDistance = baseSpeed * baseSpeed;
    return actualDistance < estimatedSafeDistance;
  }

  /////////////////////////////////////// signSafety ///////////////////////////////////////////////

  static bool signDanger(int actualDistance, double speed) {
    int baseSpeed = speed ~/ 10;
    int estimatedSafeDistance = baseSpeed * baseSpeed;
    return actualDistance < estimatedSafeDistance;
  }

  ////////////////////////////////////// PLAY AUDIO ///////////////////////////////////////

  static Future<void> playAudio(String category) async {
    audioPlayer.play(AssetSource('audios/$category.mp3'));
  }

///////////////////////////////////////SHOW FINAL ALERT//////////////////////////////////////
}
