//
//  ContentView.swift
//  NowPlaying
//
//  Created by Lucas Eleusiniotis on 2026-02-03.
//

import SwiftUI
import MusicKit
import SwiftData
import AVFoundation

// MARK: - Simple AVFoundation audio controller
// This controller lets us play a local audio file without needing a MusicKit developer token.
// It is intentionally minimal and focused on learning play/pause wiring with SwiftUI state.
final class AudioPlayerController: ObservableObject {
    private var player: AVPlayer?
    @Published var isPlaying: Bool = false

    /// Load an audio URL into the AVPlayer
    func load(url: URL) {
        player = AVPlayer(url: url)
    }

    /// Start playback and mark the state as playing
    func play() {
        player?.play()
        isPlaying = true
    }

    /// Pause playback and mark the state as not playing
    func pause() {
        player?.pause()
        isPlaying = false
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var songTitle = "Song Title"
    @State private var artistName = "Geyonce"
    @State private var isPlaying: Bool = false
    @State private var authStatus: MusicAuthorization.Status = .notDetermined
    @State private var authErrorMessage: String?

    // AVFoundation-based player for learning without MusicKit developer token
    @StateObject private var audioController = AudioPlayerController()

    var body: some View { // Start building the UI
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Text(songTitle)
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text(artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // MARK: - Play/Pause button
                // This demonstrates how you might gate playback based on authorization.
                // For learning purposes, we simply toggle the icon if not authorized,
                // and you can later wire this up to real MusicKit playback.
                Button {
                    // For learning without a MusicKit developer token, we use AVFoundation to play
                    // a local bundled audio file. This avoids the "failed to request developer token" error.

                    // Ensure we have loaded a sample file. You should add a short MP3 named
                    // "sample.mp3" to your app target (File > Add Files to "NowPlaying"...).
                    // If it's not present, show a helpful message.
                    if audioControllerIsUnloaded {
                        if let url = Bundle.main.url(forResource: "sample", withExtension: "mp3") {
                            audioController.load(url: url)
                        } else {
                            authErrorMessage = "Missing sample.mp3 in the app bundle. Add a small audio file named 'sample.mp3' to try playback."
                            return
                        }
                    }

                    // Toggle play/pause using the controller
                    if audioController.isPlaying {
                        audioController.pause()
                        isPlaying = false
                    } else {
                        audioController.play()
                        isPlaying = true
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .padding()
                }
            }
            .padding()
            
            // MARK: - Authorization status and guidance UI
            // We display the current MusicKit authorization status so you can see
            // what state the system is in. This is purely for learning/diagnostics.
            VStack(spacing: 6) {
                // Show the raw status value for quick reference
                Text("Music Authorization: \(String(describing: authStatus))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // If we have a friendly message (e.g., denied/restricted), show it
                if let msg = authErrorMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                // Optional: Provide a way to re-request access. This will only
                // present the system prompt if the status is `.notDetermined`.
                if authStatus != .authorized {
                    Button("Request Apple Music Access") {
                        // Use Task to call async functions from a button tap
                        Task { await requestMusicAccess() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            Spacer()
        }
        .task {
            // Request MusicKit access (kept for future use when you add a developer token).
            await requestMusicAccess()

            // Also attempt to preload a local sample so the first play is immediate.
            // Make sure you have added a file named "sample.mp3" to your app bundle.
            if let url = Bundle.main.url(forResource: "sample", withExtension: "mp3") {
                audioController.load(url: url)
            }
        }
    }

    // MARK: - Helper to detect if our AVPlayer has been loaded yet
    private var audioControllerIsUnloaded: Bool {
        // We infer unloaded state by inspecting the controller's internal player via KVC-safe approach.
        // Since `player` is private, we can alternatively track load via `isPlaying` never being true
        // and attempting to load lazily when the button is tapped. For clarity, we try to load when
        // `isPlaying` is false and the controller hasn't started playback yet.
        // Here, we simply consider it unloaded if we've never started playback.
        return !isPlaying && !audioController.isPlaying
    }

    // MARK: - Authorization helpers
    // We keep these helpers inside the view for simplicity. In a larger app, you might
    // move them into a separate service or an observable object.

    /// Requests MusicKit authorization and updates local UI state.
    /// - Note: If the current status is `.notDetermined`, `MusicAuthorization.request()`
    ///         will show the system prompt. Otherwise, it just returns the current status.
    @MainActor
    func requestMusicAccess() async {
        // 1) Check the current status without prompting
        let current = await MusicAuthorization.currentStatus

        if current == .notDetermined {
            // 2) The system hasn't asked yet. Calling `request()` will show the prompt.
            let status = await MusicAuthorization.request()
            authStatus = status

            // 3) If we didn't get authorized, store a friendly message for the UI
            if status != .authorized {
                authErrorMessage = message(for: status)
            } else {
                authErrorMessage = nil
            }
        } else {
            // If we already have a status, just store it
            authStatus = current

            // Provide a helpful message if access isn't granted
            if current != .authorized {
                authErrorMessage = message(for: current)
            } else {
                authErrorMessage = nil
            }
        }
    }
    
    // NOTE: The following MusicKit catalog calls typically require a valid Developer Token.

    @MainActor
    func searchSongs(query: String) async throws -> [Song] {
        // Create a search request for songs
        var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
        request.limit = 10
        let response = try await request.response()
        return Array(response.songs)
    }

    @MainActor
    func playSong(_ song: Song) async throws {
        // Use the shared application music player
        let player = ApplicationMusicPlayer.shared

        // Prepare the queue with the selected song
        player.queue = [song]

        // Start playback
        try await player.play()
    }

    /// Converts a MusicAuthorization.Status into a friendly, user-facing message.
    func message(for status: MusicAuthorization.Status) -> String {
        switch status {
        case .authorized:
            return "Access granted."
        case .notDetermined:
            return "Permission not requested yet."
        case .denied:
            return "Access denied. Enable in Settings > Privacy & Security > Media & Apple Music."
        case .restricted:
            return "Access restricted by system or parental controls."
        @unknown default:
            return "Unknown authorization status."
        }
    }


    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

// Note: Previews won't show the real system authorization prompt.
#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

