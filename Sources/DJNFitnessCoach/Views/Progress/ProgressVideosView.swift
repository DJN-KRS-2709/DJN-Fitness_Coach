import SwiftUI
import SwiftData
import PhotosUI
import AVKit
import AVFoundation

struct ProgressMediaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProgressVideo.date, order: .reverse) private var media: [ProgressVideo]

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var playingVideo: ProgressVideo?
    @State private var viewingPhoto: ProgressVideo?
    @State private var showingDeleteAlert: ProgressVideo?
    @State private var showingNoteEditor: ProgressVideo?
    @State private var editingNote = ""

    // Coach handoff
    var onSendToCoach: ((UIImage) -> Void)?

    private let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                if media.isEmpty {
                    emptyState
                } else {
                    mediaGrid
                }

                if isImporting {
                    importOverlay
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 10,
                        matching: .any(of: [.videos, .images])
                    ) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.purple)
                    }
                }
            }
            .onChange(of: selectedItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await importItems(items) }
            }
            .fullScreenCover(item: $playingVideo) { video in
                if let url = video.fileURL {
                    VideoPlayerView(url: url, title: mediaTitle(video))
                }
            }
            .sheet(item: $viewingPhoto) { photo in
                if let data = photo.imageData ?? photo.thumbnailData, let img = UIImage(data: data) {
                    PhotoViewerView(image: img, title: mediaTitle(photo), onSendToCoach: onSendToCoach)
                }
            }
            .sheet(item: $showingNoteEditor) { item in
                noteEditorSheet(item)
            }
            .alert("Delete?", isPresented: Binding(
                get: { showingDeleteAlert != nil },
                set: { if !$0 { showingDeleteAlert = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let v = showingDeleteAlert { deleteMedia(v) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete this item.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppColors.purple.opacity(0.12))
                    .frame(width: 90, height: 90)
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 38))
                    .foregroundColor(AppColors.purple)
            }
            VStack(spacing: 8) {
                Text("No Progress Media")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                Text("Upload photos or videos to track visual progress and get AI body analysis.")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 10,
                matching: .any(of: [.videos, .images])
            ) {
                Label("Add Photos or Videos", systemImage: "photo.stack.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(AppColors.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Spacer()
            Spacer()
        }
    }

    // MARK: - Media Grid

    private var mediaGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(media) { item in
                    mediaCell(item)
                }
            }
        }
    }

    private func mediaCell(_ item: ProgressVideo) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Thumbnail / photo
            Group {
                if item.isPhoto {
                    if let data = item.imageData ?? item.thumbnailData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholderRect(icon: "photo.fill")
                    }
                } else {
                    if let data = item.thumbnailData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholderRect(icon: "video.fill")
                    }
                }
            }
            .frame(height: 160)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                if item.isPhoto { viewingPhoto = item } else { playingVideo = item }
            }

            // Play icon overlay for videos
            if !item.isPhoto {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(radius: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .allowsHitTesting(false)
            }

            // Date/note overlay
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                .frame(height: 60)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.date.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
            .allowsHitTesting(false)
        }
        .contextMenu {
            if item.isPhoto, let onSend = onSendToCoach {
                Button {
                    if let data = item.imageData ?? item.thumbnailData, let img = UIImage(data: data) {
                        onSend(img)
                    }
                } label: {
                    Label("Send to Coach", systemImage: "brain.head.profile")
                }
            }
            Button {
                editingNote = item.notes
                showingNoteEditor = item
            } label: {
                Label("Edit Note", systemImage: "pencil")
            }
            Button(role: .destructive) {
                showingDeleteAlert = item
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func placeholderRect(icon: String) -> some View {
        Rectangle()
            .fill(AppColors.cardBackground)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.textSecondary)
            )
    }

    // MARK: - Note Editor

    private func noteEditorSheet(_ item: ProgressVideo) -> some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.date.formatted(.dateTime.day().month(.wide).year()))
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    TextField("e.g. 83 kg, post-bulk check-in", text: $editingNote, axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(3...6)
                        .padding(14)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)

                    Spacer()
                }
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingNoteEditor = nil }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        item.notes = editingNote
                        try? modelContext.save()
                        showingNoteEditor = nil
                    }
                    .foregroundColor(AppColors.purple)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Import Overlay

    private var importOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                SwiftUI.ProgressView(value: importProgress)
                    .progressViewStyle(.linear)
                    .tint(AppColors.purple)
                    .frame(width: 200)
                Text("Importing…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(24)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Actions

    private func importItems(_ items: [PhotosPickerItem]) async {
        isImporting = true
        importProgress = 0
        let dir = mediaDirectory()

        for (index, item) in items.enumerated() {
            // Try video first
            if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                let fileName = "\(UUID().uuidString).mov"
                let dest = dir.appendingPathComponent(fileName)
                try? FileManager.default.copyItem(at: movie.url, to: dest)
                let thumbnail = await generateThumbnail(url: dest)
                let record = ProgressVideo(date: Date(), fileName: fileName, mediaType: "video")
                record.thumbnailData = thumbnail?.jpegData(compressionQuality: 0.6)
                await MainActor.run {
                    modelContext.insert(record)
                    try? modelContext.save()
                }
            } else if let data = try? await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) {
                // It's a photo
                let record = ProgressVideo(date: Date(), fileName: "", mediaType: "photo")
                // Store full-res (capped at 1200px wide for memory)
                let resized = resizeImage(uiImage, maxDimension: 1200)
                record.imageData = resized.jpegData(compressionQuality: 0.85)
                // Thumbnail for grid
                let thumb = resizeImage(uiImage, maxDimension: 400)
                record.thumbnailData = thumb.jpegData(compressionQuality: 0.6)
                await MainActor.run {
                    modelContext.insert(record)
                    try? modelContext.save()
                }
            }

            await MainActor.run {
                importProgress = Double(index + 1) / Double(items.count)
            }
        }

        await MainActor.run {
            selectedItems = []
            isImporting = false
        }
    }

    private func deleteMedia(_ item: ProgressVideo) {
        if let url = item.fileURL {
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(item)
        try? modelContext.save()
        showingDeleteAlert = nil
    }

    private func mediaTitle(_ item: ProgressVideo) -> String {
        let date = item.date.formatted(.dateTime.day().month(.abbreviated).year())
        return item.notes.isEmpty ? date : "\(date) — \(item.notes)"
    }

    private func mediaDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("ProgressVideos")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func generateThumbnail(url: URL) async -> UIImage? {
        await withCheckedContinuation { cont in
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 400, height: 400)
            gen.generateCGImageAsynchronously(for: CMTime(seconds: 1, preferredTimescale: 60)) { image, _, _ in
                cont.resume(returning: image.map { UIImage(cgImage: $0) })
            }
        }
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

// MARK: - Photo Viewer

struct PhotoViewerView: View {
    let image: UIImage
    let title: String
    var onSendToCoach: ((UIImage) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
                if let onSend = onSendToCoach {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            onSend(image)
                            dismiss()
                        } label: {
                            Label("Send to Coach", systemImage: "brain.head.profile")
                                .foregroundColor(AppColors.purple)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Video Transferable (unchanged)

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent(received.file.lastPathComponent)
            try? FileManager.default.copyItem(at: received.file, to: temp)
            return Self(url: temp)
        }
    }
}

// MARK: - Video Player View (unchanged)

struct VideoPlayerView: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
            player?.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
