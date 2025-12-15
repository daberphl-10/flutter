class User {
  final int? id;
  final String firstName;
  final String middleName;
  final String lastName;
  final String email;
  final String? role; // 'farmer' or 'admin'

  User({
    this.id, 
    required this.firstName, 
    required this.middleName, 
    required this.lastName,
    required this.email,
    this.role,
    });

  factory User.fromJson(Map<String, dynamic> json) =>
      User(
        id: json['id'], 
        firstName: json['firstName'] ?? json['firstname'] ?? '', 
        middleName: json['middleName'] ?? json['middlename'] ?? '', 
        lastName: json['lastName'] ?? json['lastname'] ?? '', 
        email: json['email'] ?? '',
        role: json['role'],
      );

  Map<String, dynamic> toJson() => {
    "firstname": firstName, 
    "middlename": middleName, 
    "lastname": lastName,
    "email": email,
    "role": role,
  };
  
  bool get isAdmin => role == 'admin';
  bool get isFarmer => role == 'farmer';
}
