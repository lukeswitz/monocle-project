//
//  SettingsMenuView.swift
//  Noa
//
//  Created by Bart Trzynadlowski on 7/10/23.
//

import SwiftUI

struct SettingsMenuView: View {
    @EnvironmentObject private var _settings: Settings
    
    @Binding var showPairingView: Bool
    @Binding var bluetoothEnabled: Bool
    @Binding var mode: AIAssistant.Mode
    
    @State private var _translateEnabled = false
    @State private var _assistantEnabled = false
    @State private var _s2textEnabled = false
    @State private var openAIKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
    @State private var isEditingApiKey = false
    
    var body: some View {
        Menu {
            let isMonoclePaired = _settings.pairedDeviceID != nil
            
            let isAuthorized = openAIKey != ""
            
            Toggle(isOn: $_translateEnabled) {
                Label("Dictate", systemImage: "hearingdevice.ear")
            }
            .toggleStyle(.button)
            .onChange(of: _translateEnabled) { newValue in
                if newValue {
                    // Activate the mode when the toggle is selected
                    mode = .translator
                } else {
                    // Deactivate the mode when the toggle is deselected (if needed)
                    mode = .assistant // Change to the appropriate mode when not selected
                }
            }
            
            Button(role: isMonoclePaired ? .destructive : .none, action: {
                if isMonoclePaired {
                    // Unpair
                    _settings.setPairedDeviceID(nil)
                }
                
                // Always return to pairing screen right after unpairing or when pairing requested
                showPairingView = true
            }) {
                // Unpair/pair Monocle
                if isMonoclePaired {
                    Label("Unpair Monocle", systemImage: "wake")
                } else {
                    Label("Pair Monocle", systemImage: "wake")
                }
            }
            
            Button(action: {
                
                // Open the input field as a sheet
                isEditingApiKey = true
                
            }) {
                if isAuthorized {
                    Label("API Key", systemImage: "checkmark.seal")
                } else {
                    Label("No Key", systemImage: "xmark.seal")
                }
            }
            
        } label: {
            Image(systemName: "gearshape.fill")
                .foregroundColor(Color(red: 87/255, green: 199/255, blue: 170/255))
        }
        .onAppear() {
            _translateEnabled = mode == .translator
            print("Mode is:", mode)
        }
        .sheet(isPresented: $isEditingApiKey) {
            NavigationView {
                VStack {
                    TextField("Enter API Key", text: $openAIKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    Button(action: {
                        // Store apiKeyInput or perform any other actions
                        storeApiKey(openAIKey)
                        isEditingApiKey = false
                    }) {
                        Text("Save")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(50)
                .navigationTitle("OpenAI API Key")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isEditingApiKey = false // Close the input field
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            storeApiKey(openAIKey)
                            isEditingApiKey = false // Close the input field
                        }
                    }
                }
            }
            .frame(width: 300, height: 300) // Adjust the size as needed
        }
    }
}

func storeApiKey(_ apiKey: String) {
    // Store the API key in UserDefaults or wherever you want to save it
    UserDefaults.standard.set(apiKey, forKey: "openAIKey")
}

struct SettingsMenuView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsMenuView(
            showPairingView: .constant(false),
            bluetoothEnabled: .constant(true),
            mode: .constant(.assistant)
        )
        .environmentObject(Settings())
    }
}
