//
//  PlayerContainerViewController.swift
//  AVPlayerContainerDemo
//
//  Created by Лайм HD on 04.08.2022.
//

import AVKit
import UIKit
import AVPlayerKit
import AVPlayerContainerKit

/**
 Контейнер плеера.

 Точка сборки приложения: владеет сервисом плейлиста, запускает его
 и раздаёт его события детям — контроллеру плейлиста для отрисовки
 и плееру для воспроизведения.
 */
final class PlayerContainerViewController: AVPlayerContainerViewController<PlayerViewController> {
    /**
     Сервис плейлиста.
     */
    private let playlistService = PlaylistService()
    /**
     Контроллер плейлиста.
     */
    private weak var playlistViewController: PlaylistViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = #colorLiteral(red: 0.7224441171, green: 0.8850880265, blue: 0.5941329598, alpha: 1)
        let playlistViewController = PlaylistViewController(service: self.playlistService)
        self.playlistViewController = playlistViewController
        playlistViewController.view.backgroundColor = #colorLiteral(red: 0.721568644, green: 0.8862745166, blue: 0.5921568871, alpha: 1)
        self.addChildWithDefaultPlayerViewController(
            secondaryViewController: playlistViewController,
            isPlayerViewControllerPresented: false
        )
        self.playerViewController.playerView.player = AVPlayer()
        self.startPlaylist()
    }
    /**
     Запускает работу сервиса плейлиста и наблюдение за его событиями.
     */
    private func startPlaylist() {
        let playlistURLString = "https://iptv-org.github.io/iptv/languages/rus.m3u"
        let url = URL(string: playlistURLString)!
        self.playlistService.start(url: url)
        self.observePlaylistEvents()
    }
    /**
     Запускает наблюдение за событиями плейлиста и раздаёт их по назначению.
     */
    private func observePlaylistEvents() {
        Task { [weak self] in
            guard let events = self?.playlistService.events else { return }
            for await event in events {
                self?.handle(event)
            }
        }
    }
    /**
     Обрабатывает событие плейлиста.

     Отрисовку выполняет контроллер плейлиста. Готовый к воспроизведению
     запрошенный поток запускается в плеере.

     - Parameter event: Событие плейлиста.
     */
    private func handle(_ event: PlaylistEvent) {
        // отрисовку выполняет контроллер плейлиста
        self.playlistViewController?.handle(event)
        switch event {
        case .loaded, .loadingFailed:
            let count = self.playlistService.groups.reduce(0) { $0 + $1.streams.count }
            self.title = count > 0
            ? "Player Container Demo (\(count))"
            : "Player Container Demo"
        case let .resolvedStream(stream, _):
            guard case .readyToPlay = stream.status else { return }
            if self.isPlayerPresented {
                self.play(stream: stream)
            } else {
                self.updatePlayerState(isPlayerPresented: true) {
                    self.play(stream: stream)
                }
            }
        case let .streamChanged(stream, indexPath):
            // первый готовый к воспроизведению поток запускается автоматически
            guard case .readyToPlay = stream.status else { return }
            if self.isPlayerPresented { return }
            self.updatePlayerState(isPlayerPresented: true) {
                self.play(stream: stream)
            }
            // автозапущенный поток разрешён: контроллеру плейлиста
            // передаётся дополнительное событие разрешения
            let event = PlaylistEvent.resolvedStream(stream, indexPath: indexPath)
            self.playlistViewController?.handle(event)
        }
    }
    /**
     Запускает воспроизведение потока.
     - Parameter stream: Поток вещания.
     */
    private func play(stream: Stream) {
        print("Playing stream: \(stream)")
        self.playerViewController.player?.replaceCurrentItem(with: stream.url)
        self.playerViewController.player?.play()
    }
    
    
}

extension UINavigationController {
    open override var childForHomeIndicatorAutoHidden: UIViewController? {
        self.topViewController
    }
    
    
}
