
import Foundation
import Combine

class AestheticModel: ObservableObject {
    @Published var aestheticScore: Double = 0.0
    private var cancellables = Set<AnyCancellable>()

    func getAestheticScore(time: Float, complexity: Float, colorShift: Float) {
        guard let url = URL(string: "http://127.0.0.1:5001/predict") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "time": time,
            "complexity": complexity,
            "colorShift": colorShift
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data }
            .decode(type: PredictionResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error: \(error.localizedDescription)")
                }
            }, receiveValue: { response in
                self.aestheticScore = response.aesthetic_score
            })
            .store(in: &cancellables)
    }
}

struct PredictionResponse: Decodable {
    let aesthetic_score: Double
}
