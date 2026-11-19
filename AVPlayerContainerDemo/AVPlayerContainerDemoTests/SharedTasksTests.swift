//
//  SharedTasksTests.swift
//  AVPlayerContainerDemoTests
//
//  Created by Александр Алгашев on 19.11.2026.
//

import XCTest

/**
 Тесты пула общих задач `SharedTasks`.

 Файл `SharedTasks.swift` собирается непосредственно в тестовый
 таргет, поэтому тип доступен без импорта модуля приложения.
 */
final class SharedTasksTests: XCTestCase {
    /**
     Результат операции по ключу возвращается вызывающему.
     */
    func testValueReturnsResult() async throws {
        let tasks = SharedTasks(
            taskQueue: TaskQueue(limit: 1),
            operation: { (_: String) in 42 }
        )
        let result = try await tasks.value(for: "answer")
        XCTAssertEqual(result, 42)
    }
    /**
     Ошибка операции пробрасывается вызывающему.
     */
    func testValueRethrowsOperationError() async {
        let tasks = SharedTasks(
            taskQueue: TaskQueue(limit: 1),
            operation: { (_: String) -> Int in throw TestError() }
        )
        do {
            let _: Int = try await tasks.value(for: "answer")
            XCTFail("Ожидалась ошибка операции")
        } catch is TestError {} catch {
            XCTFail("Ожидалась TestError, получена \(error)")
        }
    }
    /**
     Запросы с одинаковым ключом делят одну задачу.

     Три запроса одного ключа при заблокированной операции: операция
     выполняется один раз, все три получают её результат.
     */
    func testSameKeySharesOneTask() async throws {
        let gate = Gate()
        let observer = Observer()
        let tasks = SharedTasks(
            taskQueue: TaskQueue(limit: .unlimited),
            operation: { (_: Int) -> Int in
                await observer.enter()
                await gate.wait()
                await observer.leave()
                return 42
            }
        )
        var requests: [Task<Int, any Error>] = []
        for _ in 0..<3 {
            let request = Task {
                await observer.start()
                return try await tasks.value(for: 7)
            }
            requests.append(request)
        }

        // все запросы запущены, операция по ключу выполняется одна
        await observer.waitForStartedCount(3)
        await observer.waitForRunningCount(1)
        await gate.open()

        for request in requests {
            let value = try await request.value
            XCTAssertEqual(value, 42)
        }
        let maxRunningCount = await observer.maxRunningCount
        XCTAssertEqual(maxRunningCount, 1)
    }
    /**
     Запросы с разными ключами делить нечего: каждому — своя задача.
     */
    func testDifferentKeysRunSeparateTasks() async throws {
        let gate = Gate()
        let observer = Observer()
        let tasks = SharedTasks(
            taskQueue: TaskQueue(limit: .unlimited),
            operation: { (key: Int) -> Int in
                await observer.enter()
                await gate.wait()
                await observer.leave()
                return key
            }
        )
        let first = Task { try await tasks.value(for: 1) }
        let second = Task { try await tasks.value(for: 2) }

        await observer.waitForRunningCount(2)
        await gate.open()

        let values = try await [first.value, second.value]
        XCTAssertEqual(values, [1, 2])
    }
    /**
     Отмена одного запроса не отменяет общую задачу.

     Два запроса делят задачу: отмена первого снимает только его
     подписку, второй получает результат.
     */
    func testCancelledRequestLeavesSharedTaskAlive() async throws {
        let gate = Gate()
        let observer = Observer()
        let tasks = SharedTasks(
            taskQueue: TaskQueue(limit: .unlimited),
            operation: { (_: Int) -> Int in
                await observer.enter()
                await gate.wait()
                await observer.leave()
                return 42
            }
        )
        let cancelled = Task {
            await observer.start()
            return try await tasks.value(for: 7)
        }
        let staying = Task {
            await observer.start()
            return try await tasks.value(for: 7)
        }
        // оба запроса подписались на общую задачу
        await observer.waitForStartedCount(2)
        await observer.waitForRunningCount(1)
        await Task.yield()

        cancelled.cancel()
        await gate.open()

        let value = try await staying.value
        XCTAssertEqual(value, 42)
        // отменённый запрос дождался разделяемого результата:
        // подписка снята, но обёртка честно ждёт задачу
        _ = try? await cancelled.value
    }
    /**
     Отмена последнего запроса отменяет общую задачу.

     Операция заблокирована ожиданием, поэтому отмена гарантированно
     приходит, пока задача ещё выполняется: после открытия ожидания
     операция видит отмену и завершается ошибкой.
     */
    func testCancellingLastRequestCancelsTask() async throws {
        let gate = Gate()
        let observer = Observer()
        let tasks = SharedTasks(
            taskQueue: TaskQueue(limit: 1),
            operation: { (_: Int) -> Int in
                await observer.enter()
                await gate.wait()
                do {
                    try Task.checkCancellation()
                } catch {
                    await observer.record(-1)
                    throw error
                }
                return 42
            }
        )
        let cancelled = Task {
            return try await tasks.value(for: 7)
        }
        // операция по ключу запустилась и ждёт — подписка оформлена
        await observer.waitForRunningCount(1)
        cancelled.cancel()
        await gate.open()

        do {
            let _ = try await cancelled.value
            XCTFail("Ожидалась отмена последнего запроса")
        } catch is CancellationError {} catch {
            XCTFail("Ожидалась CancellationError, получена \(error)")
        }
        let events = await observer.events
        XCTAssertEqual(events, [-1])
    }
    /**
     Число одновременных операций ограничено очередью пула.

     Четыре ключа при лимите два: операции сверх лимита ждут места.
     */
    func testOperationsDoNotExceedQueueLimit() async throws {
        let gate = Gate()
        let observer = Observer()
        let tasks = SharedTasks(
            taskQueue: TaskQueue(limit: 2),
            operation: { (key: Int) -> Int in
                await observer.enter()
                await gate.wait()
                await observer.leave()
                return key
            }
        )
        var requests: [Task<Int, any Error>] = []
        for key in 0..<4 {
            requests.append(Task { try await tasks.value(for: key) })
        }

        await observer.waitForRunningCount(2)
        // запуск сверх лимита успел бы проявиться за эту паузу
        try await Task.sleep(nanoseconds: 50_000_000)
        let maxRunningCount = await observer.maxRunningCount
        XCTAssertEqual(maxRunningCount, 2)

        await gate.open()
        for request in requests {
            _ = try await request.value
        }
    }
    /**
     Завершившаяся задача освобождает ключ.

     Повторный запрос после завершения выполняет операцию заново:
     каждый запуск операции отмечается в событиях.
     */
    func testFinishedTaskLetsKeyRunAgain() async throws {
        let observer = Observer()
        let tasks = SharedTasks(
            taskQueue: TaskQueue(limit: 1),
            operation: { (key: Int) -> Int in
                await observer.record(key)
                return 42
            }
        )
        let first = try await tasks.value(for: 7)
        // дожидаемся уборки записи завершившейся задачи
        try await Task.sleep(nanoseconds: 50_000_000)
        let second = try await tasks.value(for: 7)

        XCTAssertEqual(first, 42)
        XCTAssertEqual(second, 42)
        let events = await observer.events
        XCTAssertEqual(events, [7, 7])
    }


}

