import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel: RegisterViewModel
    @Environment(\.dismiss) private var dismiss

    init(session: SessionManager) {
        _viewModel = StateObject(wrappedValue: RegisterViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("মূল তথ্য") {
                    TextField("পূর্ণ নাম", text: $viewModel.form.name)
                    fieldError("name")

                    TextField("ইমেইল", text: $viewModel.form.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    fieldError("email")

                    TextField("ফোন নম্বর", text: $viewModel.form.phone)
                        .keyboardType(.phonePad)
                    fieldError("phone")

                    Text("ইমেইল অথবা ফোন নম্বর — অন্তত একটা দিতে হবে।")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("পাসওয়ার্ড") {
                    SecureField("পাসওয়ার্ড", text: $viewModel.form.password)
                    fieldError("password")
                    SecureField("পাসওয়ার্ড নিশ্চিত করুন", text: $viewModel.form.passwordConfirmation)
                    fieldError("passwordConfirmation")
                }

                Section("অ্যাকাউন্টের ধরন") {
                    // web: account_type required|in:personal,business
                    Picker("অ্যাকাউন্টের ধরন", selection: $viewModel.form.accountType) {
                        Text("ব্যক্তিগত").tag(AlhoqUser.AccountType.personal)
                        Text("ব্যবসায়িক").tag(AlhoqUser.AccountType.business)
                    }
                    .pickerStyle(.segmented)

                    // web: company_name required_if:account_type,business
                    if viewModel.form.accountType == .business {
                        TextField("প্রতিষ্ঠানের নাম", text: $viewModel.form.companyName)
                        fieldError("companyName")
                    }

                    TextField("পেশা", text: $viewModel.form.occupation)
                    fieldError("occupation")
                }

                Section("অবস্থান (ঐচ্ছিক)") {
                    TextField("শহর", text: $viewModel.form.city)
                    TextField("উপজেলা", text: $viewModel.form.upazila)

                    Button {
                        viewModel.detectMyLocation()
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                            Text(viewModel.isDetectingLocation ? "লোকেশন খোঁজা হচ্ছে…" : "আমার লোকেশন যোগ করুন")
                        }
                    }
                    .disabled(viewModel.isDetectingLocation)

                    if let lat = viewModel.form.latitude, let lng = viewModel.form.longitude {
                        Text("লোকেশন পাওয়া গেছে (\(lat, specifier: "%.4f"), \(lng, specifier: "%.4f"))")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                // web: duplicate email/phone সার্ভার থেকে 422 এ আসবে, ফর্মের সেই ফিল্ডের নিচে দেখাতে হবে
                ForEach(Array(viewModel.serverErrors.keys), id: \.self) { key in
                    if let messages = viewModel.serverErrors[key] {
                        Text(messages.first ?? "")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let generalError = viewModel.generalError {
                    Text(generalError).foregroundStyle(.red)
                }

                Button {
                    Task {
                        await viewModel.submit()
                        if viewModel.generalError == nil && viewModel.serverErrors.isEmpty {
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("অ্যাকাউন্ট তৈরি করুন").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }
            .navigationTitle("নতুন অ্যাকাউন্ট")
            .toolbar {
                cancelToolbarItem("বাতিল") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func fieldError(_ key: String) -> some View {
        if let message = viewModel.fieldErrors[key] {
            Text(message).font(.caption2).foregroundStyle(.red)
        }
    }
}
