import SwiftUI
import NeosDomain

struct AccountSettingsView: View {
    let state: AppState
    @Bindable var accountVM: AccountViewModel
    let settingsVM: SettingsViewModel
    let homeVM: HomeViewModel

    @State private var showSignOutConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                Text("Settings")
                    .typography(.pageTitle)
                    .padding(.bottom, DS.Spacing.sm)

                accountSection
                servicesSection
                playbackSection
                cacheSection
                aboutSection
                diagnosticsSection
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.top, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.xxxl)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .accessibilityIdentifier(AccessibilityID.Settings.view)
    }

    // MARK: - Section Card

    private func sectionCard<Content: View>(
        header: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(header)
                .typography(.sectionHeader)

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                content()
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: DS.Radius.large))
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        sectionCard(header: "Account") {
            if let user = state.signedInUser {
                signedInView(user: user)
            } else {
                signInForm
            }
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

            Button(action: { showSignOutConfirmation = true }) {
                if accountVM.isSigningOut {
                    Spinner(size: 16, lineWidth: 2)
                } else {
                    Text("Sign Out")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(accountVM.isSigningOut)
            .accessibilityIdentifier(AccessibilityID.Settings.signOutButton)
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    accountVM.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out of your HEOS account?")
            }
        }
    }

    private var signInForm: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("Sign in with your HEOS account to access favorites and playlists across devices.")
                .typography(.secondary)

            VStack(spacing: DS.Spacing.md) {
                TextField("Email", text: $accountVM.username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .accessibilityIdentifier(AccessibilityID.Settings.emailField)

                SecureField("Password", text: $accountVM.password)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier(AccessibilityID.Settings.passwordField)
            }
            .frame(maxWidth: 360)

            Toggle("Remember me", isOn: $accountVM.rememberMe)
                .toggleStyle(.switch)
                .tint(DS.Colors.accent)
                .accessibilityIdentifier(AccessibilityID.Settings.rememberMeToggle)
                .frame(maxWidth: 360)

            if let error = accountVM.signInError {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: error.icon)
                        .foregroundStyle(errorColor(for: error))
                    Text(error.message)
                        .typography(.secondary)
                        .foregroundStyle(errorColor(for: error))
                }
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
            .controlSize(.regular)
            .disabled(accountVM.username.isEmpty || accountVM.password.isEmpty || accountVM.isSigningIn)
            .accessibilityIdentifier(AccessibilityID.Settings.signInButton)
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
        sectionCard(header: "Services") {
            if homeVM.streamingSources.isEmpty {
                Text("No services available. Connect to a speaker to see your music services.")
                    .typography(.secondary)
            } else {
                ServiceConfigView(
                    sources: homeVM.streamingSources.filter { $0.available && $0.type == "music_service" },
                    hiddenSIDs: homeVM.hiddenSIDs,
                    onToggle: { sid in homeVM.toggleServiceVisibility(sid: sid) }
                )
            }
        }
    }

    // MARK: - Playback Section

    private var playbackSection: some View {
        sectionCard(header: "Playback") {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Volume Limit")
                        .typography(.bodyMedium)
                    Text("Set a maximum volume to prevent accidentally playing too loud.")
                        .typography(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { settingsVM.volumeLimitEnabled },
                    set: { settingsVM.volumeLimitEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .tint(DS.Colors.accent)
                .labelsHidden()
                .accessibilityIdentifier(AccessibilityID.Settings.volumeLimitToggle)
            }

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
        sectionCard(header: "Cache") {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Cached Data")
                        .typography(.bodyMedium)
                    Text(settingsVM.estimatedCacheSize)
                        .typography(.secondary)
                        .accessibilityIdentifier(AccessibilityID.Settings.cacheSizeLabel)
                }

                Spacer()

                Button("Clear Cache") {
                    settingsVM.showClearCacheConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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
    }

    // MARK: - About Section

    private var aboutSection: some View {
        sectionCard(header: "About") {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Image("NeosLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 24)

                VStack(spacing: DS.Spacing.md) {
                    aboutRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        .accessibilityIdentifier(AccessibilityID.Settings.aboutVersion)

                    Divider().opacity(0.3)

                    aboutRow(label: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                        .accessibilityIdentifier(AccessibilityID.Settings.aboutBuild)
                }

                if let copyright = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String, !copyright.isEmpty {
                    Text(copyright)
                        .typography(.footnote)
                        .accessibilityIdentifier(AccessibilityID.Settings.aboutCopyright)
                }

                Divider().opacity(0.3)

                Button(action: {
                    if let url = URL(string: "https://ko-fi.com/galela") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: DS.Icons.heartFill)
                            .foregroundStyle(.pink)
                        Text("Support Neos on Ko-fi")
                            .typography(.bodyMedium)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.Settings.supportButton)
            }
        }
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .typography(.secondary)
            Spacer()
            Text(value)
                .typography(.bodyPrimary)
        }
    }

    // MARK: - Diagnostics Section

    private var diagnosticsSection: some View {
        sectionCard(header: "Diagnostics") {
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
                                        .typography(.secondaryEmphasis)
                                        .foregroundStyle(DS.Colors.accent)
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
