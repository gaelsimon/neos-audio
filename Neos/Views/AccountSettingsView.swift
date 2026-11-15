import SwiftUI
import NeosDomain

struct AccountSettingsView: View {
    let state: AppState
    @Bindable var accountVM: AccountViewModel
    let settingsVM: SettingsViewModel
    let homeVM: HomeViewModel
    let localServersVM: LocalServersViewModel

    @State private var showSignOutConfirmation = false

    var body: some View {
        Form {
            accountSection
            servicesSection
            localServersSection
            playbackSection
            cacheSection
            aboutSection
            diagnosticsSection
        }
        .settingsForm()
        .pageHeading("Settings")
        .task { await localServersVM.load() }
        .accessibilityIdentifier(AccessibilityID.Settings.view)
    }

    // MARK: - Account Section

    @ViewBuilder
    private var accountSection: some View {
        if let user = state.signedInUser {
            Section("Account") {
                signedInView(user: user)
            }
        } else {
            signInSection
        }
    }

    private func signedInView(user: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: DS.Icons.personCircleFill)
                .font(DS.IconFont.jumbo)
                .foregroundStyle(DS.Colors.accent)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(user)
                    .typography(.bodyMedium)
                    .accessibilityIdentifier(AccessibilityID.Settings.signedInUser)
                Text("HEOS Account")
                    .typography(.secondary)
            }

            Spacer()

            TextActionButton(
                title: "Sign Out",
                role: .destructive,
                isBusy: accountVM.isSigningOut,
                accessibilityID: AccessibilityID.Settings.signOutButton
            ) { showSignOutConfirmation = true }
            .disabled(accountVM.isSigningOut)
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    accountVM.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out of your HEOS account?")
            }
        }
    }

    private var signInSection: some View {
        Section {
            TextField("Email", text: $accountVM.username)
                .textContentType(.username)
                .literalTextInput(.email)
                .accessibilityIdentifier(AccessibilityID.Settings.emailField)

            SecureField("Password", text: $accountVM.password)
                .textContentType(.password)
                .accessibilityIdentifier(AccessibilityID.Settings.passwordField)

            Toggle("Remember me", isOn: $accountVM.rememberMe)
                .toggleStyle(.switch)
                .tint(DS.Colors.accent)
                .accessibilityIdentifier(AccessibilityID.Settings.rememberMeToggle)

            if let error = accountVM.signInError {
                Label(error.message, systemImage: error.icon)
                    .typography(.secondary, color: errorColor(for: error))
                    .accessibilityIdentifier(AccessibilityID.Settings.signInError)
            }

            Button(action: { accountVM.signIn() }) {
                if accountVM.isSigningIn {
                    Spinner(size: 16, lineWidth: 2)
                } else {
                    Text("Sign In")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(accountVM.username.isEmpty || accountVM.password.isEmpty || accountVM.isSigningIn)
            .accessibilityIdentifier(AccessibilityID.Settings.signInButton)
        } header: {
            Text("Account")
        } footer: {
            Text("Sign in with your HEOS account to access favorites and playlists across devices.")
        }
    }

    private func errorColor(for error: SignInErrorType) -> Color {
        switch error {
        case .authFailed: return .red
        case .networkError: return .orange
        case .timeout: return .yellow
        case .unknown: return .red
        }
    }

    // MARK: - Services Section

    private var servicesSection: some View {
        let services = MusicSource.listed(homeVM.streamingSources, signedIn: state.signedInUser != nil)
        return Section("Services") {
            if services.isEmpty {
                Text("No services available. Connect to a speaker to see your music services.")
                    .typography(.secondary)
            } else {
                ServiceConfigView(
                    sources: services,
                    hiddenSIDs: homeVM.hiddenSIDs,
                    onToggle: { sid in homeVM.toggleServiceVisibility(sid: sid) }
                )
            }
        }
    }

    // MARK: - Local Music Servers Section

    private var localServersSection: some View {
        Section("Local Music Servers") {
            if localServersVM.servers.isEmpty {
                if localServersVM.hasLoaded {
                    Text("No local music servers found.")
                        .typography(.secondary)
                }
            } else {
                LocalServerSettingsView(servers: localServersVM.servers, preferences: localServersVM.preferences)
            }
        }
    }

    // MARK: - Playback Section

    private var playbackSection: some View {
        Section("Playback") {
            Toggle(isOn: Binding(
                get: { settingsVM.volumeLimitEnabled },
                set: { settingsVM.volumeLimitEnabled = $0 }
            )) {
                Text("Volume Limit")
                Text("Set a maximum volume to prevent accidentally playing too loud.")
            }
            .toggleStyle(.switch)
            .tint(DS.Colors.accent)
            .accessibilityIdentifier(AccessibilityID.Settings.volumeLimitToggle)

            if settingsVM.volumeLimitEnabled {
                HStack(spacing: DS.Spacing.md) {
                    Slider(
                        value: Binding(
                            get: { Double(settingsVM.volumeLimitValue) },
                            set: { settingsVM.volumeLimitValue = Int($0) }
                        ),
                        in: 1...100
                    )
                    .tint(DS.Colors.accent)
                    .accessibilityIdentifier(AccessibilityID.Settings.volumeLimitSlider)

                    Text("\(settingsVM.volumeLimitValue)%")
                        .monospacedDigit()
                        .typography(.secondary)
                        .frame(width: 44, alignment: .trailing)
                        .accessibilityIdentifier(AccessibilityID.Settings.volumeLimitLabel)
                }
            }
        }
    }

    // MARK: - Cache Section

    private var cacheSection: some View {
        Section("Cache") {
            LabeledContent("Cached Data") {
                Text(settingsVM.estimatedCacheSize)
                    .accessibilityIdentifier(AccessibilityID.Settings.cacheSizeLabel)
            }

            Button("Clear Cache") {
                settingsVM.showClearCacheConfirmation = true
            }
            .accessibilityIdentifier(AccessibilityID.Settings.clearCacheButton)
            .confirmationDialog("Clear Cache", isPresented: Binding(
                get: { settingsVM.showClearCacheConfirmation },
                set: { settingsVM.showClearCacheConfirmation = $0 }
            )) {
                Button("Clear Cache", role: .destructive) {
                    settingsVM.clearCache()
                }
            } message: {
                Text("This will clear all cached metadata and diagnostics. This cannot be undone.")
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            Image("NeosLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 24)
                .accessibilityLabel("Neos")

            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                .accessibilityIdentifier(AccessibilityID.Settings.aboutVersion)

            LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                .accessibilityIdentifier(AccessibilityID.Settings.aboutBuild)

            if let update = state.availableUpdate {
                aboutLink(
                    "Neos \(update.version) is available", systemImage: DS.Icons.update, tint: DS.Colors.accent,
                    url: update.url.absoluteString, accessibilityID: AccessibilityID.Settings.updateLink
                )
            }

            // App Review rejects links to outside payment, tips included, and a repo page with a Sponsor button counts.
            #if APP_STORE
            aboutLink(
                "Neos Support", systemImage: "questionmark.circle", tint: DS.Colors.textSecondary,
                url: "https://gaelsimon.github.io/neos-audio/support.html", accessibilityID: AccessibilityID.Settings.helpButton
            )
            #else
            aboutLink(
                "Support Neos on Ko-fi", systemImage: DS.Icons.heartFill, tint: .pink,
                url: "https://ko-fi.com/galela", accessibilityID: AccessibilityID.Settings.supportButton
            )
            #endif
        } header: {
            Text("About")
        } footer: {
            if let copyright = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String, !copyright.isEmpty {
                Text(copyright)
                    .accessibilityIdentifier(AccessibilityID.Settings.aboutCopyright)
            }
        }
    }

    @ViewBuilder
    private func aboutLink(_ title: String, systemImage: String, tint: Color, url: String, accessibilityID: String) -> some View {
        if let url = URL(string: url) {
            Link(destination: url) {
                Label {
                    Text(title)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                }
            }
            .accessibilityIdentifier(accessibilityID)
        }
    }

    // MARK: - Diagnostics Section

    private var diagnosticsSection: some View {
        Section("Diagnostics") {
            if state.diagnostics.isEmpty {
                Text("No diagnostic events recorded.")
                    .typography(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        ForEach(state.diagnostics) { event in
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                HStack(spacing: DS.Spacing.sm) {
                                    Text(event.date, format: .dateTime.hour().minute().second())
                                        .typography(.footnote)
                                    Text(event.source)
                                        .typography(.secondaryEmphasis, color: DS.Colors.accent)
                                }
                                Text(event.message)
                                    .typography(.secondary)
                            }
                            if event.id != state.diagnostics.last?.id {
                                Divider().opacity(0.2)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .accessibilityIdentifier(AccessibilityID.Settings.diagnosticsList)
            }

            Button("Copy All") {
                settingsVM.copyDiagnostics()
                state.showToast("Diagnostics copied to clipboard", icon: DS.Icons.clipboard)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier(AccessibilityID.Settings.copyDiagnosticsButton)
        }
    }
}
