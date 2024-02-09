//
//  Tutorial.swift
//  Noa
//
//  Created by Bart Trzynadlowski on 10/5/23.
//

import UIKit

func displayTutorialInChatWindow(chatMessageStore: ChatMessageStore) async throws {
    let messages: [(pause: Float, image: UIImage?, text: String)] = [
        ( pause: 2, image: nil, text: "Hi I'm a cyborg eyepiece, Let's show you around 🙂" ),
        ( pause: 3, image: UIImage(named: "Tutorial_2"), text: "Tap either of the touch pads and speak. I'll respond directly on your Monocle." ),
        ( pause: 3, image: UIImage(named:"Tutorial_3_alt"), text: "I can also translate whatever I hear into English, or .\n\nUse the gear icon at the top right to switch modes or enter your OpenAI API key." ),
//        ( pause: 5, image: UIImage(named: "Tutorial_4"), text: "Did you know that I'm a fantastic artist? Tap then hold, and Monocle will take a picture before listening.\n\nAsk me how to change the image, and I'll return back a new image right here in the chat." ),
        ( pause: 0, image: nil, text: "Go ahead. Ask me anything" )
    ]

    for (pause, image, text) in messages {
        chatMessageStore.putMessage(Message(text: text, picture: image, participant: .assistant))
        try Task.checkCancellation()
        try await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
    }
}
