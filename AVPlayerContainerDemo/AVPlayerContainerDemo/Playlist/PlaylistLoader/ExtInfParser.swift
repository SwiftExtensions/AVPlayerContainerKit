//
//  ExtInfParser.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 23.10.2026.
//

import Foundation

/**
 Парсер строки `#EXTINF` плейлиста в формате M3U.

 Разбирает строку за один проход по символам: извлекает длительность,
 пары «ключ — значение» атрибутов и название канала.
 */
struct ExtInfParser {
    /**
     Разбирает строку `#EXTINF`.

     Разделителем названия считается первая запятая вне кавычек.

     - Parameter line: Строка плейлиста.
     - Returns: Разобранная строка `#EXTINF`, либо `nil`, если в строке нет
       запятой-разделителя.
     */
    func parse(_ line: String) -> ExtInf? {
        var index = line.index(line.startIndex, offsetBy: "#EXTINF:".count)
        // длительность — от конца префикса до первого пробела
        let durationStart = index
        while index < line.endIndex, line[index] != " " {
            index = line.index(after: index)
        }
        let duration = line[durationStart..<index]

        let (attributes, title) = self.parseAttributes(line, from: index)

        guard let title else { return nil }
        return ExtInf(
            title: String(title),
            duration: String(duration),
            attributes: attributes
        )
    }
    /**
     Разбирает атрибуты «ключ — значение» и находит название канала.

     Значения могут быть заключены в кавычки. Разделителем названия считается
     первая запятая вне кавычек.

     - Parameter line: Строка плейлиста.
     - Parameter start: Индекс, с которого начинается разбор атрибутов.
     - Returns: Кортеж со словарём атрибутов и названием канала после
       запятой-разделителя. Название равно `nil`, если разделитель не найден.
     */
    private func parseAttributes(
        _ line: String,
        from start: String.Index
    ) -> (attributes: [String: String], title: Substring?) {
        var attributes: [String: String] = [:]
        var key = ""
        var value = ""
        var isReadingValue = false
        var isInsideQuotes = false
        var title: Substring?

        var index = start
        while index < line.endIndex, title == nil {
            let character = line[index]
            if isInsideQuotes {
                if character == "\"" {
                    // кавычка закрыла значение: пара готова
                    attributes[key] = value
                    key = ""
                    value = ""
                    isReadingValue = false
                    isInsideQuotes = false
                } else {
                    value.append(character)
                }
            } else {
                switch character {
                case "\"":
                    isReadingValue = true
                    isInsideQuotes = true
                case "=":
                    isReadingValue = true
                case ",":
                    // первая запятая вне кавычек — начало названия
                    title = line[line.index(after: index)...]
                case " ":
                    break
                default:
                    if isReadingValue {
                        value.append(character)
                    } else {
                        key.append(character)
                    }
                }
            }
            index = line.index(after: index)
        }

        return (attributes, title)
    }


}
