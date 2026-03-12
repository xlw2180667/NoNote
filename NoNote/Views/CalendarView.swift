import SwiftUI

struct CalendarView: View {
    @StateObject private var cloudKit = CloudKitService()
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var showEditor = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            CalendarGridView(
                displayedMonth: $displayedMonth,
                selectedDate: $selectedDate,
                diaryDates: cloudKit.diaryDates
            )

            Spacer()

            HStack(spacing: 20) {
                Button(action: {
                    displayedMonth = Date()
                    selectedDate = Date()
                }) {
                    Text(String(localized: "#now"))
                        .font(.custom("Roboto-Medium", size: 17))
                        .foregroundColor(.noDiaryGreen)
                        .frame(width: 120, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.noDiaryGreen, lineWidth: 2)
                        )
                }

                Button(action: {
                    showEditor = true
                }) {
                    Text(String(localized: "#write"))
                        .font(.custom("Roboto-Medium", size: 17))
                        .foregroundColor(.white)
                        .frame(width: 120, height: 56)
                        .background(Color.noDiaryGreen)
                        .cornerRadius(28)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showEditor) {
            DiaryEditorView(date: selectedDate, cloudKit: cloudKit)
        }
        .task {
            await fetchCurrentMonth()
        }
        .onChange(of: displayedMonth) { _ in
            Task { await fetchDisplayedMonth() }
        }
        .alert(String(localized: "#oops"), isPresented: $showError) {
            Button(String(localized: "#ok"), role: .cancel) {}
            Button(String(localized: "#dontShowAlert")) {
                UserDefaults.standard.set(true, forKey: "dontShowAlert")
            }
        } message: {
            Text(errorMessage)
        }
    }

    private func fetchCurrentMonth() async {
        let cal = Calendar.current
        let month = cal.component(.month, from: Date())
        let year = cal.component(.year, from: Date())
        await fetchMonth(monthAndYear: "\(month)-\(year)")
    }

    private func fetchDisplayedMonth() async {
        let cal = Calendar.current
        let month = cal.component(.month, from: displayedMonth)
        let year = cal.component(.year, from: displayedMonth)
        await fetchMonth(monthAndYear: "\(month)-\(year)")
    }

    private func fetchMonth(monthAndYear: String) async {
        do {
            try await cloudKit.fetchDiaries(monthAndYear: monthAndYear)
        } catch {
            if !UserDefaults.standard.bool(forKey: "dontShowAlert") {
                errorMessage = String(localized: "#cannotConnectToICloud")
                showError = true
            }
        }
    }
}
