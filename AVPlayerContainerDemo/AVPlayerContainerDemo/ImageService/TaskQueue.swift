//
//  TaskQueue.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 19.11.2026.
//

import Foundation

/**
 Очередь задач с ограничением числа одновременных выполнений.

 Оркестрирует выполнение асинхронных операций: свободное место есть —
 операция запускается сразу, мест нет — запрос встаёт в очередь и ждёт,
 пока одна из выполняющихся операций завершится. Очередь обслуживается
 в порядке поступления запросов. Ограничение `.unlimited` выполняет
 все операции сразу, без очереди.

 Отмена вызывающей задачи во время ожидания снимает запрос из очереди:
 его операция не запускается.

 Актор: состояние очереди изменяется многими задачами одновременно,
 поэтому доступ к нему сериализован изоляцией актора.

 Пример ограничения загрузок до трёх одновременных:

     let queue = TaskQueue(limit: 3)

     let image = try await queue.run {
         try await loadImage(from: url)
     }

 Пример очереди без ограничений: все операции выполняются сразу.

     let queue = TaskQueue(limit: .unlimited)
 */
actor TaskQueue {
    /**
     Ограничение числа одновременно выполняющихся операций.
     */
    enum Limit: Sendable {
        /**
         Без ограничения: каждая операция выполняется сразу,
         очередь не используется.
         */
        case unlimited
        /**
         Ограничение числом одновременно выполняющихся операций.

         Операции сверх лимита ожидают в очереди.
         */
        case limited(Int)
        
        
    }

    
    /**
     Максимальное число одновременно выполняющихся операций.

     `nil` — без ограничения: запросы выполняются сразу.
     */
    private let maxConcurrentTasks: Int?
    /**
     Число занятых мест: операции выполняются или место передано
     ожидающему запросу.
     */
    private var runningTasksCount = 0
    /**
     Идентификаторы ожидающих запросов в порядке поступления.
     */
    private var queuedRequests: [UUID] = []
    /**
     Продолжения ожидающих запросов по их идентификаторам.
     */
    private var waiters: [UUID: CheckedContinuation<Void, any Error>] = [:]
    /**
     Флаг наличия свободного места для выполнения операции.
     */
    private var hasFreeTaskSlot: Bool {
        guard let maxConcurrentTasks else { return true }
        return self.runningTasksCount < maxConcurrentTasks
    }

    /**
     Создаёт очередь задач.

     - Parameter limit: Ограничение числа одновременно выполняющихся
       операций. Значения `.limited` меньше единицы приводятся к единице.
     */
    init(limit: Limit) {
        switch limit {
        case .unlimited:
            self.maxConcurrentTasks = nil
        case .limited(let count):
            self.maxConcurrentTasks = max(1, count)
        }
    }
    /**
     Создаёт очередь задач с численным ограничением.

     - Parameter limit: Максимальное число одновременно выполняющихся
       операций. Значения меньше единицы приводятся к единице.
     */
    init(limit: Int) {
        self.init(limit: .limited(limit))
    }

    /**
     Выполняет операцию, когда для неё освободится место.

     Операции запускаются в порядке поступления запросов. Отмена
     вызывающей задачи во время ожидания снимает запрос из очереди
     с ошибкой `CancellationError`: операция не запускается.

     Пример параллельной загрузки изображений не более четырёх
     одновременно:

         let queue = TaskQueue(limit: 4)

         try await withThrowingTaskGroup(of: Void.self) { group in
             for url in urls {
                 group.addTask {
                     _ = try await queue.run { try await loadImage(from: url) }
                 }
             }
             try await group.waitForAll()
         }

     - Parameter operation: Операция для выполнения.
     - Returns: Результат операции.
     - Throws: Ошибка операции или `CancellationError` при отмене
       ожидания.
     */
    func run<Success: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Success
    ) async throws -> Success {
        try await self.wait()
        defer { self.signal() }
        // запрос мог быть отменён сразу после передачи места
        try Task.checkCancellation()
        return try await operation()
    }
    /**
     Занимает свободное место или ожидает его освобождения.

     Возврат из метода означает, что место занято запросом: его
     обязательно освободить вызовом `signal`.

     - Throws: `CancellationError`, если ожидание в очереди отменено.
     */
    private func wait() async throws {
        try Task.checkCancellation()
        if self.hasFreeTaskSlot {
            self.runningTasksCount += 1
            return
        }
        let request = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.waiters[request] = continuation
                self.queuedRequests.append(request)
            }
        } onCancel: {
            Task { await self.cancelWaiting(request) }
        }
    }
    /**
     Освобождает занятое место.

     Место передаётся первому ожидающему запросу в очереди. Очередь
     пуста — число занятых мест уменьшается.
     */
    private func signal() {
        while let request = self.queuedRequests.first {
            self.queuedRequests.removeFirst()
            // запрос мог быть отменён за время ожидания
            guard let waiter = self.waiters.removeValue(forKey: request) else { continue }
            waiter.resume()
            return
        }
        self.runningTasksCount -= 1
    }
    /**
     Снимает запрос с ожидания в очереди.

     - Parameter request: Идентификатор ожидающего запроса.
     */
    private func cancelWaiting(_ request: UUID) {
        guard let waiter = self.waiters.removeValue(forKey: request) else { return }
        self.queuedRequests.removeAll { $0 == request }
        waiter.resume(throwing: CancellationError())
    }


}

