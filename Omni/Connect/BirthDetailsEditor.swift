import SwiftUI
import CoreLocation

/// Reused by private invitations and opt-in discovery. Never guesses a birth time.
struct BirthDetailsEditor: View {
    @Binding var time: String?
    @Binding var zone: String?
    @Binding var place: String?
    @Binding var longitude: Double?
    @Binding var fold: Int?
    @State private var query = ""
    @State private var searching = false
    @State private var error: String?
    @State private var choices: [CLPlacemark] = []
    @State private var geocoder = CLGeocoder()
    private var known: Binding<Bool> { Binding(get: { time != nil }, set: { time = $0 ? "12:00" : nil; fold = nil }) }
    private var clock: Binding<Date> {
        Binding(get: { Self.format.date(from: time ?? "12:00") ?? .now }, set: { time = Self.format.string(from: $0) })
    }
    private static var format: DateFormatter { let f = DateFormatter(); f.dateFormat = "HH:mm"; f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); return f }
    var body: some View {
        Toggle("I know my birth time", isOn: known)
        if time != nil {
            DatePicker("Birth time", selection: clock, displayedComponents: .hourAndMinute).environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            TextField("Birth city, state or country", text: $query)
            Button(searching ? "Finding city…" : "Find birth city") { Task { await search() } }.disabled(searching || query.trimmingCharacters(in: .whitespaces).isEmpty)
            ForEach(Array(choices.enumerated()), id: \.offset) { _, item in
                Button(Self.title(item)) {
                    guard let location = item.location, let timezone = item.timeZone else { return }
                    place = Self.title(item); longitude = location.coordinate.longitude; zone = timezone.identifier; choices = []; error = nil
                }
            }
            if let place, let zone { Label(place, systemImage: "checkmark.circle"); Text(zone.replacingOccurrences(of: "_", with: " ")).font(.caption) }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            DisclosureGroup("If your birth time occurred twice") {
                Picker("Clock-change occurrence", selection: Binding(get: { fold ?? -1 }, set: { fold = $0 == -1 ? nil : $0 })) {
                    Text("Not applicable / not sure").tag(-1); Text("First occurrence").tag(0); Text("Second occurrence").tag(1)
                }
                Text("Only needed if clocks went back at your exact birth time.").font(.caption)
            }
        }
        Text("Omni calculates five elements from your birth details. Unknown times are left out. Birth city sets historical time zone and mean solar time; your exact birth details are never shown to another person.").font(.caption)
        Text("City search uses Apple's place lookup. No device location access is requested.").font(.caption).foregroundStyle(.secondary)
    }
    private func search() async {
        searching = true; error = nil; defer { searching = false }
        do {
            choices = try await geocoder.geocodeAddressString(query, in: nil, preferredLocale: Locale(identifier: "en_US")).filter { $0.location != nil && $0.timeZone != nil }
            if choices.isEmpty { error = "City not found. Try adding the state and country." }
        } catch { self.error = "Could not find this city. Please try again." }
    }
    private static func title(_ p: CLPlacemark) -> String { [p.locality ?? p.name, p.administrativeArea, p.country].compactMap { $0 }.joined(separator: ", ") }
}
