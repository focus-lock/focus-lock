//
//  ContentView.swift
//  focus-lock
//
//  Created by Shabarish Nair on 1/11/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isAuthed = false
    
    var body: some View {
        if isAuthed{
            NavigationStack{
                HomeView()
            }
        }
        else {
            AuthView(isAuthed: $isAuthed)
        }
    }
}

#Preview {
    ContentView()
}
