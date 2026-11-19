//
//  TestHelpers.swift
//  AVPlayerContainerDemoTests
//
//  Created by Александр Алгашев on 19.11.2026.
//

import Foundation

/**
 Наблюдатель за выполнением операций.

 Считает число выполняющихся операций, их максимум и порядок
 запуска. `waitForRunningCount` и `waitForStartedCount` позволяют
 дождаться нужного состояния без фиксированных задержек.
 */
actor Observer {
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
actor Gate {
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
struct TestError: Error {}

