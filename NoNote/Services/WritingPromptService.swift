import Foundation

enum WritingPromptService {
    static let prompts: [(en: String, zh: String)] = [
        ("What made you smile today?", "今天什么事让你微笑了？"),
        ("Describe a moment you felt grateful for.", "描述一个让你感到感激的时刻。"),
        ("What's something new you learned recently?", "你最近学到了什么新东西？"),
        ("Write about a person who made your day better.", "写写一个让你今天变得更好的人。"),
        ("What would you tell your future self?", "你想对未来的自己说什么？"),
        ("Describe the weather and how it made you feel.", "描述一下今天的天气和它带给你的感受。"),
        ("What's a small victory you had today?", "今天你取得了什么小胜利？"),
        ("Write about something you're looking forward to.", "写写你期待的事情。"),
        ("What's on your mind right now?", "你现在在想什么？"),
        ("Describe your favorite moment of the day.", "描述今天你最喜欢的时刻。"),
        ("What challenge did you face today?", "你今天面对了什么挑战？"),
        ("Write about a place you'd like to visit.", "写写一个你想去的地方。"),
        ("What made today different from yesterday?", "今天和昨天有什么不同？"),
        ("Describe something beautiful you noticed.", "描述你注意到的美好事物。"),
        ("What's a habit you'd like to build?", "你想养成什么习惯？"),
        ("Write about someone you miss.", "写写一个你想念的人。"),
        ("What was the best thing you ate today?", "今天你吃过最好吃的是什么？"),
        ("Describe how you're feeling in three words.", "用三个词描述你现在的感受。"),
        ("What's a book, movie, or song on your mind?", "你脑海中有什么书、电影或歌曲？"),
        ("Write about a goal you're working toward.", "写写你正在努力实现的目标。"),
        ("What would make tomorrow great?", "什么能让明天变得很棒？"),
        ("Describe a conversation that stuck with you.", "描述一次让你印象深刻的对话。"),
        ("What's something you're proud of?", "你为什么感到自豪？"),
        ("Write about your morning routine today.", "写写你今天早上的日常。"),
        ("What's a kind thing someone did for you?", "有人为你做过什么善意的事？"),
        ("Describe the sounds around you right now.", "描述你现在周围的声音。"),
        ("What lesson did today teach you?", "今天教会了你什么？"),
        ("Write about something that made you laugh.", "写写让你笑的事情。"),
        ("What are you thankful for this week?", "这周你感激什么？"),
        ("If today were a color, what would it be and why?", "如果今天是一种颜色，会是什么？为什么？"),
    ]

    static func promptForDate(_ date: Date) -> String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = (dayOfYear - 1) % prompts.count
        let prompt = prompts[index]
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return lang == "zh" ? prompt.zh : prompt.en
    }
}
