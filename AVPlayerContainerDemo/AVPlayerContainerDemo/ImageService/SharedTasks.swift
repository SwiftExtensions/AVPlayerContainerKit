//
//  SharedTasks.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 19.11.2026.
//

import Foundation

/**
 Пул задач, общих для одинаковых ключей.

 Запросы с одинаковым ключом делят одну задачу: операция по ключу
 выполняется не более одного раза одновременно. Каждый запрос —
 отдельная подписка: отмена вызывающей задачи снимает ожидание
 только этого запроса, общая задача отменяется, когда ключ теряет
 последнего подписчика.

 Одновременные операции ограничены очередью: свободное место есть —
 задача выполняет ключ сразу, мест нет — ждёт в очереди.

 Актор: словарь задач и реестр подписок изменяются многими задачами
 одновременно, поэтому доступ к ним сериализован изоляцией актора.

 Пример пула загрузок изображений с дедупликацией по адресу:

     let images = SharedTasks(
         taskQueue: TaskQueue(limit: 10),
         operation: loadImage
     )

     // оба запроса делят одну задачу загрузки
     async let first = images.value(for: url)
     async let second = images.value(for: url)
 */
actor SharedTasks<Key: Hashable & Sendable, Success: Sendable> {
    /**
     Задачи по ключам.
     */
    private var tasks: [Key: Task<Success, any Error>] = [:]
    /**
     Реестр подписок на ключи.

     Пока у ключа есть хотя бы один активный запрос, его задача
     не отменяется: отмена запроса снимает ожидание только этого
     запроса.
     */
    private var subscribers = Subscribers<Key>()
    /**
     Очередь задач.

     Ограничивает число одновременных операций: сверх лимита задачи
     ожидают свободного места в порядке поступления.
     */
    private let taskQueue: TaskQueue
    /**
     Операция, выполняемая задачей по ключу.
     */
    private let operation: @Sendable (Key) async throws -> Success

    /**
     Создаёт пул общих задач.

     - Parameter taskQueue: Очередь задач: ограничивает число
       одновременно выполняющихся операций.
     - Parameter operation: Операция, выполняемая задачей по ключу.
     */
    init(
        taskQueue: TaskQueue,
        operation: @escaping @Sendable (Key) async throws -> Success
    ) {
        self.taskQueue = taskQueue
        self.operation = operation
    }

    /**
     Возвращает результат задачи по ключу.

     Каждый вызов — отдельный запрос: задачи с тем же ключом делят
     результат, а отмена вызывающей задачи снимает ожидание только
     этого запроса.

     - Parameter key: Ключ задачи.
     - Returns: Результат операции по ключу.
     - Throws: Ошибка операции или `CancellationError` при отмене
       последнего запроса ключа.
     */
    func value(for key: Key) async throws -> Success {
        try Task.checkCancellation()
        let subscription = self.subscribers.subscribe(key)
        defer { self.unsubscribe(subscription) }

        return try await withTaskCancellationHandler {
            try await self.task(for: key).value
        } onCancel: {
            Task { await self.unsubscribe(subscription) }
        }
    }
    /**
     Возвращает задачу для ключа.

     Если задача с этим ключом уже выполняется, возвращается
     существующая. Иначе создаётся новая: сама операция проходит
     через очередь, которая запускает её при наличии свободного места.

     - Parameter key: Ключ задачи.
     - Returns: Задача по ключу.
     */
    private func task(for key: Key) -> Task<Success, any Error> {
        if let task = self.tasks[key] {
            return task
        }
        let task = Task<Success, any Error> {
            try await self.taskQueue.run {
                try await self.operation(key)
            }
        }
        self.tasks[key] = task
        // завершение задачи освобождает её запись
        Task { await self.finishTask(task, for: key) }
        return task
    }
    /**
     Снимает запрос с задачи.

     Когда у ключа не остаётся активных запросов, его задача
     отменяется: довыполнять никому не нужную операцию незачем.
     Отмена задачи, ожидающей место в очереди, снимает её с ожидания.

     - Parameter subscription: Токен подписки на ключ.
     */
    private func unsubscribe(_ subscription: Subscribers<Key>.Token) {
        guard self.subscribers.unsubscribe(subscription) else { return }
        self.tasks[subscription.value]?.cancel()
    }
    /**
     Убирает запись завершившейся задачи.

     - Parameter task: Завершившаяся задача.
     - Parameter key: Ключ задачи.
     */
    private func finishTask(_ task: Task<Success, any Error>, for key: Key) async {
        _ = await task.result
        // запись могли заменить новой задачей с тем же ключом — её не трогаем
        guard self.tasks[key] == task else { return }
        self.tasks[key] = nil
        self.subscribers.removeAll(for: key)
    }


}

