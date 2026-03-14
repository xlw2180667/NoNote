import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Photo Item

private struct PhotoItem: Identifiable, Equatable {
    let id = UUID()
    let thumbnail: UIImage    // small (~300px), for grid display
    var sourceURL: URL?       // non-nil for existing photos (full-res on disk)
    var fullImage: UIImage?   // non-nil for newly picked photos

    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Drop Delegate

private struct PhotoDropDelegate: DropDelegate {
    let item: PhotoItem
    @Binding var items: [PhotoItem]
    @Binding var draggingItem: PhotoItem?

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem,
              dragging.id != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == dragging.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id })
        else { return }

        withAnimation(.default) {
            items.move(fromOffsets: IndexSet(integer: fromIndex),
                       toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Editor View

struct DiaryEditorView: View {
    let date: Date
    @ObservedObject var cloudKit: CloudKitService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var text: String = ""
    @State private var mood: String? = nil
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false
    @FocusState private var isEditorFocused: Bool

    // Multi-photo state
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var photoItems: [PhotoItem] = []
    @State private var draggingItem: PhotoItem? = nil
    @State private var fullScreenPhoto: FullScreenPhoto? = nil
    @State private var isLoadingPhotos = false

    // Track original state to detect changes
    @State private var weather: String? = nil
    @State private var originalText: String = ""
    @State private var originalMood: String? = nil
    @State private var originalWeather: String? = nil
    @State private var originalPhotoURLs: [URL] = []
    @AppStorage("writingPromptsEnabled") private var promptsEnabled = true

    private var hasExistingEntry: Bool {
        !originalText.isEmpty
    }

    private var hasChanges: Bool {
        if text != originalText || mood != originalMood || weather != originalWeather { return true }
        if isLoadingPhotos { return false }
        if photoItems.contains(where: { $0.sourceURL == nil }) { return true }
        let currentURLs = photoItems.compactMap(\.sourceURL)
        return currentURLs != originalPhotoURLs
    }

    private var titleString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    private let photoGridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ZStack {
            Color.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                // Mood picker
                MoodPickerRow(selectedMood: $mood)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Weather picker
                WeatherPickerRow(selectedWeather: $weather)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                // Text editor with prompt overlay
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.custom(AppFonts.regular, size: 16))
                        .foregroundColor(.textPrimary)
                        .scrollContentBackground(.hidden)
                        .focused($isEditorFocused)

                    if text.isEmpty && !hasExistingEntry && promptsEnabled {
                        Text(WritingPromptService.promptForDate(date))
                            .font(.custom(AppFonts.regular, size: 16))
                            .foregroundColor(.textSecondary.opacity(0.5))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .padding()

                // Photo section
                photoSection

                // Character count
                HStack {
                    Spacer()
                    Text(String(localized: "#characterCount\(text.count)"))
                        .font(.custom(AppFonts.regular, size: 12))
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }

            if isLoading {
                LoadingOverlay()
            }
        }
        .navigationTitle(titleString)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {
                        isEditorFocused = false
                        performSave()
                    }) {
                        Text(String(localized: "#save"))
                            .font(.custom(AppFonts.medium, size: 16))
                            .foregroundColor(hasChanges && hasContent ? .accent : .textSecondary)
                    }
                    .disabled(!hasChanges || !hasContent)
                    if hasExistingEntry {
                        Menu {
                            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                                Label(String(localized: "#delete"), systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18))
                                .foregroundColor(.textPrimary)
                        }
                    }
                }
            }
        }
        .onAppear {
            text = cloudKit.diaryText(for: date)
            let entry = cloudKit.diaryCacheEntry(for: date)
            mood = entry?.mood
            weather = entry?.weather
            let urls = entry?.photoFileURLs ?? []
            originalText = text
            originalMood = mood
            originalWeather = weather
            originalPhotoURLs = urls
            isEditorFocused = true

            // Pre-fill weather from cached fetch for new entries
            if weather == nil && !hasExistingEntry {
                if let code = WeatherService.shared.currentWeatherCode {
                    weather = code
                    originalWeather = code
                }
            }

            // Load photo thumbnails after navigation animation finishes
            if !urls.isEmpty {
                isLoadingPhotos = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let loaded: [(UIImage, URL)] = urls.compactMap { url in
                            guard let thumb = PhotoCacheService.loadThumbnail(from: url, maxSize: 300) else { return nil }
                            return (thumb, url)
                        }
                        DispatchQueue.main.async {
                            withAnimation(.easeOut(duration: 0.3)) {
                                photoItems = loaded.map { PhotoItem(thumbnail: $0.0, sourceURL: $0.1) }
                                isLoadingPhotos = false
                            }
                        }
                    }
                }
            }
        }
        .onDisappear {
            // iPad: auto-save on date switch since there's no back button
            if hSizeClass == .regular {
                saveIfNeeded()
            }
        }
        .onChange(of: cloudKit.diaryText(for: date)) { newText in
            // Update editor when iCloud sync brings new data, but only if user has no local edits
            guard !hasChanges else { return }
            text = newText
            originalText = newText
        }
        .onChange(of: cloudKit.diaryMood(for: date)) { newMood in
            guard !hasChanges else { return }
            mood = newMood
            originalMood = newMood
        }
        .onChange(of: selectedPhotoItems) { newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        if photoItems.count < 9 {
                            let thumb = PhotoCacheService.resizeImage(image, maxDimension: 300)
                            withAnimation(.easeOut(duration: 0.25)) {
                                photoItems.append(PhotoItem(thumbnail: thumb, fullImage: image))
                            }
                        }
                    }
                }
                selectedPhotoItems = []
            }
        }
        .alert(String(localized: "#oops"), isPresented: $showError) {
            Button(String(localized: "#ok"), role: .cancel) {
                if hSizeClass != .regular { dismiss() }
            }
            Button(String(localized: "#dontShowAlert")) {
                UserDefaults.standard.set(true, forKey: "dontShowAlert")
                if hSizeClass != .regular { dismiss() }
            }
        } message: {
            Text(errorMessage)
        }
        .alert(String(localized: "#confirmDelete"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "#delete"), role: .destructive) {
                deleteDiary()
            }
            Button(String(localized: "#cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "#confirmDeleteMessage"))
        }
        .fullScreenCover(item: $fullScreenPhoto) { photo in
            PhotoFullScreenView(
                photoItems: photoItems,
                initialIndex: photo.index
            )
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !photoItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photoItems) { item in
                            photoCell(item: item)
                                .frame(width: 80, height: 80)
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                                .opacity(draggingItem?.id == item.id ? 0.5 : 1.0)
                                .onDrag {
                                    draggingItem = item
                                    return NSItemProvider(object: item.id.uuidString as NSString)
                                }
                                .onDrop(of: [UTType.text], delegate: PhotoDropDelegate(
                                    item: item,
                                    items: $photoItems,
                                    draggingItem: $draggingItem
                                ))
                        }
                    }
                }
            }

            if photoItems.count < 9 {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 9 - photoItems.count,
                    matching: .images
                ) {
                    Label(String(localized: "#addPhoto"), systemImage: "photo.badge.plus")
                        .font(.custom(AppFonts.medium, size: 14))
                        .foregroundColor(.accent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func photoCell(item: PhotoItem) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Image(uiImage: item.thumbnail)
                        .resizable()
                        .scaledToFill()
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
                .onTapGesture {
                    if let index = photoItems.firstIndex(where: { $0.id == item.id }) {
                        fullScreenPhoto = FullScreenPhoto(index: index)
                    }
                }

            Button(action: { removePhoto(item: item) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.danger)
                    .background(Circle().fill(Color.surfaceCard))
            }
            .offset(x: 4, y: -4)
        }
    }

    // MARK: - Actions

    private func removePhoto(item: PhotoItem) {
        withAnimation {
            photoItems.removeAll { $0.id == item.id }
        }
    }

    private var hasContent: Bool {
        !text.isEmpty || mood != nil || !photoItems.isEmpty
    }

    private func saveIfNeeded() {
        guard hasChanges, hasContent else { return }
        performSave()
    }

    private func performSave() {
        guard hasContent else { return }
        isLoading = true
        // Update text + mood + weather in memory
        cloudKit.updateCacheInMemory(text: text, date: date, mood: mood, weather: weather)
        // Update original state so hasChanges resets
        originalText = text
        originalMood = mood
        originalWeather = weather
        originalPhotoURLs = photoItems.compactMap(\.sourceURL)
        // Build photo sources
        let sources: [(image: UIImage?, url: URL?)]
        if isLoadingPhotos {
            let cachedURLs = cloudKit.diaryCacheEntry(for: date)?.photoFileURLs ?? []
            sources = cachedURLs.map { (image: nil, url: $0) }
        } else {
            sources = photoItems.map { (image: $0.fullImage, url: $0.sourceURL) }
        }
        cloudKit.saveInBackground(text: text, date: date, mood: mood, weather: weather, photoSources: sources)
        // Brief loading indicator for user feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
    }

    private func deleteDiary() {
        isLoading = true
        Task {
            do {
                try await cloudKit.deleteDiary(date: date)
                isLoading = false
                if hSizeClass != .regular { dismiss() }
            } catch {
                isLoading = false
                if hSizeClass != .regular { dismiss() }
            }
        }
    }
}

// MARK: - Full Screen Photo Identifier

private struct FullScreenPhoto: Identifiable {
    let index: Int
    var id: Int { index }
}

// MARK: - Full Screen Photo Viewer

private struct PhotoFullScreenView: View {
    let photoItems: [PhotoItem]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage: Int = 0
    @State private var fullImages: [UUID: UIImage] = [:]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentPage) {
                ForEach(Array(photoItems.enumerated()), id: \.element.id) { index, item in
                    let displayImage = fullImages[item.id] ?? item.thumbnail
                    Image(uiImage: displayImage)
                        .resizable()
                        .scaledToFit()
                        .tag(index)
                        .onAppear { loadFullImage(item: item) }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.3))
            }
            .padding(16)
        }
        .overlay(alignment: .bottom) {
            if photoItems.count > 1 {
                Text("\(currentPage + 1)/\(photoItems.count)")
                    .font(.custom(AppFonts.medium, size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            currentPage = initialIndex
        }
    }

    private func loadFullImage(item: PhotoItem) {
        guard fullImages[item.id] == nil else { return }
        if let full = item.fullImage {
            fullImages[item.id] = full
        } else if let url = item.sourceURL {
            DispatchQueue.global(qos: .userInitiated).async {
                if let img = UIImage(contentsOfFile: url.path) {
                    DispatchQueue.main.async {
                        fullImages[item.id] = img
                    }
                }
            }
        }
    }
}
