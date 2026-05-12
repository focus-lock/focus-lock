//
//  RulesView.swift
//  
//
//  Created by Suraj Modur on 1/11/26.
//

import SwiftUI
import FamilyControls

struct RulesView: View {
    
    // New State to track if the sheet(rule add modal) is open
    @State private var showCreateSheet = false
    
    @State private var ruleBeingEdited: Rule?
    
    @State private var goToBlocked = false
    
    // Builds the saved selection text for one rule in the rules list.
    private func selectedActivitySummary(for rule: Rule) -> String {
        // Counts directly selected individual apps.
        let appCount = rule.activitySelection.applicationTokens.count

        // Counts selected app categories, including category "Select All".
        let categoryCount = rule.activitySelection.categoryTokens.count

        // Counts selected websites if the user selects web domains later.
        let webDomainCount = rule.activitySelection.webDomainTokens.count

        // Stores each non-empty piece of the summary text.
        var parts: [String] = []

        // Adds an app summary when individual apps are selected.
        if appCount > 0 {
            parts.append("\(appCount) \(appCount == 1 ? "app" : "apps")")
        }

        // Adds a category summary when categories are selected.
        if categoryCount > 0 {
            parts.append("\(categoryCount) \(categoryCount == 1 ? "category" : "categories")")
        }

        // Adds a website summary when web domains are selected.
        if webDomainCount > 0 {
            parts.append("\(webDomainCount) \(webDomainCount == 1 ? "website" : "websites")")
        }

        // Shows zero selected when nothing has been picked yet.
        if parts.isEmpty {
            return "None Selected"
        }

        // Joins the non-empty pieces and adds the selected label at the end.
        return parts.joined(separator: ", ") + " selected"
    }
    
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
            .sheet(item: $ruleBeingEdited){ rule in
                EditRuleView(rule:rule)
            }
            
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment:.leading, spacing: 16) {
    
                    ForEach($appState.rules){ $rule in
                        VStack(alignment: .leading, spacing: 4){
                            HStack{
                                Text(rule.title)
                                    .font(.title2)
                                    .bold()
                                Spacer()
                                
                                Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(rule.isEnabled ? .green : .red)
                                    .font(.title2)
                                    .onTapGesture {
                                        // Toggle through AppState so the actual Screen Time shield updates too.
                                        appState.toggleRule(id: rule.id)
                                    }
                                
                                //Editing Rule Button
                                Button(action: {
                                    //Updated state var with rule that is currently being edited and goes back to .sheet to call EditRuleView
                                    ruleBeingEdited = rule
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundStyle(.blue)
                                        .font(.title2)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                
                                
                                Button(action:{
                                    
                                    appState.deleteRule(id:rule.id)
                                }){
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                        .font(.title2)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            Text("\(rule.startTime, style: .time) - \(rule.endTime, style: .time)")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            
                            
                            // Shows how many picker items this rule contains.
                            Text(selectedActivitySummary(for: rule))
                                .font(.caption)
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
