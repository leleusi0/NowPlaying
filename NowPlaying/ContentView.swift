//
//  ContentView.swift
//  NowPlaying
//
//  Created by Lucas Eleusiniotis on 2026-02-03.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var songTitle = "Song Title"
    @State private var artistName = "Artist Name"
    @State private var isPlaying: Bool = false

    var body: some View {
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
                
                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .padding()
                }
            }
            .padding()
            Spacer()
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

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
