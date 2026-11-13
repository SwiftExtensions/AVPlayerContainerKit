//
//  RemoteControlService.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 13.11.2026.
//

import AVFoundation
import AVPlayerKit
import MediaPlayer
import UIKit

/**
 Сервис дистанционного управления воспроизведением.

 Регистрирует команды центра управления и заблокированного экрана:
 воспроизведение, пауза и переключение каналов. При переключении
 канала обновляет информацию «Сейчас играет» названием и логотипом
 канала.

 Команды переключения повторяют выбор строки пользователем, поэтому
 сервис получает их замыканиями и не знает про плейлист.
 */
final class RemoteControlService {
    /**
     Дистанционное управление командами плеера.
     */
    private let commandCenter = RemoteCommandCenter()
    /**
     Сервис изображений для загрузки логотипа канала.
     */
    private let imageService = ImageService()
    /**
     Возвращает плеер, которым управляют команды.
     */
    private let player: () -> AVPlayer?
    
    /**
     Адрес потока, показанного в информации «Сейчас играет».

     Защищает от применения логотипа, загруженного для уже
     переключённого канала.
     */
    private var streamURL: URL?

    /**
     Создаёт сервис дистанционного управления и регистрирует команды.

     - Parameter player: Замыкание плеера, которым управляют команды.
     - Parameter selectNext: Замыкание выбора следующего по списку
       потока; `true`, если поток есть и выбран.
     - Parameter selectPrevious: Замыкание выбора предыдущего
       по списку потока; `true`, если поток есть и выбран.
     */
    init(
        player: @escaping () -> AVPlayer?,
        selectNext: @escaping () -> Bool,
        selectPrevious: @escaping () -> Bool
    ) {
        self.player = player
        self.commandCenter.addAction(to: \.playCommand) { [player] _ in
            guard let player = player() else {
                return .noActionableNowPlayingItem
            }
            player.play()
            return .success
        }
        self.commandCenter.addAction(to: \.pauseCommand) { [player] _ in
            guard let player = player() else {
                return .noActionableNowPlayingItem
            }
            player.pause()
            return .success
        }
        self.commandCenter.addAction(to: \.togglePlayPauseCommand) { [player] _ in
            guard let player = player() else {
                return .noActionableNowPlayingItem
            }
            if player.timeControlStatus == .paused {
                player.play()
            } else {
                player.pause()
            }
            return .success
        }
        self.commandCenter.addAction(to: \.nextTrackCommand) { _ in
            selectNext() ? .success : .noActionableNowPlayingItem
        }
        self.commandCenter.addAction(to: \.previousTrackCommand) { _ in
            selectPrevious() ? .success : .noActionableNowPlayingItem
        }
        try? AVAudioSession.sharedInstance().configureMoviePlayback()
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    /**
     Сообщает о начале воспроизведения потока.

     Информация «Сейчас играет» обновляется названием канала и его
     группой. Логотип загружается по адресу из атрибута `tvg-logo`
     и добавляется, когда придёт из сети.

     - Parameter stream: Поток вещания, переключённый на воспроизведение.
     */
    func streamDidStart(_ stream: Stream) {
        self.streamURL = stream.url
        self.updateNowPlayingInfo(for: stream, artwork: nil)
        guard let logoURLString = stream.attributes["tvg-logo"] else { return }
        self.imageService.loadImage(from: logoURLString) { [weak self] result in
            guard case .success(let image) = result else { return }
            self?.updateNowPlayingInfo(for: stream, artwork: image)
        }
    }
    /**
     Обновляет информацию «Сейчас играет», если поток всё ещё играет.

     Группа канала из атрибута `group-title` показывается в поле
     исполнителя. Прямой эфир отмечается по длительности `-1` строки
     `#EXTINF`.

     - Parameter stream: Поток вещания.
     - Parameter artwork: Логотип канала. `nil` — показать без логотипа.
     */
    private func updateNowPlayingInfo(for stream: Stream, artwork: UIImage?) {
        guard self.streamURL == stream.url else { return }
        var builder = NowPlayingInfoBuilder(
            title: stream.title,
            artist: stream.attributes["group-title"]
        )
        builder.mediaType = .video
        builder.isLiveStream = stream.duration == "-1"
        builder.setArtwork(artwork)
        var info = builder.build()
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }


}
