import Testing
@testable import SharedModels
import Foundation

@Test func messageContentRoundTrip() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let cases: [MessageContent] = [
        .text("Hello world"),
        .code(language: "swift", content: "print(\"hi\")"),
        .system("Session created"),
        .error("Something went wrong"),
    ]

    for original in cases {
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MessageContent.self, from: data)
        #expect(decoded == original)
    }
}

@Test func wsMessageRoundTrip() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let msg = WSMessage.sendChat(.init(
        sessionId: UUID(),
        content: "Hello",
        stream: true
    ))

    let data = try encoder.encode(msg)
    let decoded = try decoder.decode(WSMessage.self, from: data)

    if case .sendChat(let payload) = decoded {
        #expect(payload.content == "Hello")
        #expect(payload.stream == true)
    } else {
        Issue.record("Expected sendChat")
    }
}