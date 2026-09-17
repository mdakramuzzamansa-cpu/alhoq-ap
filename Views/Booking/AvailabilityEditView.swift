import SwiftUI

struct AvailabilityEditView: View {
    @StateObject private var viewModel: AvailabilityEditViewModel

    init(listingId: Int) {
        _viewModel = StateObject(wrappedValue: AvailabilityEditViewModel(listingId: listingId))
    }

    var body: some View {
        Form {
            Section("স্লট দৈর্ঘ্য") {
                Picker("প্রতি স্লট (মিনিট)", selection: $viewModel.schedule.slotDurationMinutes) {
                    ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                        Text("\(minutes) মিনিট").tag(minutes)
                    }
                }
            }

            Section("সাপ্তাহিক শিডিউল") {
                ForEach(0..<7, id: \.self) { day in
                    dayRow(day)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red)
            }
            if let success = viewModel.successMessage {
                Text(success).foregroundStyle(.green)
            }

            Button {
                Task { await viewModel.save() }
            } label: {
                if viewModel.isSaving {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("সেভ করুন").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSaving)
        }
        .navigationTitle("বুকিং শিডিউল")
        .task { await viewModel.load() }
        .overlay {
            if viewModel.isLoading { ProgressView() }
        }
    }

    private func dayRow(_ day: Int) -> some View {
        let binding = Binding(
            get: { viewModel.schedule.days[day] ?? BookingSchedule.DaySchedule() },
            set: { viewModel.schedule.days[day] = $0 }
        )
        return VStack(alignment: .leading) {
            Toggle(BookingSchedule.weekdayLabels[day] ?? "", isOn: binding.active)
            if binding.wrappedValue.active {
                HStack {
                    TextField("শুরু (HH:mm)", text: binding.startTime)
                    TextField("শেষ (HH:mm)", text: binding.endTime)
                }
                .font(.caption)
            }
        }
    }
}
