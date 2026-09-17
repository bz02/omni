# Optional native chart integration

`Omni/Charts/ChartScreen.swift` is the optional SwiftUI interface for the local `backend/` calculation service. Present `ChartScreen()` in a sheet; it owns a NavigationStack and Close control. Only expose its entry when `ChartScreen.isAvailable` is true.

## Configuration

Add the **base URL** to the app's generated Info.plist with the build setting `INFOPLIST_KEY_OMNI_CHART_API_URL`. The client appends `/v1/charts`.

- Release accepts only HTTPS, without URL credentials, query parameters or fragments.
- Debug additionally accepts HTTP with host `127.0.0.1` or `localhost`, for an iOS Simulator reaching the Mac backend. Example base: `http://127.0.0.1:8000`.
- Missing or invalid configuration makes `ChartScreen.isAvailable` false.
- If local App Transport Security blocks the development connection, configure a narrowly scoped local-network exception in the Debug target; do not disable ATS for release.
- No endpoint has been enabled in the checked-in app configuration by this integration. Root app code decides where to offer the entry.

The endpoint value is an address, never a token. There is deliberately no shared bearer secret or API key in this screen. The backend's local loopback mode works for simulator development. Its remote authentication gate will return 401/403 until proper user authentication is integrated. HTTPS alone does not make this prototype ready for customer traffic.

## Data flow and consent

1. User explicitly confirms knowledge of their recorded birth time. Date/time pickers use a neutral Gregorian clock so a DST gap is not silently normalized before sending it to the backend.
2. User enters a birth city or hospital address and taps **Find birthplace**. `CLGeocoder` sends only this search to Apple; location permissions and current GPS are not used. A candidate must contain coordinates and a timezone, and the user selects it explicitly.
3. The consent toggle is off initially and whenever birth inputs change. It identifies the calculation server and birth fields being sent. No profile name, journal entry, sex assumption or other app data is included.
4. The client sends a POST using an ephemeral URLSession with no cache or cookies. Redirects are refused to avoid forwarding birth details to a different endpoint. Request/resource deadlines are 25/35 seconds.
5. The calculated response stays in view memory and is cleared when the screen closes. Work is cancelled when leaving. No chart or birth details are written to UserDefaults, documents or analytics.

Birth times after the current time at the selected birthplace are rejected. The API handles DST gaps/overlaps; overlaps expose a first/second occurrence picker without guessing. Authentication, timeouts, invalid service responses and unavailable polar Placidus houses have explicit messages. The result preserves the Moshier fallback warning and calculation conventions, and does not invent a beneficial element, personality score or prediction.

## Launch dependencies

Before enabling a production endpoint, resolve the Swiss Ephemeris/pyswisseph license plan described in `backend/README.md`, add short-lived per-user authenticated requests and server-side authorization/rate limits, publish an accurate privacy policy and retention/deletion process, and complete device/network/locale/DST integration QA. The consent text currently describes the supplied non-persisting private prototype; update it if the server's actual behavior changes.

Apple references: [CLGeocoder](https://developer.apple.com/documentation/corelocation/clgeocoder), [ephemeral URLSession configuration](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/ephemeral).
