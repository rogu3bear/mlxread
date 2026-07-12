import Foundation

/// Uploads a problem report (a debug .zip plus the user's optional email and
/// description) to the delivery worker, which emails it to the maintainer.
struct ReportSender {
    struct Fields: Sendable {
        var email: String
        var description: String
        var appVersion: String
        var osVersion: String
    }

    func send(zip: Data, fields: Fields) async throws {
        let boundary = "mlxread.\(UUID().uuidString)"
        var request = URLRequest(url: Constants.Report.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.Report.token, forHTTPHeaderField: "X-MLXRead-Token")
        request.httpBody = Self.multipartBody(boundary: boundary, fields: fields, zip: zip)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ReportError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ReportError.network("No response from the server.")
        }
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if (200..<300).contains(http.statusCode), (payload?["ok"] as? Bool) == true {
            return
        }
        let reason = (payload?["error"] as? String) ?? "The server returned HTTP \(http.statusCode)."
        throw ReportError.server(friendly(reason))
    }

    private func friendly(_ code: String) -> String {
        switch code {
        case "rate_limited": return "You've sent a few reports recently — please try again a little later."
        case "bad_bundle_size": return "The debug bundle was too large to send."
        case "unauthorized": return "This build can't submit reports."
        default: return "Couldn't send the report (\(code)). Please try again."
        }
    }

    private static func multipartBody(boundary: String, fields: Fields, zip: Data) -> Data {
        var body = Data()
        func text(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        text("email", fields.email)
        text("description", fields.description)
        text("app_version", fields.appVersion)
        text("os_version", fields.osVersion)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"bundle\"; filename=\"mlxread-debug.zip\"\r\n")
        body.append("Content-Type: application/zip\r\n\r\n")
        body.append(zip)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let encoded = string.data(using: .utf8) { append(encoded) }
    }
}
