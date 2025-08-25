class User {
  int id;
  String username;
  String? fullname;
  String? email;
  String? phone; // Make sure this is nullable
  String user_role;
  String? dob;
  bool? is_verified;
  bool? is_delete_account;
  String? created_date;
  String? modified_date;
  String? address_line; // Make sure this is nullable
  String? township; // Make sure this is nullable
  String? city; // Make sure this is nullable
  String? postal_code; // Make sure this is nullable

  User({
    required this.id,
    required this.username,
    this.fullname,
    this.email,
    this.phone,
    required this.user_role,
    this.dob,
    this.is_verified,
    this.is_delete_account,
    this.created_date,
    this.modified_date,
    this.address_line,
    this.township,
    this.city,
    this.postal_code,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      fullname: json['fullname'],
      email: json['email'],
      phone: json['phone'], // Ensure key matches JSON and type is handled
      user_role: json['user_role'],
      dob: json['dob'],
      is_verified: json['is_verified'],
      is_delete_account: json['is_delete_account'],
      created_date: json['created_date'],
      modified_date: json['modified_date'],
      address_line: json['address_line'], // Ensure key matches JSON
      township: json['township'], // Ensure key matches JSON
      city: json['city'], // Ensure key matches JSON
      postal_code: json['postal_code'], // Ensure key matches JSON
    );
  }

  // Add a toJson method if you don't have one, for saving to SharedPrefs
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'fullname': fullname,
      'email': email,
      'phone': phone,
      'user_role': user_role,
      'dob': dob,
      'is_verified': is_verified,
      'is_delete_account': is_delete_account,
      'created_date': created_date,
      'modified_date': modified_date,
      'address_line': address_line,
      'township': township,
      'city': city,
      'postal_code': postal_code,
    };
  }
}
