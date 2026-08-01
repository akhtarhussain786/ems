class AttendanceModel {
  final int? id;
  final int? employeeId;
  final String attendanceDate;
  final String? checkIn;
  final String? checkOut;
  final String? checkInPhoto;
  final String? checkOutPhoto;
  final double? latitude;
  final double? longitude;
  final String? address;
  final double? distance;
  final int? lateMinutes;
  final String? workingHours;
  final String? overtime;
  final String status;
  final String? remarks;

  AttendanceModel({
    this.id,
    this.employeeId,
    required this.attendanceDate,
    this.checkIn,
    this.checkOut,
    this.checkInPhoto,
    this.checkOutPhoto,
    this.latitude,
    this.longitude,
    this.address,
    this.distance,
    this.lateMinutes,
    this.workingHours,
    this.overtime,
    this.status = 'present',
    this.remarks,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'],
      employeeId: json['employee_id'],
      attendanceDate: json['attendance_date'] ?? '',
      checkIn: json['check_in'],
      checkOut: json['check_out'],
      checkInPhoto: json['check_in_photo'],
      checkOutPhoto: json['check_out_photo'],
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      address: json['address'],
      distance: json['distance'] != null ? double.tryParse(json['distance'].toString()) : null,
      lateMinutes: json['late_minutes'] != null ? int.tryParse(json['late_minutes'].toString()) : null,
      workingHours: json['working_hours'],
      overtime: json['overtime'],
      status: json['status'] ?? 'present',
      remarks: json['remarks'],
    );
  }
}
