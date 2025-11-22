class User {
  final int? id;
  final String firstName;
  final String middleName;
  final String lastName;
  final String email;

  User({
    this.id, 
    required this.firstName, 
    required this.middleName, 
    required this.lastName,
    required this.email
    });

  factory User.fromJson(Map<String, dynamic> json) =>
      User(
        id: json['id'], 
        firstName: json['firstName'], 
        middleName: json['middleName'], 
        lastName: json['lastName'], 
        email: json['email']
      );

  Map<String, dynamic> toJson() => {
    "first Name": firstName, 
    "middle Name": middleName, 
    "last Name": lastName,
    "email": email};
}
