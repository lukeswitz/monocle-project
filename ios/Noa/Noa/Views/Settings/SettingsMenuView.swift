//
//  SettingsMenuView.swift
//  Noa
//
//  Created by Bart Trzynadlowski on 7/10/23.
//

import SwiftUI

struct SettingsMenuView: View {
    @EnvironmentObject private var _settings: Settings

    @Binding var popUpApiBox: Bool
    @Binding var showPairingView: Bool
    @Binding var bluetoothEnabled: Bool
    @Binding var mode: ChatGPT.Mode

    @State private var _translateEnabled = false
    @State private var _transcribeEnabled = false

    var body: some View {
        Menu {
            let isMonoclePaired = _settings.pairedDeviceID != nil

            Button(action: {
                popUpApiBox = true
            }) {
                Label("Manage API Key", systemImage: "person.circle")
            }

            Toggle(isOn: $_translateEnabled) {
                Label("Translate", systemImage: "globe")
            }
            .toggleStyle(.button)
            
            Toggle(isOn: $_transcribeEnabled) {
                Label("Transcribe", systemImage: "hearingdevice.ear")
            }
            .toggleStyle(.button)

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
        } label: {
            Image(systemName: "gearshape.fill")
                .foregroundColor(Color(red: 87/255, green: 199/255, blue: 170/255))
        }
        .onAppear {
            //_translateEnabled = mode == .translator
            mode = _settings.getChatMode()
            if (mode == .assistant){
                
            } else if (mode == .translator) {
                _translateEnabled = true
            }  else if (mode == .transcriber) {
                _transcribeEnabled = true
            }
            
        }
        .onChange(of: _translateEnabled) { newValue in
            if newValue {
                _transcribeEnabled = false // Disable transcribe when translate is enabled
                mode = .translator
                
            } else if !_transcribeEnabled {
                mode = .assistant // If both are false, set mode to assistant
            }
            _settings.setChatMode(mode)
            print("Mode: ", mode)
        }
        .onChange(of: _transcribeEnabled) { newValue in
            if newValue {
                _translateEnabled = false // Disable translate when transcribe is enabled
                mode = .transcriber
            } else if !_translateEnabled {
                mode = .assistant // If both are false, set mode to assistant
            }
            print("Mode: ", mode)
            _settings.setChatMode(mode)
        }
    }
}

struct SettingsMenuView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsMenuView(
            popUpApiBox: .constant(false),
            showPairingView: .constant(false),
            bluetoothEnabled: .constant(true),
            mode: .constant(.assistant)
        )
            .environmentObject(Settings())
    }
}
