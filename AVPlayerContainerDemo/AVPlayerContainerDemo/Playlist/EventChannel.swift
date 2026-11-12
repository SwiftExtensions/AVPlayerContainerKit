//
//  EventChannel.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 12.11.2026.
//

import Foundation

/**
 Канал событий.

 Выдаёт события в асинхронную последовательность. События, выданные до
 подписки потребителя, накапливаются и выдаются при подписке.
 */
final class EventChannel<Event> {
    /**
     Продолжение асинхронной последовательности событий.
     */
    private var continuation: AsyncStream<Event>.Continuation?
    /**
     События, выданные до подписки потребителя.
     */
    private var pendingEvents: [Event] = []

    /**
     Возвращает асинхронную последовательность событий.
     */
    func stream() -> AsyncStream<Event> {
        AsyncStream { continuation in
            self.continuation = continuation
            // выдаём события, накопившиеся до подписки потребителя
            let pendingEvents = self.pendingEvents
            self.pendingEvents.removeAll()
            for event in pendingEvents {
                continuation.yield(event)
            }
        }
    }
    /**
     Выдаёт событие в последовательность.

     События, выданные до подписки потребителя, накапливаются.

     - Parameter event: Событие.
     */
    func emit(_ event: Event) {
        if let continuation {
            continuation.yield(event)
        } else {
            // потребитель ещё не подписался — накапливаем
            self.pendingEvents.append(event)
        }
    }


}


