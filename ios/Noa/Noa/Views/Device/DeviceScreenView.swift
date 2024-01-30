//
//  DeviceScreenView.swift
//  Noa
//
//  Created by Artur Burlakin on 6/29/23.
//
//  This is the initial view on a fresh start when Moncole is unpaired and is used for device-
//  related operations: pairing, firmware update, FPGA update. Specific sheets are used for each
//  case.
//
//  Resources
//  ---------
//  - "Computed State in SwiftUI view"
//    https://yoswift.dev/swiftui/computed-state/
//

import SwiftUI

/// Device sheet types
enum DeviceSheetType {
    case pairing
    case firmwareUpdate
    case fpgaUpdate
}

struct DeviceScreenView: View {
    @Binding var showDeviceSheet: Bool
    @Binding var deviceSheetType: DeviceSheetType
    @Binding var monocleWithinPairingRange: Bool
    @Binding var updateProgressPercent: Int
    @Environment(\.openURL) var openURL
    @Environment(\.colorScheme) var colorScheme

    private let _onConnectPressed: (() -> Void)?
    
    var body: some View {
        ZStack {
            colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255).edgesIgnoringSafeArea(.all) : Color(red: 255/255, green: 255/255, blue: 255/255).edgesIgnoringSafeArea(.all)
            VStack {
                VStack {
                    let light = Image("jx-owl")
                        .resizable()
                    let dark = Image("jx-smiley")
                        .resizable()
                    ColorModeAdaptiveImage(light: light, dark: dark)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .padding(.top, 80)
                    
                    Text("know")
                        .font(.system(size: 28, weight: .bold))
                        .padding(.top, -7)
                    Text("by jx&co")
                        .font(.system(size: 18, weight: .bold))
                        .padding(.top, -7)
                    
                    Spacer()
                
                    Text("Let’s set up your Monocle. Take it out of the case, and bring it close.")
                        .font(.system(size: 17))
                        .frame(width: 314, height: 60)
                        .multilineTextAlignment(.center)
                        
                    
                    Spacer()

                    let privacyPolicyText = "Before understanding, one must know."
                    Text(.init(privacyPolicyText))
                        .font(.system(size: 12))
                        .frame(width: 217)
                        .multilineTextAlignment(.center)
                        .accentColor(Color(red: 232/255, green: 46/255, blue: 135/255))
                        .lineSpacing(5)
                }

                VStack {
                    if showDeviceSheet {
                        RoundedRectangle(cornerRadius: 40)
                            .fill(Color.white)
                            .frame(height: 350)
                            .padding(10)
                            .overlay(
                                PopupDeviceView(
                                    showDeviceSheet: $showDeviceSheet,
                                    deviceSheetType: $deviceSheetType,
                                    monocleWithinPairingRange: $monocleWithinPairingRange,
                                    updateProgressPercent: $updateProgressPercent,
                                    onConnectPressed: _onConnectPressed
                                )
                            )
                    }
                }
            }
        }
        .ignoresSafeArea(.all)
    }

    init(showDeviceSheet: Binding<Bool>, deviceSheetType: Binding<DeviceSheetType>, monocleWithinPairingRange: Binding<Bool>, updateProgressPercent: Binding<Int>, onConnectPressed: (() -> Void)?) {
        _showDeviceSheet = showDeviceSheet
        _deviceSheetType = deviceSheetType
        _monocleWithinPairingRange = monocleWithinPairingRange
        _updateProgressPercent = updateProgressPercent
        _onConnectPressed = onConnectPressed
    }
}

struct DeviceScreenView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceScreenView(
            showDeviceSheet: .constant(true),
            deviceSheetType: .constant(.firmwareUpdate),
            monocleWithinPairingRange: .constant(false),
            updateProgressPercent: .constant(50),
            onConnectPressed: { print("Connect pressed") }
        )
    }
}
