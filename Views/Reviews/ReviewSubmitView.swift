import SwiftUI

struct ReviewSubmitView: View {
    @StateObject private var viewModel: ReviewSubmitViewModel
    @Environment(\.dismiss) private var dismiss

    init(listingId: Int) {
        _viewModel = StateObject(wrappedValue: ReviewSubmitViewModel(listingId: listingId))
    }

    var body: some View {
        NavigationStack {
            if viewModel.didSubmit {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(.green)
                    Text("ধন্যবাদ!").font(.title3.bold())
                    Text("অনুমোদনের পর আপনার রিভিউ দেখানো হবে।")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("বন্ধ করুন") { dismiss() }.buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    Section("রেটিং") {
                        HStack {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= viewModel.rating ? "star.fill" : "star")
                                    .foregroundStyle(.yellow)
                                    .font(.title2)
                                    .onTapGesture { viewModel.rating = star }
                            }
                        }
                    }
                    Section("মন্তব্য (ঐচ্ছিক)") {
                        TextField("আপনার অভিজ্ঞতা লিখুন", text: $viewModel.comment, axis: .vertical)
                            .lineLimit(3...8)
                    }
                    if let error = viewModel.errorMessage {
                        Text(error).foregroundStyle(.red)
                    }
                    Button {
                        Task { await viewModel.submit() }
                    } label: {
                        if viewModel.isSubmitting { ProgressView().frame(maxWidth: .infinity) } else { Text("জমা দিন").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSubmitting)
                }
                .navigationTitle("রিভিউ দিন")
                .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
            }
        }
    }
}
