//
//  RulesView.swift
//  
//
//  Created by Suraj Modur on 1/11/26.
//

import SwiftUI

struct RulesView: View {
    
    @State private var goToBlocked = false
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 50) {
            Text("Rules")
                .font(.title)
                .frame(maxWidth: .infinity, alignment: .center)
            
            
            
            FocusCompactButton(title: "Create Rule"){
                appState.rules.append(Rule(title: "New Rule \(appState.rules.count + 1)", isEnabled: true))
            }.frame(maxWidth: .infinity, alignment: .trailing)
            
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment:.leading, spacing: 16) {
                    
                    ForEach(appState.rules){ rule in
                        VStack(alignment: .leading, spacing: 4){
                            HStack{
                                Text(rule.title)
                                    .font(.title2)
                                    .bold()
                                Spacer()
                                Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(rule.isEnabled ? .green : .red)
                                
                            }
                            Text(rule.isEnabled ? "Enabled" : "Disabled")
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                    }
                    
                }
            }
            
            FocusButton(title: "Blocked Screen") {
                goToBlocked = true
            }
        }.padding(20)
        .navigationDestination(isPresented: $goToBlocked) {
            BlockedView()
        }
    }
    
}

#Preview {
    NavigationStack {
            RulesView()
                .environmentObject(AppState())
        }
}
