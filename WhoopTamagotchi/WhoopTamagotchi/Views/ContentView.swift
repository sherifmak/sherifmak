import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if viewModel.isLoggedIn {
                    loggedInView
                } else {
                    loginView
                }
            }
            .padding()
            .navigationTitle("Whoop Tamagotchi")
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    // MARK: - Logged In View

    private var loggedInView: some View {
        VStack(spacing: 24) {
            TamagotchiAnimatedCharacter(
                strainLevel: viewModel.strainLevel,
                strain: viewModel.strain
            )
            .scaleEffect(1.8)
            .frame(height: 200)

            VStack(spacing: 8) {
                Text("Today's Strain")
                    .font(.headline)
                Text(String(format: "%.1f", viewModel.strain))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text(viewModel.strainLevel.label)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            if viewModel.isLoading {
                ProgressView("Fetching strain...")
            }

            Button("Refresh") {
                Task { await viewModel.fetchStrain() }
            }
            .buttonStyle(.borderedProminent)

            Spacer()

            Button("Sign Out", role: .destructive) {
                viewModel.signOut()
            }
            .font(.footnote)
        }
        .task {
            await viewModel.fetchStrain()
        }
    }

    // MARK: - Login View

    private var loginView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                TamagotchiAnimatedCharacter(strainLevel: .light, strain: 5.0)
                    .scaleEffect(1.5)
                    .frame(height: 160)

                Text("Meet your Tamagotchi!")
                    .font(.title2.bold())

                Text("Connect your WHOOP to bring your Tamagotchi to life. It'll react to your daily strain in real time.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: { viewModel.startOAuth() }) {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("Connect WHOOP")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .padding(.horizontal)

            Spacer()
        }
        .onOpenURL { url in
            viewModel.handleCallback(url: url)
        }
    }
}

// MARK: - View Model

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var strain: Double = 0.0
    @Published var strainLevel: StrainLevel = .resting
    @Published var showError = false
    @Published var errorMessage = ""

    private var oauthState: String?
    private let api = WhoopAPIClient.shared

    init() {
        isLoggedIn = OAuthTokens.load() != nil
        if let state = TamagotchiState.load() {
            strain = state.strain
            strainLevel = state.strainLevel
        }
    }

    func startOAuth() {
        let state = UUID().uuidString
        oauthState = state
        guard let url = api.authorizationURL(state: state) else { return }
        UIApplication.shared.open(url)
    }

    func handleCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let state = components.queryItems?.first(where: { $0.name == "state" })?.value,
              state == oauthState else {
            showErrorAlert("Authentication failed. Please try again.")
            return
        }

        Task {
            do {
                _ = try await api.exchangeCodeForTokens(code: code)
                isLoggedIn = true
                await fetchStrain()
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                showErrorAlert("Failed to connect WHOOP: \(error.localizedDescription)")
            }
        }
    }

    func fetchStrain() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let value = try await api.fetchTodayStrain()
            strain = value
            strainLevel = StrainLevel.from(strain: value)
        } catch let error as WhoopAPIError where error == .notAuthenticated {
            isLoggedIn = false
            showErrorAlert("Your session expired. Please sign in again.")
        } catch {
            showErrorAlert("Could not fetch strain: \(error.localizedDescription)")
        }
    }

    func signOut() {
        OAuthTokens.delete()
        isLoggedIn = false
        strain = 0
        strainLevel = .resting
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
    }
}
