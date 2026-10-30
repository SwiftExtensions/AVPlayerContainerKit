//
//  Group.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 23.10.2026.
//

/**
 Группа потоков вещания в плейлисте.

 Потоки, объединённые заголовком группы из атрибута `group-title`
 строки `#EXTINF`.
 */
struct Group {
    /**
     Заголовок группы. `nil` для потоков без группы.
     */
    let title: String?
    /**
     Потоки вещания группы.
     */
    var streams: [Stream]


}
