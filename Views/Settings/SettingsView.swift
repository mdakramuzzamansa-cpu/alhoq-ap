import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var callsEnabled: Bool
    @Published var smsEnabled: Bool
    @Published var chatEnabled: Bool
    @Published var payoutMethod: String
    @Published var payoutAccount: String
    @Published var newPassword = ""
    @Published var newPasswordConfirmation = ""
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let api: SettingsAPIProtocol = SettingsAPI()

    init(user: AlhoqUser) {
        callsEnabled = user.callsEnabled
        smsEnabled = user.smsEnabled
        chatEnabled = user.chatEnabled
        payoutMethod = user.payoutMethod ?? "bkash"
        payoutAccount = user.payoutAccount ?? ""
    }

    func save() async {
        errorMessage = nil
        successMessage = nil
        if !newPassword.isEmpty && newPassword != newPasswordConfirmation {
            errorMessage = "নতুন পাসওয়ার্ড দুটো মিলছে না।"
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await api.updateSettings(UpdateSettingsRequest(
                callsEnabled: callsEnabled, smsEnabled: smsEnabled, chatEnabled: chatEnabled,
                payoutMethod: payoutMethod, payoutAccount: payoutAccount.isEmpty ? nil : payoutAccount,
                password: newPassword.isEmpty ? nil : newPassword,
                passwordConfirmation: newPassword.isEmpty ? nil : newPasswordConfirmation
            ))
            successMessage = "সেটিংস আপডেট হয়েছে।"
            newPassword = ""; newPasswordConfirmation = ""
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "সেভ করা যায়নি।"
        }
    }
}

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(user: AlhoqUser) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(user: user))
    }

    var body: some View {
        Form {
            Section("যোগাযোগ ও গোপনীয়তা") {
                Toggle("কল করার অনুমতি দিন", isOn: $viewModel.callsEnabled)
                Toggle("SMS নোটিফিকেশন", isOn: $viewModel.smsEnabled)
                Toggle("চ্যাট করার অনুমতি দিন", isOn: $viewModel.chatEnabled)
            }

            Section("পেআউট তথ্য") {
                Picker("মাধ্যম", selection: $viewModel.payoutMethod) {
                    Text("bKash").tag("bkash")
                    Text("Nagad").tag("nagad")
                    Text("Rocket").tag("rocket")
                    Text("ব্যাংক ট্রান্সফার").tag("bank_transfer")
                }
                TextField("অ্যাকাউন্ট নম্বর", text: $viewModel.payoutAccount)
            }

            Section("পাসওয়ার্ড বদলান") {
                SecureField("নতুন পাসওয়ার্ড", text: $viewModel.newPassword)
                SecureField("নিশ্চিত করুন", text: $viewModel.newPasswordConfirmation)
            }

            if let error = viewModel.errorMessage { Text(error).foregroundStyle(.red) }
            if let success = viewModel.successMessage { Text(success).foregroundStyle(.green) }

            Button {
                Task { await viewModel.save() }
            } label: {
                if viewModel.isSaving { ProgressView().frame(maxWidth: .infinity) } else { Text("সেভ করুন").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSaving)
        }
        .navigationTitle("সেটিংস")
    }
}
