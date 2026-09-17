import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var viewModel: LoginViewModel
    @State private var showRegister = false

    init(session: SessionManager) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(session: session))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Alhoq-এ লগইন করুন")
                    .font(.title2.bold())

                // web: একটাই ফিল্ড — email অথবা phone
                VStack(alignment: .leading, spacing: 6) {
                    Text("ইমেইল অথবা ফোন নম্বর")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("email@example.com অথবা 01XXXXXXXXX", text: $viewModel.login)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("পাসওয়ার্ড")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Group {
                            if viewModel.isPasswordVisible {
                                TextField("পাসওয়ার্ড", text: $viewModel.password)
                            } else {
                                SecureField("পাসওয়ার্ড", text: $viewModel.password)
                            }
                        }
                        Button {
                            viewModel.isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: viewModel.isPasswordVisible ? "eye.slash" : "eye")
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // ⚠️ NOTE: web-এ কোনো "Forgot Password" route নেই (routes/web.php-এ নেই),
                // তাই এই বাটন এখানে যোগ করা হয়নি (Rule 15 — ZIP-এ যা নেই তা বানানো যাবে না)।
                // Android API-তে যোগ হয়ে থাকলে জানালে এখানে ঠিক করে দেব।

                Button {
                    Task { await viewModel.submit() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("লগইন করুন").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmit)

                Button("নতুন অ্যাকাউন্ট তৈরি করুন") {
                    showRegister = true
                }
                .font(.footnote)
            }
            .padding()
        }
        .sheet(isPresented: $showRegister) {
            RegisterView(session: session)
        }
    }
}
