//
//  ContentView.swift
//  focus-lock
//
//  Created by Shabarish Nair on 1/11/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isAuthed = false
    
    // Reads the shared app state created by focus_lockApp.
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if isAuthed {
            TabView {
                NavigationStack {
                    HomeView()
                }
                .tabItem {
                    Label("Home", systemImage: "house")
                }

                NavigationStack {
                    RulesView()
                }
                .tabItem {
                    Label("Rules", systemImage: "book.closed")
                }

                NavigationStack {
                    HabitsView()
                }
                .tabItem {
                    Label("Habits", systemImage: "chart.bar.xaxis")
                }
            }
            // Inject the shared state into the entire tab hierarchy.
            // Any child view can access it with @EnvironmentObject var appState: AppState
            .environmentObject(appState)
        } else {
            AuthView(isAuthed: $isAuthed)
                // Optional: also inject appState here if the auth flow needs it.
                .environmentObject(appState)
        }
    }
}



#Preview {
    ContentView()
        // Gives the preview the shared app state that ContentView expects.
        .environmentObject(AppState())
}
