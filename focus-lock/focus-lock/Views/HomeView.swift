//
//  HomeView.swift
//  
//
//  Created by Suraj Modur on 1/11/26.
//

import SwiftUI

struct HomeView: View {
    
    @EnvironmentObject var appState: AppState // Shared app state injected from ContentView
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            Text("Focus Lock")
                .font(.largeTitle)
                .bold()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)
            
            Text(Date(), style: .date)
                .font(.headline)
                .foregroundColor(.gray)
            
            Divider()
            
            Text("Today")
                .font(.title2)
                .bold()
            
            Text("Money Lost: \(appState.formattedMoney(appState.moneyLostToday))") // Read today's money lost from shared state
                .foregroundColor(.red)
            
            Text("Minutes Wasted: \(appState.minutesWastedToday) minutes") // Read today's minutes wasted from shared state
                .foregroundColor(.orange)
            
            Divider()
            
            
            Text("This Week")
                .font(.title2)
                .bold()
            
            Text("Money Lost: \(appState.formattedMoney(appState.moneyLostThisWeek))") // Weekly money lost from state
                .foregroundColor(.red)
            
            Text("Minutes Wasted: \(appState.minutesWastedThisWeek) minutes") // Weekly minutes wasted from state
                .foregroundColor(.orange)
            
            Divider()
            
            Text("Lifetime Stats")
                .font(.title2)
                .bold()
            
            Text("Money Lost: \(appState.formattedMoney(appState.moneyLostLifetime))") // Lifetime money lost from state
                .foregroundColor(.red)
            
            Text("Minutes Wasted: \(appState.lifetimeHours) hours") // Lifetime hours derived from minutes in state
                .foregroundColor(.orange)
            
                
            
            Spacer()
            
        }.padding()
        
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppState()) // Provide preview AppState so @EnvironmentObject resolves
    }
}
