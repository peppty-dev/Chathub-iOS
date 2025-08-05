import Foundation

class FalconChatbotClient {

    enum FalconError: Error {
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case decodingFailed(Error)
    }

    func sendMessage(apiKey: String, apiURL: String, prompt: String, completion: @escaping (Result<String, FalconError>) -> Void) {
        guard let url = URL(string: apiURL) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["inputs": prompt]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.requestFailed(error)))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode), let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            // Assuming the response is a JSON array with a dictionary containing "generated_text"
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]],
                   let firstResult = jsonResponse.first,
                   let generatedText = firstResult["generated_text"] as? String {
                    completion(.success(generatedText))
                } else {
                    completion(.failure(.invalidResponse))
                }
            } catch {
                completion(.failure(.decodingFailed(error)))
            }
        }.resume()
    }
} 