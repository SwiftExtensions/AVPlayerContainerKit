//
//  SubscribersTests.swift
//  AVPlayerContainerDemoTests
//
//  Created by Александр Алгашев on 19.11.2026.
//

import XCTest

/**
 Тесты реестра подписчиков `Subscribers`.
 */
final class SubscribersTests: XCTestCase {
    /**
     Проверяет, что `subscribe` возвращает токен с переданным значением.
     */
    func testSubscribeReturnsTokenWithValue() {
        var subscribers = Subscribers<String>()

        let token = subscribers.subscribe("avatar")

        XCTAssertEqual(token.value, "avatar")
    }
    /**
     Проверяет, что снятие подписки возвращает `false`, пока у значения
     остаются другие подписчики.
     */
    func testUnsubscribeReturnsFalseWhileOthersRemain() {
        var subscribers = Subscribers<String>()
        let first = subscribers.subscribe("avatar")
        let second = subscribers.subscribe("avatar")

        XCTAssertFalse(subscribers.unsubscribe(first))
        XCTAssertTrue(subscribers.unsubscribe(second))
    }
    /**
     Проверяет, что подписки на разные значения учитываются раздельно:
     отписка последнего подписчика одного значения не зависит от другого.
     */
    func testUnsubscribeCountsValuesSeparately() {
        var subscribers = Subscribers<String>()
        let avatar = subscribers.subscribe("avatar")
        subscribers.subscribe("cover")

        XCTAssertTrue(subscribers.unsubscribe(avatar))
    }
    /**
     Проверяет, что повторное снятие одного токена — пустая операция.
     */
    func testUnsubscribeTwiceReturnsFalse() {
        var subscribers = Subscribers<String>()
        let token = subscribers.subscribe("avatar")

        XCTAssertTrue(subscribers.unsubscribe(token))
        XCTAssertFalse(subscribers.unsubscribe(token))
    }
    /**
     Проверяет, что токен чужого реестра ничего не снимает.
     */
    func testUnsubscribeForeignTokenReturnsFalse() {
        var subscribers = Subscribers<String>()
        var others = Subscribers<String>()
        let foreign = others.subscribe("avatar")
        subscribers.subscribe("avatar")

        XCTAssertFalse(subscribers.unsubscribe(foreign))
    }
    /**
     Проверяет, что `removeAll` снимает все подписки на значение:
     отписка снятых токенов больше ничего не меняет.
     */
    func testRemoveAllClearsSubscribers() {
        var subscribers = Subscribers<String>()
        let first = subscribers.subscribe("avatar")
        let second = subscribers.subscribe("avatar")

        subscribers.removeAll(for: "avatar")

        XCTAssertFalse(subscribers.unsubscribe(first))
        XCTAssertFalse(subscribers.unsubscribe(second))
    }
    /**
     Проверяет, что после `removeAll` значение снова принимает подписки.
     */
    func testSubscribeWorksAfterRemoveAll() {
        var subscribers = Subscribers<String>()
        subscribers.subscribe("avatar")
        subscribers.removeAll(for: "avatar")

        let token = subscribers.subscribe("avatar")

        XCTAssertTrue(subscribers.unsubscribe(token))
    }


}

