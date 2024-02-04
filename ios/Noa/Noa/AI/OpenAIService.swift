import Foundation

public class OpenAIService {
    static let shared = OpenAIService()
    

    // Dictionary to map model types to their respective endpoints
    private let modelEndpoints: [String: String] = [
        "GPT-4": "https://api.openai.com/v1/engines/{model}/completions",
        "GPT-3.5": "https://api.openai.com/v1/engines/{model}/completions",
        "DALL·E": "https://api.openai.com/v1/engines/{model}/images",
        "TTS": "https://api.openai.com/v1/engines/{model}/tts",
        "Whisper": "https://api.openai.com/v1/audio/transcriptions",
        "Embedding": "https://api.openai.com/v1/engines/{model}/embeddings",
        "Moderation": "https://api.openai.com/v1/engines/{model}/moderations",
        "GPT Base": "https://api.openai.com/v1/engines/{model}/completions"
    ]
    
    func getCompletionModels() -> [String] {
           var models: [String] = []
           models += getGPT4Models()
           models += getGPT35Models()
           models += getGPTBaseModels()
           return models.sorted() // Sort if desired
       }

    // GPT-4 Models
    func getGPT4Models() -> [String] {
        return [
            "gpt-4-0125-preview",
            "gpt-4-turbo-preview",
            "gpt-4-1106-preview",
            "gpt-4-vision-preview",
            "gpt-4",
            "gpt-4-0613",
            "gpt-4-32k",
            "gpt-4-32k-0613"
        ]
    }

    // GPT-3.5 Models
    func getGPT35Models() -> [String] {
        return [
            "gpt-3.5-turbo-1106",
            "gpt-3.5-turbo",
            "gpt-3.5-turbo-16k",
            "gpt-3.5-turbo-instruct",
            "gpt-3.5-turbo-0613",
            "gpt-3.5-turbo-16k-0613",
            "gpt-3.5-turbo-0301"
        ]
    }

    // DALL·E Models
    func getDalleModels() -> [String] {
        return ["dall-e-3", "dall-e-2"]
    }

    // TTS Models
    func getTTSModels() -> [String] {
        return ["tts-1", "tts-1-hd"]
    }

    // Whisper Models
    func getWhisperModels() -> [String] {
        return ["whisper-1"]
    }

    // Embedding Models
    func getEmbeddingModels() -> [String] {
        return ["text-embedding-3-large", "text-embedding-3-small", "text-embedding-ada-002"]
    }

    // Moderation Models
    func getModerationModels() -> [String] {
        return ["text-moderation-latest", "text-moderation-stable", "text-moderation-007"]
    }

    // GPT Base Models
    func getGPTBaseModels() -> [String] {
        return ["babbage-002", "davinci-002"]
    }

    // Function to get the API endpoint for a given model type
    public func getEndpoint(forModelType modelType: String) -> String? {
        return modelEndpoints[modelType]
    }
}
