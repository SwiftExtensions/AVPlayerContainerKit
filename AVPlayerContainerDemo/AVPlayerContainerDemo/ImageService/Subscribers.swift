//
//  Subscribers.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 19.11.2026.
//

import Foundation

/**
 Реестр подписчиков по значениям.

 Учитывает, сколько активных запросов приходится на каждое значение:
 `subscribe` выдаёт токен запроса, `unsubscribe` снимает его. Токен
 хранит и значение, и идентификатор — при отписке ничего дополнительно
 передавать не нужно.

 Значимый тип: изоляцию состояния обеспечивает владелец реестра.

 Пример учёта запросов, делящих общий ресурс значения:

     var subscribers = Subscribers<URL>()

     // два запроса одного и того же изображения
     let first = subscribers.subscribe(url)
     let second = subscribers.subscribe(url)

     subscribers.unsubscribe(first)   // false — второй ещё ждёт
     subscribers.unsubscribe(second)  // true — подписчиков не осталось
 */
struct Subscribers<Value: Hashable & Sendable>: Sendable {
    /**
     Токен подписки на значение.

     Создаётся только в `subscribe` и служит для снятия подписки.
     */
    struct Token: Sendable {
        /**
         Идентификатор подписки.
         */
        fileprivate let id: UUID
        /**
         Значение подписки.
         */
        let value: Value
        
        
    }
    
    
    /**
     Идентификаторы активных подписок по значениям.
     */
    private var values: [Value: Set<UUID>] = [:]

    /**
     Регистрирует подписку на значение и возвращает её токен.

     - Parameter value: Значение подписки.
     - Returns: Токен для снятия подписки.
     */
    mutating func subscribe(_ value: Value) -> Token {
        let token = Token(id: UUID(), value: value)
        self.values[value, default: []].insert(token.id)
        return token
    }
    /**
     Снимает подписку по токену.

     Повторное снятие того же токена — пустая операция.

     Возвращённое значение удобно для решения, освобождать ли общий
     ресурс значения:

         if subscribers.unsubscribe(token) {
             // подписчиков не осталось — ресурс можно освободить
             loadingTasks[token.value]?.cancel()
         }

     - Parameter token: Токен подписки.
     - Returns: `true`, если у значения не осталось подписок.
     */
    @discardableResult
    mutating func unsubscribe(_ token: Token) -> Bool {
        guard self.values[token.value]?.remove(token.id) != nil else { return false }
        guard self.values[token.value]?.isEmpty != false else { return false }

        self.values[token.value] = nil
        return true
    }
    /**
     Снимает все подписки на значение.

     - Parameter value: Значение подписки.
     */
    mutating func removeAll(for value: Value) {
        self.values[value] = nil
    }


}

