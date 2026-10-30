//
//  StreamValidator.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 21.10.2026.
//

import AVFoundation
import Foundation

/**
 Валидатор потоков вещания.

 Хранит очередь проверки потоков по запросам, последовательно проверяет их
 и выдаёт пути строк элементов, у которых изменилось состояние.
 */
final class StreamValidator {
    /**
     Максимальное время ожидания проверки одного потока в секундах.
     */
    private let timeout: TimeInterval
    /**
     Хранилище потоков вещания.
     */
    private let store: StreamStore
    
    /**
     Пути строк потоков с активным запросом на проверку.
     */
    private var activeRequests: Set<IndexPath> = []
    /**
     Очередь путей строк потоков для проверки.
     */
    private var validationChannel: AsyncStream<IndexPath>.Continuation?
    /**
     Пути строк, ожидающие создания очереди проверки.
     */
    private var pendingValidationIndices: Set<IndexPath> = []
    /**
     Задача последовательной проверки потоков по запросам.
     */
    private var validationLoopTask: Task<Void, Never>?
    /**
     Продолжение последовательности изменений состояния потоков.
     */
    private var changesContinuation: AsyncThrowingStream<IndexPath, any Error>.Continuation?
    /**
     Путь строки потока, проверяемого в данный момент.
     */
    private var currentValidationIndexPath: IndexPath?
    /**
     Задача проверки текущего потока.
     */
    private var currentValidationTask: Task<Void, Never>?
    /**
     Путь строки потока с приоритетной проверкой.
     */
    private var priorityValidationIndexPath: IndexPath?

    /**
     Создаёт валидатор потоков.

     - Parameter store: Хранилище потоков вещания.
     - Parameter timeout: Максимальное время ожидания проверки одного потока
       в секундах.
     */
    init(store: StreamStore, timeout: TimeInterval) {
        self.store = store
        self.timeout = timeout
    }

    /**
     Проверяет потоки по очереди запросов и выдаёт пути строк элементов, у которых
     изменилось состояние.

     Очередь проверки формируется из запросов и меняется во время работы:
     новые запросы добавляются, а отменённые удаляются. Проверяемый поток
     с отменённым запросом прерывается, и проверка переходит к следующему
     в очереди. Потоки с известным состоянием не проверяются.

     - Returns: Асинхронная последовательность индексов изменённых элементов.
     */
    func streamChanges() -> AsyncThrowingStream<IndexPath, any Error> {
        AsyncThrowingStream { continuation in
            self.changesContinuation = continuation
            let channel = AsyncStream<IndexPath> { channelContinuation in
                self.validationChannel = channelContinuation
                // выдаём индексы, накопившиеся до создания очереди
                for indexPath in self.pendingValidationIndices {
                    channelContinuation.yield(indexPath)
                }
                self.pendingValidationIndices.removeAll()
            }
            let task = Task {
                await self.validationLoop(channel)
            }
            self.validationLoopTask = task
            // отменяем проверку, если потребитель прекратил итерацию
            continuation.onTermination = { [weak self] _ in
                task.cancel()
                self?.currentValidationTask?.cancel()
            }
        }
    }
    /**
     Запрашивает проверку потока по пути строки.

     Если состояние потока ещё неизвестно, он ставится в очередь проверки.
     Для потоков с известным состоянием или с активным запросом запрос
     не создаётся.

     - Parameter indexPath: Путь строки потока.
     */
    func requestValidation(at indexPath: IndexPath) {
        guard case .unknown = self.store.stream(at: indexPath).status else { return }
        guard self.activeRequests.insert(indexPath).inserted else { return }

        if let channel = self.validationChannel {
            channel.yield(indexPath)
        } else {
            self.pendingValidationIndices.insert(indexPath)
        }
    }
    /**
     Отменяет запрос на проверку потока по пути строки.

     Поток удаляется из очереди, а если он проверялся в данный момент,
     проверка прерывается.

     - Parameter indexPath: Путь строки потока.
     */
    func cancelValidation(at indexPath: IndexPath) {
        self.activeRequests.remove(indexPath)
        if self.currentValidationIndexPath == indexPath {
            self.currentValidationTask?.cancel()
        }
    }
    /**
     Назначает поток приоритетным для проверки по пути строки.

     Текущая проверка отменяется, а её поток возвращается в очередь.
     Указанный поток проверяется следующим, остальные — после него.

     - Parameter indexPath: Путь строки потока.
     */
    func prioritizeValidation(at indexPath: IndexPath) {
        guard case .unknown = self.store.stream(at: indexPath).status else { return }

        self.priorityValidationIndexPath = indexPath
        // возвращаем прерываемый поток в очередь проверки
        if let current = self.currentValidationIndexPath, current != indexPath {
            self.validationChannel?.yield(current)
        }
        // прерываем текущую проверку, чтобы цикл перешёл к приоритетному потоку
        self.currentValidationTask?.cancel()
        // будим цикл проверки
        self.validationChannel?.yield(indexPath)
    }
    /**
     Забирает пути строк из очереди и последовательно проверяет их.

     Потоки с отменённым запросом или уже проверенные пропускаются.
     По завершении очереди последовательность закрывается.

     - Parameter channel: Очередь путей строк для проверки.
     */
    private func validationLoop(_ channel: AsyncStream<IndexPath>) async {
        for await indexPath in channel {
            // сначала проверяем приоритетный поток, если он назначен
            if let priority = self.priorityValidationIndexPath {
                self.priorityValidationIndexPath = nil
                await self.performValidationIfNeeded(at: priority)
            }
            await self.performValidationIfNeeded(at: indexPath)
        }
        self.changesContinuation?.finish()
    }
    /**
     Проверяет поток по указанному пути строки, если запрос на проверку активен
     и состояние ещё неизвестно.

     Потоки с отменённым запросом или известным состоянием пропускаются.

     - Parameter indexPath: Путь строки потока.
     */
    private func performValidationIfNeeded(at indexPath: IndexPath) async {
        guard self.activeRequests.contains(indexPath) else { return }
        guard case .unknown = self.store.stream(at: indexPath).status else { return }
        await self.performValidation(at: indexPath)
    }
    /**
     Проверяет поток по указанному пути строки и выдаёт путь строки в последовательность
     изменений при каждом изменении состояния.

     Проверка выполняется в отдельной задаче, чтобы её можно было отменить
     при отмене запроса. При отмене поток возвращается в состояние `.unknown`.

     - Parameter indexPath: Путь строки проверяемого потока.
     */
    private func performValidation(at indexPath: IndexPath) async {
        self.store.setStatus(.processing, at: indexPath)
        self.currentValidationIndexPath = indexPath
        self.changesContinuation?.yield(indexPath)

        let task = Task {
            do {
                try await AVAsset(url: self.store.stream(at: indexPath).url)
                    .validatePlayability(timeout: self.timeout)
                self.store.setStatus(.readyToPlay, at: indexPath)
            } catch is CancellationError {
                // проверка отменена — поток возвращается в состояние «не проверялся»
                self.store.setStatus(.unknown, at: indexPath)
            } catch {
                self.store.setStatus(.failed(error), at: indexPath)
            }
            self.changesContinuation?.yield(indexPath)
        }
        self.currentValidationTask = task
        await task.value
        self.currentValidationTask = nil
        self.currentValidationIndexPath = nil
    }
    
    
}
