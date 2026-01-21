//
//  RulesView.swift
//  
//
//  Created by Suraj Modur on 1/11/26.
//

import SwiftUI

struct RulesView: View {
    
    // New State to track if the sheet(rule add modal) is open
    @State private var showCreateSheet = false
    
    @State private var goToBlocked = false
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 50) {
            Text("Rules")
                .font(.title)
                .frame(maxWidth: .infinity, alignment: .center)
            
            
            
            FocusCompactButton(title: "Create Rule"){
                // flipping this to true.
                // the .sheet modifier below watches this switch
                showCreateSheet = true
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            // when showCreateSheet becomes true, it presents the view
            .sheet(isPresented: $showCreateSheet){
                CreateRuleView()
            }
            
            
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
                            Text("\(rule.startTime, style: .time) - \(rule.endTime, style: .time)")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
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
