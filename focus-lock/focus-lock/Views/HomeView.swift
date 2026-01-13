//
//  HomeView.swift
//  
//
//  Created by Suraj Modur on 1/11/26.
//

import SwiftUI

struct HomeView: View {
    
    @State private var HomeRulePath = NavigationPath()
    
    
    var body: some View {
        NavigationStack {
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
                
                Text("Money Lost: $15")
                    .foregroundColor(.red)
                
                Text("Minutes Wasted: 15 minutes")
                    .foregroundColor(.orange)
                
                Divider()
                
                
                Text("This Week")
                    .font(.title2)
                    .bold()
                
                Text("Money Lost: $100")
                    .foregroundColor(.red)
                
                Text("Minutes Wasted: 35 minutes")
                    .foregroundColor(.orange)
                
                Divider()
                
                Text("Lifetime Stats")
                    .font(.title2)
                    .bold()
                
                Text("Money Lost: $500")
                    .foregroundColor(.red)
                
                Text("Minutes Wasted: 5 hours")
                    .foregroundColor(.orange)
                
                    
                
                Spacer()
                
                NavigationLink {
                    RulesView()
                } label : {
                    Text("Rules")
                        .bold()
                        .foregroundColor(.black)
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                        }
                    
                    
                }
                .frame(maxWidth: .infinity, alignment: .center )
                
                
            }
            .padding()
        }
        }
    }

#Preview {
    HomeView()
}
