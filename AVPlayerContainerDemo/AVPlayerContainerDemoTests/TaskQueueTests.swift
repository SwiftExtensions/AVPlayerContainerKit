//
//  TaskQueueTests.swift
//  AVPlayerContainerDemoTests
//
//  Created by Александр Алгашев on 19.11.2026.
//

import XCTest

/**
 Тесты очереди задач `TaskQueue`.

 Файл `TaskQueue.swift` собирается непосредственно в тестовый таргет,
 поэтому тип доступен без импорта модуля приложения.
 */
final class TaskQueueTests: XCTestCase {
    /**
     Наблюдатель за выполнением операций.

     Считает число выполняющихся операций, их максимум и порядок
     запуска. `waitForRunningCount` позволяет дождаться занятия мест
     без фиксированных задержек.
     */
    private actor Observer {
        /**
         Число выполняющихся операций.
         */
        private(set) var runningCount = 0
        /**
         Максимум одновременно выполнявшихся операций.
         */
        private(set) var maxRunningCount = 0
        /**
         Запуски операций в порядке поступления.
         */
        private(set) var events: [Int] = []
        /**
         Число запущенных задач.

         Запущенная задача, не занявшая место, находится в очереди —
         по счётчику можно подтвердить постановку в очередь.
         */
        private(set) var startedCount = 0
        /**
         Продолжения ожиданий числа выполняющихся операций.
         */
        private var countWaiters: [(
            count: Int,
            continuation: CheckedContinuation<Void, Never>
        )] = []
        /**
         Продолжения ожиданий числа запущенных задач.
         */
        private var startedWaiters: [(
            count: Int,
            continuation: CheckedContinuation<Void, Never>
        )] = []

        /**
         Отмечает запуск задачи.
         */
        func start() {
            self.startedCount += 1
            self.wakeWaiters(&self.startedWaiters, reached: self.startedCount)
        }
        /**
         Отмечает начало выполнения операции.
         */
        func enter() {
            self.runningCount += 1
            self.maxRunningCount = max(self.maxRunningCount, self.runningCount)
            self.wakeWaiters(&self.countWaiters, reached: self.runningCount)
        }
        /**
         Отмечает завершение операции.
         */
        func leave() {
            self.runningCount -= 1
        }
        /**
         Записывает запуск операции в порядок событий.

         - Parameter event: Идентификатор операции.
         */
        func record(_ event: Int) {
            self.events.append(event)
        }
        /**
         Ждёт, пока число выполняющихся операций достигнет значения.

         - Parameter count: Число выполняющихся операций.
         */
        func waitForRunningCount(_ count: Int) async {
            if self.runningCount >= count { return }
            await withCheckedContinuation {
                self.countWaiters.append((count: count, continuation: $0))
            }
        }
        /**
         Ждёт, пока число запущенных задач достигнет значения.

         - Parameter count: Число запущенных задач.
         */
        func waitForStartedCount(_ count: Int) async {
            if self.startedCount >= count { return }
            await withCheckedContinuation {
                self.startedWaiters.append((count: count, continuation: $0))
            }
        }
        /**
         Будит ожидания, чьё число достигнуто.

         - Parameter waiters: Список ожиданий с их целевыми значениями.
         */
        private func wakeWaiters(
            _ waiters: inout [(
                count: Int,
                continuation: CheckedContinuation<Void, Never>
            )],
            reached count: Int
        ) {
            let ready = waiters.filter { $0.count <= count }
            waiters.removeAll { $0.count <= count }
            for waiter in ready {
                waiter.continuation.resume()
            }
        }
    }
    /**
     Ожидание, открываемое из теста.

     Блокирует операции в очереди, пока тест не вызовет `open`.
     */
    private actor Gate {
        private var isOpen = false
        private var continuations: [CheckedContinuation<Void, Never>] = []

        /**
         Ждёт открытия.
         */
        func wait() async {
            if self.isOpen { return }
            await withCheckedContinuation {
                self.continuations.append($0)
            }
        }
        /**
         Открывает ожидание и будит всех ждущих.
         */
        func open() {
            self.isOpen = true
            for continuation in self.continuations {
                continuation.resume()
            }
            self.continuations.removeAll()
        }
    }
    /**
     Ошибка для проверки проброса ошибок операции.
     */
    private struct TestError: Error {}

    /**
     Результат операции возвращается вызывающему.
     */
    func testRunReturnsResult() async throws {
        let queue = TaskQueue(limit: 1)
        let result = try await queue.run { 42 }
        XCTAssertEqual(result, 42)
    }
    /**
     Ошибка операции пробрасывается вызывающему.
     */
    func testRunRethrowsOperationError() async {
        let queue = TaskQueue(limit: 1)
        do {
            let _: Int = try await queue.run { throw TestError() }
            XCTFail("Ожидалась ошибка операции")
        } catch is TestError {} catch {
            XCTFail("Ожидалась TestError, получена \(error)")
        }
    }
    /**
     Число одновременных выполнений не превышает ограничение.

     Операции заблокированы ожиданием, поэтому четвёртая не смогла бы
     начаться незамеченной: запуск сверх лимита задержкой проявился бы
     в счётчиках наблюдателя.
     */
    func testConcurrentRunsDoNotExceedLimit() async throws {
        let queue = TaskQueue(limit: 3)
        let gate = Gate()
        let observer = Observer()
        var tasks: [Task<Void, any Error>] = []
        for _ in 0..<5 {
            let task = Task {
                try await queue.run {
                    await observer.enter()
                    await gate.wait()
                    await observer.leave()
                }
            }
            tasks.append(task)
        }

        await observer.waitForRunningCount(3)
        // запуск сверх лимита успел бы проявиться за эту паузу
        try await Task.sleep(nanoseconds: 50_000_000)
        let runningCount = await observer.runningCount
        let maxRunningCount = await observer.maxRunningCount
        XCTAssertEqual(runningCount, 3)
        XCTAssertEqual(maxRunningCount, 3)

        await gate.open()
        for task in tasks {
            try await task.value
        }
    }
    /**
     Ожидающие запросы запускаются в порядке поступления.

     Единственное место занято заблокированной операцией. Каждая
     следующая задача создаётся, только когда предыдущая запустилась:
     место занято, значит её запрос уже в очереди, и порядок запуска
     должен совпасть с порядком создания.
     */
    func testQueuedRunsStartInOrder() async throws {
        let queue = TaskQueue(limit: 1)
        let gate = Gate()
        let observer = Observer()
        let blocker = Task {
            try await queue.run {
                await observer.enter()
                await gate.wait()
            }
        }
        await observer.waitForRunningCount(1)

        var tasks: [Task<Void, any Error>] = []
        for index in 0..<4 {
            let task = Task {
                await observer.start()
                try await queue.run {
                    await observer.record(index)
                }
            }
            tasks.append(task)
            // ждём запуска задачи: место занято, значит её запрос уже
            // в очереди или встаёт прямо сейчас — yield даёт ему встать
            await observer.waitForStartedCount(index + 1)
            await Task.yield()
        }

        await gate.open()
        try await blocker.value
        for task in tasks {
            try await task.value
        }
        let events = await observer.events
        XCTAssertEqual(events, [0, 1, 2, 3])
    }
    /**
     Отмена ожидающего запроса не запускает его операцию.

     Запрос отменяется в очереди: после освобождения места операция
     не выполняется, а вызывающий получает `CancellationError`.
     */
    func testCancelledQueuedRunDoesNotExecute() async throws {
        let queue = TaskQueue(limit: 1)
        let gate = Gate()
        let observer = Observer()
        let blocker = Task {
            try await queue.run {
                await observer.enter()
                await gate.wait()
            }
        }
        await observer.waitForRunningCount(1)

        let queued = Task {
            await observer.start()
            try await queue.run {
                await observer.record(1)
            }
        }
        // дожидаемся запуска задачи: место занято, её запрос в очереди
        await observer.waitForStartedCount(1)
        queued.cancel()
        await gate.open()

        try await blocker.value
        do {
            try await queued.value
            XCTFail("Ожидалась отмена ожидающего запроса")
        } catch is CancellationError {} catch {
            XCTFail("Ожидалась CancellationError, получена \(error)")
        }
        let events = await observer.events
        XCTAssertTrue(events.isEmpty)
    }
    /**
     Ограничение `.unlimited` выполняет все операции сразу.

     Все пять операций должны выполняться одновременно, что
     подтверждается числом занятых мест.
     */
    func testUnlimitedRunsAllOperations() async throws {
        let queue = TaskQueue(limit: .unlimited)
        let gate = Gate()
        let observer = Observer()
        var tasks: [Task<Void, any Error>] = []
        for _ in 0..<5 {
            let task = Task {
                try await queue.run {
                    await observer.enter()
                    await gate.wait()
                    await observer.leave()
                }
            }
            tasks.append(task)
        }

        await observer.waitForRunningCount(5)
        let maxRunningCount = await observer.maxRunningCount
        XCTAssertEqual(maxRunningCount, 5)

        await gate.open()
        for task in tasks {
            try await task.value
        }
    }


}

