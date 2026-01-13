//
//  AuthView.swift
//  focus-lock
//
//  Created by Shabarish Nair on 1/11/26.
//

import SwiftUI

struct AuthView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @Binding var isAuthed: Bool
    
    var body: some View {
        VStack(){
            Text("Focus Lock").font(.title)
            
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Sign up"){
                
            }.buttonStyle(.borderedProminent)
            
            Button("Guest Access(No login)"){
                isAuthed = true
            }
            
        }.padding()
    }
}

#Preview {
    AuthPreviewWrapper()
}

private struct AuthPreviewWrapper: View {
    @State private var isAuthed = false
    var body: some View {
        AuthView(isAuthed: $isAuthed)
    }
}
