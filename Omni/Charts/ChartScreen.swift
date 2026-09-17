import SwiftUI
import CoreLocation

/// Optional integration surface. It remains hidden until a permitted endpoint is configured.
struct ChartScreen: View {
    static var isAvailable: Bool { ChartEndpoint.url != nil }

    @Environment(\.dismiss) private var dismiss
    @State private var birthClock = Date(timeIntervalSince1970: 962107200)
    @State private var knowsTime = false
    @State private var placeQuery = ""
    @State private var candidates: [ChartBirthplace] = []
    @State private var birthplace: ChartBirthplace?
    @State private var consent = false
    @State private var occurrence = -1
    @State private var needsOccurrence = false
    @State private var isSearching = false
    @State private var isCalculating = false
    @State private var errorMessage: String?
    @State private var chart: ChartResult?
    @State private var searchTask: Task<Void, Never>?
    @State private var chartTask: Task<Void, Never>?
    @State private var geocoder = CLGeocoder()

    private let utc = TimeZone(secondsFromGMT: 0)!
    private var canCalculate: Bool {
        knowsTime && birthplace != nil && consent && !isCalculating && ChartScreen.isAvailable
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "YOUR SYMBOLIC CHART", title: "A little context.\nYour choices, always.", subtitle: "Explore calculated sky positions and Four Pillars. Their meanings are a tradition for reflection, not a prediction of your life.")
                    if ChartScreen.isAvailable {
                        birthDetails
                        locationDetails
                        sharingDetails
                        if let errorMessage {
                            OmniCard(color: OmniTheme.peach) {
                                Label("Something needs attention", systemImage: "exclamationmark.circle")
                                    .font(.headline)
                                Text(errorMessage).font(.subheadline).textSelection(.enabled)
                            }.accessibilityIdentifier("chart.error")
                        }
                        OmniButton(title: isCalculating ? "Calculating your chart…" : "Calculate my chart", icon: "sparkles") { calculate() }
                            .disabled(!canCalculate).opacity(canCalculate ? 1 : 0.5)
                            .accessibilityIdentifier("chart.calculate")
                        if isCalculating { ProgressView("Resolving time and chart positions").font(.caption) }
                        if let chart { ChartResultView(chart: chart) }
                    } else {
                        OmniCard { Text("Chart calculations aren't connected in this version.") }
                    }
                }.padding(24)
            }
            .background(OmniTheme.paper)
            .foregroundStyle(OmniTheme.ink)
            .navigationTitle("Your chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .onChange(of: birthClock) { _, _ in invalidateChart() }
            .onChange(of: knowsTime) { _, _ in invalidateChart() }
            .onChange(of: occurrence) { _, _ in chart = nil; consent = false }
            .onDisappear {
                searchTask?.cancel()
                chartTask?.cancel()
                geocoder.cancelGeocode()
                chart = nil
                consent = false
                isSearching = false
                isCalculating = false
            }
        }
    }

    private var birthDetails: some View {
        OmniCard {
            Eyebrow(text: "1 · YOUR BIRTH RECORD")
            DatePicker("Birth date", selection: $birthClock,
                       in: Date(timeIntervalSince1970: -2208988800)...Date().addingTimeInterval(86400),
                       displayedComponents: .date)
                .environment(\.timeZone, utc)
                .environment(\.calendar, Calendar(identifier: .gregorian))
            Toggle("I know my recorded birth time", isOn: $knowsTime)
                .accessibilityIdentifier("chart.knowsTime")
            if knowsTime {
                DatePicker("Local birth time", selection: $birthClock, displayedComponents: .hourAndMinute)
                    .environment(\.timeZone, utc)
                    .environment(\.calendar, Calendar(identifier: .gregorian))
                Text("Enter the clock time recorded at your birthplace. We'll resolve its historical timezone and daylight saving time.")
                    .font(.caption).foregroundStyle(OmniTheme.muted)
            } else {
                Text("An exact time is needed for the rising sign, houses and hour pillar. Come back when you have it.")
                    .font(.caption).foregroundStyle(OmniTheme.muted)
            }
            if needsOccurrence {
                Picker("Clock-change occurrence", selection: $occurrence) {
                    Text("Choose from birth record").tag(-1)
                    Text("First occurrence").tag(0)
                    Text("Second occurrence").tag(1)
                }
                Text("On this date the clock repeated an hour. Choose only if your birth record or another reliable source identifies which occurrence.")
                    .font(.caption).foregroundStyle(OmniTheme.muted)
            }
        }.disabled(isCalculating)
    }

    private var locationDetails: some View {
        OmniCard {
            Eyebrow(text: "2 · YOUR BIRTHPLACE")
            TextField("City and country, or hospital address", text: $placeQuery)
                .textContentType(.fullStreetAddress)
                .submitLabel(.search)
                .padding(14).background(OmniTheme.paper, in: RoundedRectangle(cornerRadius: 12))
                .onSubmit { searchBirthplace() }
                .onChange(of: placeQuery) { _, _ in
                    searchTask?.cancel()
                    geocoder.cancelGeocode()
                    isSearching = false
                    candidates = []
                    birthplace = nil
                    invalidateChart()
                }
                .accessibilityIdentifier("chart.birthplace")
            Text("Find birthplace sends this search to Apple's location service. Your birth date and time aren't part of that search. Use a hospital address for more precise coordinates.")
                .font(.caption).foregroundStyle(OmniTheme.muted)
            Button { searchBirthplace() } label: {
                Label(isSearching ? "Finding places…" : "Find birthplace", systemImage: "magnifyingglass")
                    .frame(minHeight: 44)
            }
            .disabled(isSearching || placeQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
            if isSearching { ProgressView() }
            ForEach(candidates) { candidate in
                Button {
                    birthplace = candidate
                    invalidateChart()
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(candidate.name).font(.subheadline.weight(.medium))
                            Text(candidate.timezone.identifier).font(.caption)
                            Text(candidate.coordinateLabel).font(.caption2).foregroundStyle(OmniTheme.muted)
                        }
                        Spacer()
                        Image(systemName: birthplace?.id == candidate.id ? "checkmark.circle.fill" : "circle")
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(OmniTheme.sage.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).accessibilityAddTraits(birthplace?.id == candidate.id ? .isSelected : [])
            }
            if let birthplace {
                Label("Selected: \(birthplace.name)", systemImage: "checkmark.circle").font(.caption)
            }
        }.disabled(isCalculating)
    }

    private var sharingDetails: some View {
        OmniCard(color: OmniTheme.sage) {
            Eyebrow(text: "3 · CHOOSE WHAT YOU SHARE")
            Text("This calculation uses a server.").font(OmniTheme.title(23))
            Text("If you continue, your birth date, recorded time, birthplace coordinates and timezone will be sent to \(ChartEndpoint.url?.host ?? "the chart service"). Your name and journal entries aren't included.")
                .font(.subheadline).lineSpacing(3)
            Text("The result stays in memory while this page is open. The current calculation service does not store birth records; it is a private prototype.")
                .font(.caption).foregroundStyle(OmniTheme.muted)
            Toggle("I agree to send these birth details for this calculation", isOn: $consent)
                .font(.subheadline).accessibilityIdentifier("chart.consent")
            #if DEBUG
            Text("Development connection · no customer account authentication is integrated.")
                .font(.caption2).foregroundStyle(OmniTheme.muted)
            #endif
        }.disabled(isCalculating)
    }

    private func invalidateChart() {
        chart = nil
        consent = false
        errorMessage = nil
        needsOccurrence = false
        occurrence = -1
    }

    private func searchBirthplace() {
        let query = placeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 3, !isSearching, !isCalculating else { return }
        searchTask?.cancel()
        geocoder.cancelGeocode()
        candidates = []
        birthplace = nil
        invalidateChart()
        isSearching = true
        searchTask = Task { @MainActor in
            do {
                let placemarks = try await geocoder.geocodeAddressString(query, in: nil, preferredLocale: Locale(identifier: "en_US"))
                guard !Task.isCancelled else { return }
                candidates = placemarks.compactMap(ChartBirthplace.init)
                if candidates.isEmpty {
                    errorMessage = "No place with a reliable timezone was found. Try the city, state and country, or a more specific address."
                }
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = "We couldn't find that birthplace. Check your connection and try a city, state and country."
            }
            isSearching = false
        }
    }

    private func calculate() {
        guard canCalculate, let birthplace, let endpoint = ChartEndpoint.url else { return }
        let birthString = ChartDates.format(birthClock, timezone: utc, pattern: "yyyy-MM-dd'T'HH:mm:00")
        let localNow = ChartDates.format(Date(), timezone: birthplace.timezone, pattern: "yyyy-MM-dd'T'HH:mm:ss")
        guard birthString <= localNow else {
            errorMessage = "Your birth date and time must be in the past at your selected birthplace."
            return
        }
        if needsOccurrence && occurrence < 0 {
            errorMessage = "This time occurred twice. Select the occurrence from your birth record before calculating again."
            return
        }
        let payload = ChartPayload(
            birthTime: birthString,
            timezone: birthplace.timezone.identifier,
            longitude: birthplace.longitude,
            latitude: birthplace.latitude,
            fold: occurrence < 0 ? nil : occurrence,
            targetDate: ChartDates.format(Date(), timezone: birthplace.timezone, pattern: "yyyy-MM-dd")
        )
        chart = nil
        errorMessage = nil
        isCalculating = true
        chartTask = Task { @MainActor in
            do {
                let result = try await ChartTransport.calculate(payload, endpoint: endpoint)
                guard !Task.isCancelled else { return }
                chart = result
            } catch let issue as ChartRequestError {
                guard !Task.isCancelled else { return }
                errorMessage = issue.localizedDescription
                if issue.isAmbiguousTime { needsOccurrence = true }
            } catch {
                guard !Task.isCancelled else { return }
                if let networkError = error as? URLError, networkError.code == .timedOut {
                    errorMessage = "The chart service took too long. Your entries are still here; try again."
                } else if error is DecodingError {
                    errorMessage = "The chart service returned a result this version can't read. Please try again after the service is updated."
                } else {
                    errorMessage = "We couldn't reach the chart service. Check your connection and try again."
                }
            }
            consent = false
            isCalculating = false
        }
    }
}

private struct ChartBirthplace: Identifiable {
    let id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
    let timezone: TimeZone

    init?(_ placemark: CLPlacemark) {
        guard let coordinate = placemark.location?.coordinate, let timezone = placemark.timeZone else { return nil }
        let parts = [placemark.name, placemark.locality, placemark.administrativeArea, placemark.country].compactMap { $0 }
        var unique: [String] = []
        for part in parts where !unique.contains(part) { unique.append(part) }
        self.name = unique.joined(separator: ", ")
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.timezone = timezone
    }

    var coordinateLabel: String { String(format: "%.4f°, %.4f°", latitude, longitude) }
}

private enum ChartDates {
    static func format(_ date: Date, timezone: TimeZone, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

private enum ChartEndpoint {
    static var url: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "OMNI_CHART_API_URL") as? String,
              let components = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              let url = components.url else { return nil }
        if components.scheme?.lowercased() == "https" { return url }
        #if DEBUG
        if components.scheme?.lowercased() == "http", ["localhost", "127.0.0.1"].contains(host.lowercased()) { return url }
        #endif
        return nil
    }
}

private struct ChartPayload: Encodable {
    let birthTime: String
    let timezone: String
    let longitude: Double
    let latitude: Double
    let fold: Int?
    let targetDate: String
    let solarTimeMethod = "apparent"
    let dayBoundary = "midnight"
    // No sex parameter is inferred: traditional Da Yun remains unavailable.
}

private struct ChartRequestError: LocalizedError {
    let message: String
    var isAmbiguousTime = false
    var errorDescription: String? { message }
}

private final class ChartNoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private enum ChartTransport {
    static func calculate(_ payload: ChartPayload, endpoint: URL) async throws -> ChartResult {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 35
        let session = URLSession(configuration: configuration, delegate: ChartNoRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: endpoint.appendingPathComponent("v1/charts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ChartRequestError(message: "The chart service didn't return a valid response.")
        }
        if response.statusCode == 401 || response.statusCode == 403 {
            throw ChartRequestError(message: "This chart service requires an authenticated connection that isn't integrated in this version. Your chart wasn't calculated.")
        }
        if response.statusCode == 422 {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String ?? ""
            if detail.contains("occurred twice") {
                throw ChartRequestError(message: "The clock repeated this birth time during a timezone change. Choose the first or second occurrence from your birth record below.", isAmbiguousTime: true)
            }
            if detail.contains("did not exist") {
                throw ChartRequestError(message: "This recorded time falls in an hour skipped by a clock change. Please check the original record; we won't silently shift your birth time.")
            }
            throw ChartRequestError(message: "The service couldn't accept these birth details. Check the recorded date, time, birthplace and timezone (supported years: 1900–2100).")
        }
        guard response.statusCode == 200, data.count < 1_000_000 else {
            throw ChartRequestError(message: "The chart service is unavailable right now. Please try again later.")
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try decoder.decode(ChartResult.self, from: data)
        guard result.schemaVersion == "1.0" else {
            throw ChartRequestError(message: "This chart format needs a newer version of the app.")
        }
        return result
    }
}

private struct ChartResult: Decodable {
    let schemaVersion: String
    let time: ChartTime
    let east: East
    let west: West
    let style: Style

    struct ChartTime: Decodable {
        let utc: String
        let localMeanTime: String
        let localApparentTime: String
        let equationOfTimeSeconds: Double
        let method: String
        let precisionNote: String
    }
    struct East: Decodable {
        let dayMaster: DayMaster
        let pillars: [Pillar]
        let beneficialElements: BeneficialElements
        let conventions: Conventions
    }
    struct DayMaster: Decodable { let stem: String; let pinyin: String; let element: String; let polarity: String }
    struct Pillar: Decodable, Identifiable {
        let name: String
        let ganzhi: String
        let stemElement: String
        let branchElement: String
        var id: String { name }
    }
    struct BeneficialElements: Decodable { let status: String; let reason: String }
    struct Conventions: Decodable { let yearMonthBoundary: String; let dayBoundary: String; let hourStem: String }
    struct West: Decodable {
        let planets: [Planet]
        let angles: Angles
        let houseStatus: String
        let houseNote: String?
        let ephemeris: Ephemeris
    }
    struct Planet: Decodable, Identifiable {
        let name: String
        let sign: String
        let degreeInSign: Double
        let retrograde: Bool
        var id: String { name }
        var label: String { name.replacingOccurrences(of: "_", with: " ").capitalized }
    }
    struct Angle: Decodable { let sign: String; let degreeInSign: Double }
    struct Angles: Decodable { let ascendant: Angle?; let midheaven: Angle? }
    struct Ephemeris: Decodable { let status: String; let note: String; let fallbackBodies: [String] }
    struct Style: Decodable { let element: String; let colors: [String]; let prompt: String; let basis: String }
}

private struct ChartResultView: View {
    let chart: ChartResult
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Divider()
            PageHeading(eyebrow: "YOUR CALCULATED CHART", title: "Symbols to explore.", subtitle: "Calculated from your birth record. No personality score or fate prediction is attached.")
            if chart.west.ephemeris.status != "swiss" {
                OmniCard(color: OmniTheme.peach) {
                    Label("Ephemeris precision note", systemImage: "info.circle").font(.headline)
                    Text("This server used the built-in Moshier model for some positions because Swiss data files weren't available. The chart is calculated; it is not the Swiss-file precision tier.").font(.subheadline)
                }
            }
            OmniCard {
                Eyebrow(text: "FOUR PILLARS · BA ZI")
                Text("\(chart.east.dayMaster.pinyin) \(chart.east.dayMaster.stem) · \(chart.east.dayMaster.polarity.capitalized) \(chart.east.dayMaster.element.capitalized)")
                    .font(OmniTheme.title(25))
                Text("Your day master is the heavenly stem of the day pillar.").font(.caption).foregroundStyle(OmniTheme.muted)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], alignment: .leading, spacing: 15) {
                    ForEach(chart.east.pillars) { pillar in
                        VStack(alignment: .leading, spacing: 7) {
                            Eyebrow(text: pillar.name)
                            Text(pillar.ganzhi).font(.system(size: 30, weight: .medium, design: .serif))
                            Text("\(pillar.stemElement.capitalized) · \(pillar.branchElement.capitalized)").font(.caption)
                        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(OmniTheme.sage, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                Text("A beneficial element (Xi/Yong Shen) requires a defined interpretive method. We don't infer one by counting missing elements.")
                    .font(.caption).foregroundStyle(OmniTheme.muted)
            }
            OmniCard {
                Eyebrow(text: "THE SKY · TROPICAL ZODIAC")
                if let rising = chart.west.angles.ascendant {
                    Text("\(rising.sign) rising · \(rising.degreeInSign, specifier: "%.1f")°").font(OmniTheme.title(25))
                }
                if chart.west.houseStatus != "calculated" {
                    Label("Houses unavailable", systemImage: "info.circle").font(.headline)
                    Text(chart.west.houseNote ?? "Placidus houses couldn't be calculated for this location and time.").font(.caption).foregroundStyle(OmniTheme.muted)
                }
                ForEach(chart.west.planets) { planet in
                    HStack(alignment: .firstTextBaseline) {
                        Text(planet.label).font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(planet.sign) \(planet.degreeInSign, specifier: "%.1f")°\(planet.retrograde ? " · Rx" : "")")
                            .font(.subheadline).multilineTextAlignment(.trailing)
                    }
                }
                Text("Rx marks apparent retrograde motion. The north node uses the true-node method. Houses use Placidus when available.")
                    .font(.caption).foregroundStyle(OmniTheme.muted)
            }
            OmniCard(color: OmniTheme.sage) {
                Eyebrow(text: "A CREATIVE STYLE THEME")
                Text(chart.style.colors.map { $0.capitalized }.joined(separator: " + ")).font(OmniTheme.title(25))
                Text(chart.style.prompt).font(.subheadline).lineSpacing(4)
                Text(chart.style.basis).font(.caption).foregroundStyle(OmniTheme.muted)
            }
            OmniCard {
                DisclosureGroup("How this was calculated") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Birth instant (UTC): \(chart.time.utc)")
                        Text("Local mean time: \(chart.time.localMeanTime)")
                        Text("Apparent solar time: \(chart.time.localApparentTime)")
                        Text("Equation of time: \(chart.time.equationOfTimeSeconds, specifier: "%.1f") seconds")
                        Text(chart.time.method)
                        Text(chart.east.conventions.yearMonthBoundary)
                        Text("Day pillar changes at midnight. \(chart.east.conventions.hourStem)")
                        Text(chart.time.precisionNote)
                        Text(chart.west.ephemeris.note)
                    }.font(.caption).foregroundStyle(OmniTheme.muted).textSelection(.enabled).padding(.top, 12)
                }
            }
        }.accessibilityIdentifier("chart.result")
    }
}
