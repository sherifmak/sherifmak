import XCTest
@testable import WhoopTamagotchi

final class WhoopModelsTests: XCTestCase {

    // MARK: - CycleResponse Decoding

    func testDecodeScoredCycle() throws {
        let json = """
        {
          "records": [
            {
              "id": 93845,
              "user_id": 10129,
              "created_at": "2022-04-24T11:25:44.774Z",
              "updated_at": "2022-04-24T14:25:44.774Z",
              "start": "2022-04-24T02:25:44.774Z",
              "end": "2022-04-24T10:25:44.774Z",
              "timezone_offset": "-05:00",
              "score_state": "SCORED",
              "score": {
                "strain": 14.2,
                "kilojoule": 8288.297,
                "average_heart_rate": 68,
                "max_heart_rate": 141
              }
            }
          ],
          "next_token": "MTIzOjEyMzEyMw"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CycleResponse.self, from: json)

        XCTAssertEqual(response.records.count, 1)
        XCTAssertEqual(response.nextToken, "MTIzOjEyMzEyMw")

        let cycle = response.records[0]
        XCTAssertEqual(cycle.id, 93845)
        XCTAssertEqual(cycle.userId, 10129)
        XCTAssertEqual(cycle.scoreState, "SCORED")
        XCTAssertEqual(cycle.start, "2022-04-24T02:25:44.774Z")
        XCTAssertEqual(cycle.end, "2022-04-24T10:25:44.774Z")
        XCTAssertEqual(cycle.timezoneOffset, "-05:00")
        XCTAssertEqual(cycle.createdAt, "2022-04-24T11:25:44.774Z")

        let score = try XCTUnwrap(cycle.score)
        XCTAssertEqual(score.strain, 14.2)
        XCTAssertEqual(score.kilojoule, 8288.297)
        XCTAssertEqual(score.averageHeartRate, 68)
        XCTAssertEqual(score.maxHeartRate, 141)
    }

    func testDecodePendingScoreCycle() throws {
        let json = """
        {
          "records": [
            {
              "id": 99999,
              "user_id": 10129,
              "created_at": "2022-04-24T11:25:44.774Z",
              "updated_at": "2022-04-24T14:25:44.774Z",
              "start": "2022-04-24T02:25:44.774Z",
              "end": null,
              "timezone_offset": "-05:00",
              "score_state": "PENDING_SCORE",
              "score": null
            }
          ],
          "next_token": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CycleResponse.self, from: json)

        let cycle = response.records[0]
        XCTAssertEqual(cycle.scoreState, "PENDING_SCORE")
        XCTAssertNil(cycle.score)
        XCTAssertNil(cycle.end)
        XCTAssertNil(response.nextToken)
    }

    func testDecodeUnscorableCycle() throws {
        let json = """
        {
          "records": [
            {
              "id": 88888,
              "user_id": 10129,
              "created_at": "2022-04-24T11:25:44.774Z",
              "updated_at": "2022-04-24T14:25:44.774Z",
              "start": "2022-04-24T02:25:44.774Z",
              "end": "2022-04-24T10:25:44.774Z",
              "timezone_offset": "-05:00",
              "score_state": "UNSCORABLE",
              "score": null
            }
          ],
          "next_token": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CycleResponse.self, from: json)

        let cycle = response.records[0]
        XCTAssertEqual(cycle.scoreState, "UNSCORABLE")
        XCTAssertNil(cycle.score)
    }

    func testDecodeEmptyRecords() throws {
        let json = """
        {
          "records": [],
          "next_token": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CycleResponse.self, from: json)
        XCTAssertTrue(response.records.isEmpty)
    }

    // MARK: - CycleScore Edge Values

    func testDecodeZeroStrain() throws {
        let json = """
        {
          "strain": 0.0,
          "kilojoule": 0.0,
          "average_heart_rate": 55,
          "max_heart_rate": 60
        }
        """.data(using: .utf8)!

        let score = try JSONDecoder().decode(CycleScore.self, from: json)
        XCTAssertEqual(score.strain, 0.0)
    }

    func testDecodeMaxStrain() throws {
        let json = """
        {
          "strain": 21.0,
          "kilojoule": 15000.0,
          "average_heart_rate": 120,
          "max_heart_rate": 200
        }
        """.data(using: .utf8)!

        let score = try JSONDecoder().decode(CycleScore.self, from: json)
        XCTAssertEqual(score.strain, 21.0)
    }

    func testDecodeHighPrecisionStrain() throws {
        let json = """
        {
          "strain": 5.2951527,
          "kilojoule": 8288.297,
          "average_heart_rate": 68,
          "max_heart_rate": 141
        }
        """.data(using: .utf8)!

        let score = try JSONDecoder().decode(CycleScore.self, from: json)
        XCTAssertEqual(score.strain, 5.2951527, accuracy: 0.0000001)
    }

    // MARK: - WebhookEvent Decoding

    func testDecodeWebhookEvent() throws {
        let json = """
        {
          "user_id": 456,
          "id": 12345,
          "type": "workout.updated",
          "timestamp": "2024-01-15T08:00:00.000Z"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(WebhookEvent.self, from: json)
        XCTAssertEqual(event.userId, 456)
        XCTAssertEqual(event.id, 12345)
        XCTAssertEqual(event.type, "workout.updated")
    }
}
