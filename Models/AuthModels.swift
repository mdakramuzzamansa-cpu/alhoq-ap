import Foundation

// MARK: - Login
// web (Auth/AuthController@login) validation:
//   login: required|string      (email অথবা ফোন — একটাই ফিল্ড, backend filter_var দিয়ে ঠিক করে কোনটা)
//   password: required
struct LoginRequest: Encodable {
    let login: String       // email অথবা phone — placeholder/label দুটোই বলতে হবে UI-তে
    let password: String
}

struct AuthResponse: Decodable {
    let token: String       // ⚠️ ASSUMPTION: key নাম "token"। Sanctum plainTextToken সাধারণত এভাবেই আসে।
    let user: AlhoqUser
}

// MARK: - Register
// web (Auth/AuthController@register) validation — হুবহু:
//   name: required|string|max:255
//   email: nullable|required_without:phone|email|max:255|unique
//   phone: nullable|required_without:email|string|max:50|unique
//   password: required|confirmed|max:30|Password::defaults()
//   account_type: required|in:personal,business
//   company_name: nullable|required_if:account_type,business|string|max:255
//   occupation: required|string|max:255
//   city, upazila: nullable
//   latitude/longitude: nullable, but required_with each other (দুটো একসাথেই আসে GPS থেকে)
struct RegisterRequest: Encodable {
    let name: String
    let email: String?              // email অথবা phone — একটা লাগবেই, দুটোই না দিলে ফেইল
    let phone: String?
    let password: String
    let passwordConfirmation: String
    let accountType: AlhoqUser.AccountType
    let companyName: String?        // accountType == .business হলে required
    let occupation: String
    let city: String?
    let upazila: String?
    let latitude: Double?           // "Detect My Location" থেকে একসাথে আসে
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case name, email, phone, password
        case passwordConfirmation = "password_confirmation"
        case accountType = "account_type"
        case companyName = "company_name"
        case occupation, city, upazila, latitude, longitude
    }
}

/// রেজিস্ট্রেশন ফর্ম লোকালি ভ্যালিডেট করার জন্য — server ভ্যালিডেশনের হুবহু আয়না,
/// যাতে ইউজার সাবমিট করার আগেই একই এরর মেসেজ দেখতে পায় (Rule 5: "Every web validation rule must be reproduced")
enum RegisterValidation {
    static func validate(_ form: RegisterFormState) -> [String: String] {
        var errors: [String: String] = [:]

        if form.name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors["name"] = "নাম আবশ্যক।"
        }
        if form.email.isEmpty && form.phone.isEmpty {
            errors["email"] = "ইমেইল অথবা ফোন নম্বর দিন।"
        }
        if !form.email.isEmpty && !form.email.contains("@") {
            errors["email"] = "সঠিক ইমেইল দিন।"
        }
        if form.password.count < 8 {
            errors["password"] = "পাসওয়ার্ড কমপক্ষে ৮ ক্যারেক্টার হতে হবে।"
        }
        if form.password.count > 30 {
            errors["password"] = "পাসওয়ার্ড সর্বোচ্চ ৩০ ক্যারেক্টার।"
        }
        if form.password != form.passwordConfirmation {
            errors["passwordConfirmation"] = "পাসওয়ার্ড দুটো মিলছে না।"
        }
        if form.accountType == .business && form.companyName.trimmingCharacters(in: .whitespaces).isEmpty {
            errors["companyName"] = "ব্যবসা প্রতিষ্ঠানের নাম দিন।"
        }
        if form.occupation.trimmingCharacters(in: .whitespaces).isEmpty {
            errors["occupation"] = "পেশা আবশ্যক।"
        }
        return errors
    }
}

/// SwiftUI ফর্মে বাইন্ড করার জন্য plain state — RegisterRequest-এ ম্যাপ হয় submit করার সময়।
struct RegisterFormState {
    var name: String = ""
    var email: String = ""
    var phone: String = ""
    var password: String = ""
    var passwordConfirmation: String = ""
    var accountType: AlhoqUser.AccountType = .personal
    var companyName: String = ""
    var occupation: String = ""
    var city: String = ""
    var upazila: String = ""
    var latitude: Double?
    var longitude: Double?

    func toRequest() -> RegisterRequest {
        RegisterRequest(
            name: name,
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            password: password,
            passwordConfirmation: passwordConfirmation,
            accountType: accountType,
            companyName: accountType == .business ? companyName : nil,
            occupation: occupation,
            city: city.isEmpty ? nil : city,
            upazila: upazila.isEmpty ? nil : upazila,
            latitude: latitude,
            longitude: longitude
        )
    }
}
