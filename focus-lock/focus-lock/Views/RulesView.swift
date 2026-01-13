//
//  RulesView.swift
//  
//
//  Created by Suraj Modur on 1/11/26.
//

import SwiftUI

struct RulesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 50) {
            Text("Rules")
                .font(.title)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Button {
                
            } label : {
                Text("Create Rule")
                    .frame(width: 100, height:50)
                    .bold()
                    .foregroundColor(.black)
                
                    .background {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            
            
            
            
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment:.leading, spacing: 16) {
                    Text("Rule 1: Instagram").font(.title2).bold()
                    Text("Time Limit: 10 minutes")
                    Divider()
                    
                    Text("Rule 2: TikTok") .font(.title2).bold()
                    Text("Time Limit: 5 minutes")
                    
                }
            }
        }.padding(20)
    }
}

#Preview {
    RulesView()
}
