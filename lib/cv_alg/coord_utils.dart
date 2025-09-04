// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'dart:math' as math;

import 'package:opencv_core/opencv.dart' as cv;

class CoordinateDesc {
  cv.Mat rvec;
  cv.Mat tvec;
  cv.Mat R;
  CoordinateDesc({required this.rvec, required this.tvec, required this.R});

  CoordinateDesc of(CoordinateDesc coordBase) {
    // Calculate the rotation matrix of coord in coordBase's coordinate system
    cv.Mat newR = coordBase.R.t().multiplyMat(R);

    // Calculate the translation vector of coord in coordBase's coordinate system
    cv.Mat newTvec = coordBase.R.t().multiplyMat(tvec.subtract(coordBase.tvec));

    // Convert the rotation matrix to a rotation vector
    cv.Mat newRvec = cv.Rodrigues(newR);

    return CoordinateDesc(rvec: newRvec, tvec: newTvec, R: newR);
  }

  double getDistanceZ() {
    return tvec.toList()[2][0].toDouble();
  }

  double getYAngleDegree() {
    
    double thetaY = math.atan2(R.at<double>(0, 2), R.at<double>(2, 2));
    return thetaY * (180 / math.pi); // Convert radians to degrees
  }

  double getXAngleDegree() {
    double thetaX = math.atan2(-R.at<double>(1, 2), R.at<double>(2, 2));
    return thetaX * (180 / math.pi); // Convert radians to degrees
  }

  // boilerplates
  CoordinateDesc copyWith({cv.Mat? rvec, cv.Mat? tvec, cv.Mat? R}) {
    return CoordinateDesc(
      rvec: rvec ?? this.rvec,
      tvec: tvec ?? this.tvec,
      R: R ?? this.R,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'rvec': rvec.toList(),
      'tvec': tvec.toList(),
      'R': R.toList(),
    };
  }

  factory CoordinateDesc.fromMap(Map<String, dynamic> map) {
    return CoordinateDesc(
      rvec: cv.Mat.from2DList(
        map['rvec'] as List<List<double>>,
        cv.MatType.CV_32FC1,
      ),
      tvec: cv.Mat.from2DList(
        map['tvec'] as List<List<double>>,
        cv.MatType.CV_32FC1,
      ),
      R: cv.Mat.from2DList(map['R'] as List<List<double>>, cv.MatType.CV_32FC1),
    );
  }

  String toJson() => json.encode(toMap());

  factory CoordinateDesc.fromJson(String source) =>
      CoordinateDesc.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'CoordinateDesc(rvec: $rvec, tvec: $tvec, R: $R)';

  @override
  bool operator ==(covariant CoordinateDesc other) {
    if (identical(this, other)) return true;

    return other.rvec == rvec && other.tvec == tvec && other.R == R;
  }

  @override
  int get hashCode => rvec.hashCode ^ tvec.hashCode ^ R.hashCode;
}
