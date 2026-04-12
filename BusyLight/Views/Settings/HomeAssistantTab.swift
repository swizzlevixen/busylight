import SwiftUI

struct HomeAssistantTab: View {
    @State private var settings = AppSettings.shared
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var isTesting = false
    @State private var tokenText: String = ""

    @State private var urlWarning: String?

    enum ConnectionStatus {
        case unknown, testing, success, failure(String)
    }

    var body: some View {
        Form {
            Section("Connection") {
                TextField("URL", text: $settings.haBaseURL, prompt: Text("http://homeassistant.local:8123"))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { sanitizeAndValidateURL() }

                if let urlWarning {
                    Text(urlWarning)
                        .foregroundStyle(.orange)
                        .font(.caption)
                }

                SecureField("Long-Lived Access Token", text: $tokenText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: tokenText) { _, newValue in
                        settings.haToken = newValue
                    }

                Text("To create a Long-Lived Access Token, go to your Home Assistant instance, click on your profile (bottom left), scroll to the bottom, and click \"Create Token\".")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(isTesting || settings.haBaseURL.isEmpty || tokenText.isEmpty)

                    Spacer()

                    statusView
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            tokenText = settings.haToken
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch connectionStatus {
        case .unknown:
            EmptyView()
        case .testing:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Testing\u{2026}").foregroundStyle(.secondary)
            }
        case .success:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Connected").foregroundStyle(.green)
            }
        case .failure(let msg):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                Text(msg).foregroundStyle(.red).lineLimit(2)
            }
        }
    }

    private func sanitizeAndValidateURL() {
        let sanitized = URLSanitizer.sanitize(settings.haBaseURL)
        settings.haBaseURL = sanitized

        if sanitized.isEmpty {
            urlWarning = nil
        } else if !URLSanitizer.isValid(sanitized) {
            urlWarning = "This doesn\u{2019}t look like a valid URL"
        } else {
            urlWarning = nil
        }
    }

    private func testConnection() {
        sanitizeAndValidateURL()
        guard urlWarning == nil else { return }
        isTesting = true
        connectionStatus = .testing
        Task {
            do {
                let ok = try await HomeAssistantService.shared.testConnection(
                    baseURL: settings.haBaseURL, token: settings.haToken)
                connectionStatus = ok ? .success : .failure("Unexpected response")
            } catch {
                connectionStatus = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
}
