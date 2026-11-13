//
//  PlaylistFilter.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 12.11.2026.
//

import Foundation

/**
 Фильтр плейлиста.

 Определяет, какие потоки видны в таблице: при включённой настройке
 «скрывать нерабочие потоки» из групп исключаются потоки с ошибкой,
 а опустевшие группы не отображаются.
 */
final class PlaylistFilter {
    /**
     Настройки отображения плейлиста.
     */
    private var settings: Settings
    /**
     Путь строки потока-исключения.

     Такой поток не скрывается фильтром независимо от настройки: пользователь
     ожидает его и сам выбирает другой канал.
     */
    var exceptedIndexPath: IndexPath?

    /**
     Создаёт фильтр плейлиста.

     - Parameter settings: Настройки отображения плейлиста.
     */
    init(settings: Settings = Settings()) {
        self.settings = settings
    }

    /**
     Нерабочие потоки (с ошибкой) скрыты из отображения плейлиста.

     Настройка сохраняется в настройках отображения плейлиста.
     */
    var isFailedStreamsHidden: Bool {
        get { self.settings.isFailedStreamsHidden }
        set { self.settings.isFailedStreamsHidden = newValue }
    }

    /**
     Сообщает, скрыт ли поток из отображения.

     Скрыт поток с ошибкой при включённой настройке «скрывать нерабочие
     потоки». Поток-исключение проверяется вызывающей стороной до этого
     метода.

     - Parameter stream: Поток вещания.
     - Returns: `true`, если поток скрыт из отображения.
     */
    func isHidden(_ stream: Stream) -> Bool {
        guard self.isFailedStreamsHidden else { return false }
        if case .failed = stream.status { return true }
        return false
    }
    /**
     Создаёт снимки состояния групп плейлиста для отображения в таблице.

     При включённой настройке «скрывать нерабочие потоки» исключаются строки
     потоков с ошибкой, кроме потока-исключения, а опустевшие группы
     не отображаются.

     - Parameter groups: Группы потоков вещания плейлиста.
     - Returns: Снимки состояния групп плейлиста.
     */
    func groupSnapshots(for groups: [Group]) -> [GroupSnapshot] {
        groups.enumerated().compactMap { section, group in
            let rows = group.streams.indices.filter { row in
                let indexPath = IndexPath(row: row, section: section)
                // поток-исключение остаётся видимым
                if indexPath == self.exceptedIndexPath { return true }
                return !self.isHidden(group.streams[row])
            }
            if rows.isEmpty { return nil }
            return GroupSnapshot(playlistSection: section, playlistRows: rows)
        }
    }
    /**
     Фильтрует группы потоков вещания для отображения в таблице.

     При включённой настройке «скрывать нерабочие потоки» из групп
     исключаются потоки с ошибкой, кроме потока-исключения, а опустевшие
     группы не отображаются.

     - Parameter groups: Группы потоков вещания плейлиста.
     - Returns: Отфильтрованные группы потоков вещания.
     */
    func filterGroups(for groups: [Group]) -> [Group] {
        groups.enumerated().compactMap { section, group in
            let streams = group.streams.indices.filter { row in
                let indexPath = IndexPath(row: row, section: section)
                // поток-исключение остаётся видимым
                if indexPath == self.exceptedIndexPath { return true }
                return !self.isHidden(group.streams[row])
            }.map { group.streams[$0] }
            if streams.isEmpty { return nil }
            return Group(title: group.title, streams: streams)
        }
    }


}


