import SwiftUI

struct DiaryEditorView: View {
    let date: Date
    @ObservedObject var cloudKit: CloudKitService
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var titleString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy EEEE"
        return formatter.string(from: date)
    }

    var body: some View {
        ZStack {
            TextEditor(text: $text)
                .font(.custom("Roboto-Regular", size: 16))
                .foregroundColor(.noDiaryBlack)
                .padding()

            if isLoading {
                LoadingOverlay()
            }
        }
        .navigationTitle(titleString)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: save) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.noDiaryGreen)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: deleteDiary) {
                    Text(String(localized: "#delete"))
                        .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            text = cloudKit.diaryText(for: date)
        }
        .alert(String(localized: "#oops"), isPresented: $showError) {
            Button(String(localized: "#ok"), role: .cancel) { dismiss() }
            Button(String(localized: "#dontShowAlert")) {
                UserDefaults.standard.set(true, forKey: "dontShowAlert")
                dismiss()
            }
        } message: {
            Text(errorMessage)
        }
    }

    private func save() {
        guard !text.isEmpty else {
            dismiss()
            return
        }
        isLoading = true
        Task {
            do {
                try await cloudKit.saveDiary(text: text, date: date)
                dismiss()
            } catch {
                isLoading = false
                if !UserDefaults.standard.bool(forKey: "dontShowAlert") {
                    errorMessage = String(localized: "#saveToICloundError")
                    showError = true
                } else {
                    dismiss()
                }
            }
        }
    }

    private func deleteDiary() {
        guard !text.isEmpty else {
            dismiss()
            return
        }
        isLoading = true
        Task {
            do {
                try await cloudKit.deleteDiary(date: date)
                dismiss()
            } catch {
                isLoading = false
                dismiss()
            }
        }
    }
}
