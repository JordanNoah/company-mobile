import 'dart:convert';

Company companyFromJson(String str) => Company.fromJson(json.decode(str));

String companyToJson(Company data) => json.encode(data.toJson());

class Company {
    final int id;
    final String identificationNumber;
    final String socialReason;
    final String commercialName;
    final String mobilePhone;
    final String email;
    final String passwordHash;

    Company({
        required this.id,
        required this.identificationNumber,
        required this.socialReason,
        required this.commercialName,
        required this.mobilePhone,
        required this.email,
        required this.passwordHash
    });

    factory Company.fromJson(Map<String, dynamic> json) => Company(
        id: json["id"],
        identificationNumber: json["identificationNumber"],
        socialReason: json["socialReason"],
        commercialName: json["commercialName"],
        mobilePhone: json["mobilePhone"],
        email: json["email"],
        passwordHash: json["passwordHash"]
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "identificationNumber": identificationNumber,
        "socialReason": socialReason,
        "commercialName": commercialName,
        "mobilePhone": mobilePhone,
        "email": email,
        "passwordHash": passwordHash
    };
}
