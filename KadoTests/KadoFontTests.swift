import Testing
import KadoCore

@Suite("KadoFont")
struct KadoFontTests {
    @Test("register() is safe to call repeatedly")
    func registerIdempotent() {
        KadoFont.register()
        KadoFont.register()
        KadoFont.register()
    }
}
