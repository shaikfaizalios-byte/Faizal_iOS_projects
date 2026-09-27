import XCTest
@testable import MiniWallet

final class MoneyTests: XCTestCase {

    func test_userInput_parsesWholeRupees() {
        XCTAssertEqual(Money(userInput: "250")?.minorUnits, 25_000)
    }

    func test_userInput_parsesPaise() {
        XCTAssertEqual(Money(userInput: "250.75")?.minorUnits, 25_075)
    }

    func test_userInput_padsSingleDecimalDigit() {
        XCTAssertEqual(Money(userInput: "250.5")?.minorUnits, 25_050)
    }

    func test_userInput_stripsThousandsSeparators() {
        XCTAssertEqual(Money(userInput: "1,250.50")?.minorUnits, 1_25_050)
    }

    func test_userInput_rejectsMoreThanTwoDecimalPlaces() {
        XCTAssertNil(Money(userInput: "10.123"))
    }

    func test_userInput_rejectsNegativeAndGarbage() {
        XCTAssertNil(Money(userInput: "-10"))
        XCTAssertNil(Money(userInput: "abc"))
        XCTAssertNil(Money(userInput: ""))
        XCTAssertNil(Money(userInput: "1.2.3"))
    }

    func test_userInput_rejectsOverflowingAmountRatherThanTrapping() {
        XCTAssertNil(Money(userInput: "99999999999999999999"))
    }

    func test_arithmetic_isExact() {
        let a = Money(userInput: "0.10")!
        let b = Money(userInput: "0.20")!
        // The reason money is integer minor units: this is exactly 30 paise.
        XCTAssertEqual(a.adding(b).minorUnits, 30)
    }
}
