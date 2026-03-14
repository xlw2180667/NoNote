import SwiftUI

struct DiaryPreviewCard: View {
    let date: Date
    let diaryText: String
    var mood: String? = nil
    var weather: String? = nil
    var photoURLs: [URL] = []

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: icon + date + mood
            HStack(spacing: 6) {
                Image("sheepIcon")
                    .resizable()
                    .frame(width: 22, height: 22)

                Text(dateString)
                    .font(.custom(AppFonts.bold, size: 16))
                    .foregroundColor(.textPrimary)

                if let mood = mood, SheepMood.isSheepMood(mood) {
                    SheepMoodIcon(mood: mood, size: 28)
                } else if let mood = mood {
                    Text(mood)
                        .font(.system(size: 16))
                }

                if let code = weather {
                    Image(systemName: WeatherCondition.symbolForCode(code))
                        .font(.system(size: 14))
                        .foregroundColor(WeatherCondition.colorForCode(code))
                }

                Spacer()
            }

            // Diary text
            Text(diaryText)
                .font(.custom(AppFonts.regular, size: 15))
                .foregroundColor(.textSecondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // Photo thumbnails below text
            if !photoURLs.isEmpty {
                HStack(spacing: 6) {
                    let displayCount = min(photoURLs.count, 3)
                    ForEach(0..<displayCount, id: \.self) { index in
                        if let uiImage = UIImage(contentsOfFile: photoURLs[index].path) {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .frame(height: 72)
                        }
                    }
                    if photoURLs.count > 3 {
                        Text("+\(photoURLs.count - 3)")
                            .font(.custom(AppFonts.medium, size: 13))
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    // Fill empty columns so thumbnails don't stretch full width
                    if photoURLs.count < 3 {
                        ForEach(0..<(3 - photoURLs.count), id: \.self) { _ in
                            Color.clear.frame(height: 72)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.surfaceCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
