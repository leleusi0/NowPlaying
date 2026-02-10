//
//  ContentView.swift
//  NowPlaying
//
//  Created by Lucas Eleusiniotis on 2026-02-03.
//

import SwiftUI
import MusicKit
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var songTitle = "Song Title"
    @State private var artistName = "Geyonce"
    @State private var isPlaying: Bool = false
    @State private var authStatus: MusicAuthorization.Status = .notDetermined
    @State private var authErrorMessage: String?

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
                    // If not authorized, show a friendly message and do not proceed
                    if authStatus != .authorized {
                        authErrorMessage = "Please allow Apple Music access to use playback features."
                        return
                    }

                    // If authorized, this is where you'd interact with MusicKit's player.
                    // For now, we just toggle the UI state to demonstrate the flow.
                    isPlaying.toggle()
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
        // MARK: - .task modifier
        // `.task` runs an async task tied to this view's lifecycle. It starts when
        // the view appears and cancels when the view disappears. This is the
        // recommended way to kick off async work (like requesting authorization)
        // from SwiftUI views.
        .task {
            await requestMusicAccess()
        }
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
