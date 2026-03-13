import SwiftUI

struct ReminderSettingsView: View {
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 21
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @State private var showPermissionDenied = false
    @State private var selectedTime = Date()

    var body: some View {
        List {
            Section {
                Toggle(String(localized: "#reminderEnabled"), isOn: $reminderEnabled)
                    .font(.custom(AppFonts.regular, size: 16))
                    .foregroundColor(.textPrimary)
                    .tint(.accent)
                    .onChange(of: reminderEnabled) { enabled in
                        if enabled {
                            enableReminder()
                        } else {
                            NotificationService.cancelAll()
                        }
                    }

                if reminderEnabled {
                    DatePicker(
                        String(localized: "#reminderTime"),
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .font(.custom(AppFonts.regular, size: 16))
                    .foregroundColor(.textPrimary)
                    .onChange(of: selectedTime) { newTime in
                        let cal = Calendar.current
                        reminderHour = cal.component(.hour, from: newTime)
                        reminderMinute = cal.component(.minute, from: newTime)
                        NotificationService.scheduleDaily(hour: reminderHour, minute: reminderMinute)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.surface)
        .navigationTitle(String(localized: "#dailyReminder"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            var components = DateComponents()
            components.hour = reminderHour
            components.minute = reminderMinute
            selectedTime = Calendar.current.date(from: components) ?? Date()
        }
        .alert(String(localized: "#oops"), isPresented: $showPermissionDenied) {
            Button(String(localized: "#ok"), role: .cancel) {
                reminderEnabled = false
            }
        } message: {
            Text(String(localized: "#notificationPermissionDenied"))
        }
    }

    private func enableReminder() {
        Task {
            let granted = await NotificationService.requestPermission()
            if granted {
                NotificationService.scheduleDaily(hour: reminderHour, minute: reminderMinute)
            } else {
                showPermissionDenied = true
            }
        }
    }
}
