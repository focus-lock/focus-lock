//
//  RulesView.swift
//  
//
//  Created by Suraj Modur on 1/11/26.
//

import SwiftUI

struct RulesView: View {
    
    @State private var goToBlocked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 50) {
            Text("Rules")
                .font(.title)
                .frame(maxWidth: .infinity, alignment: .center)
            
            
            FocusCompactButton(title: "Create Rule"){
                
            }.frame(maxWidth: .infinity, alignment: .trailing)
            
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment:.leading, spacing: 16) {
                    Text("Rule 1: Instagram").font(.title2).bold()
                    Text("Time Limit: 10 minutes")
                    Divider()
                    
                    Text("Rule 2: TikTok") .font(.title2).bold()
                    Text("Time Limit: 5 minutes")
                    
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
        }
}
