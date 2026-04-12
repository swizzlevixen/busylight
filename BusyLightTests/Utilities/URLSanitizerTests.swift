import Testing
@testable import BusyLight

struct URLSanitizerTests {

    // MARK: - Sanitize

    @Test func sanitizeTrimsWhitespace() {
        #expect(URLSanitizer.sanitize("  http://ha.local:8123  ") == "http://ha.local:8123")
    }

    @Test func sanitizeStripsTrailingSlashes() {
        #expect(URLSanitizer.sanitize("http://ha.local:8123/") == "http://ha.local:8123")
        #expect(URLSanitizer.sanitize("http://ha.local:8123///") == "http://ha.local:8123")
    }

    @Test func sanitizePrependsSchemeWhenMissing() {
        #expect(URLSanitizer.sanitize("homeassistant.local:8123") == "http://homeassistant.local:8123")
    }

    @Test func sanitizePreservesHTTPS() {
        #expect(URLSanitizer.sanitize("https://ha.local:8123") == "https://ha.local:8123")
    }

    @Test func sanitizePreservesHTTPSCaseInsensitive() {
        #expect(URLSanitizer.sanitize("HTTPS://ha.local:8123") == "HTTPS://ha.local:8123")
    }

    @Test func sanitizeHandlesEmptyString() {
        #expect(URLSanitizer.sanitize("") == "")
    }

    @Test func sanitizeHandlesWhitespaceOnly() {
        #expect(URLSanitizer.sanitize("   ") == "")
    }

    @Test func sanitizeCombinesAllFixes() {
        // Whitespace + no scheme + trailing slash
        #expect(URLSanitizer.sanitize("  ha.local:8123/  ") == "http://ha.local:8123")
    }

    @Test func sanitizePreservesPath() {
        #expect(URLSanitizer.sanitize("http://ha.local:8123/path") == "http://ha.local:8123/path")
    }

    // MARK: - Validation

    @Test func validURLPasses() {
        #expect(URLSanitizer.isValid("http://ha.local:8123"))
    }

    @Test func emptyStringIsInvalid() {
        #expect(!URLSanitizer.isValid(""))
    }

    @Test func schemeOnlyIsInvalid() {
        #expect(!URLSanitizer.isValid("http://"))
    }

    @Test func validHTTPSPasses() {
        #expect(URLSanitizer.isValid("https://homeassistant.example.com"))
    }
}
