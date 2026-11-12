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
    /**
     Путь строки воспроизводимого в данный момент потока.
     */
    private var currentStreamIndexPath: IndexPath?

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
        self.playerViewController.playbackErrorDelegate = self
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
        case let .resolvedStream(stream, indexPath):
            guard case .readyToPlay = stream.status else { return }
            if self.isPlayerPresented {
                self.play(stream: stream, at: indexPath)
            } else {
                self.updatePlayerState(isPlayerPresented: true) {
                    self.play(stream: stream, at: indexPath)
                }
            }
        case let .streamChanged(stream, indexPath):
            // первый готовый к воспроизведению поток запускается автоматически
            guard case .readyToPlay = stream.status else { return }
            if self.isPlayerPresented { return }
            self.updatePlayerState(isPlayerPresented: true) {
                self.play(stream: stream, at: indexPath)
            }
            // автозапущенный поток разрешён: контроллеру плейлиста
            // передаётся дополнительное событие разрешения
            let event = PlaylistEvent.resolvedStream(stream, indexPath: indexPath)
            self.playlistViewController?.handle(event)
        }
    }
    /**
     Запускает воспроизведение потока.

     Путь строки запоминается: по нему поток помечается ошибкой,
     если воспроизведение не удастся.

     - Parameter stream: Поток вещания.
     - Parameter indexPath: Путь строки потока.
     */
    private func play(stream: Stream, at indexPath: IndexPath) {
        print("Playing stream: \(stream)")
        self.currentStreamIndexPath = indexPath
        self.playerViewController.player?.replaceCurrentItem(with: stream.url)
        self.playerViewController.player?.play()
    }


}

// MARK: - PlayerViewController.PlaybackErrorDelegate

extension PlayerContainerViewController: PlayerViewController.PlaybackErrorDelegate {
    func playerViewController(
        _ playerViewController: PlayerViewController,
        player: AVPlayer,
        didFailWith error: (any Error)?
    ) {
        self.handlePlaybackError(error)
    }
    func playerViewController(
        _ playerViewController: PlayerViewController,
        playerItem: AVPlayerItem,
        didFailWith error: (any Error)?
    ) {
        self.handlePlaybackError(error)
    }
    /**
     Обрабатывает ошибку воспроизведения текущего потока.

     Обработка переносится на главный поток: наблюдение за плеером может
     сообщить об ошибке из любого потока.

     - Parameter error: Ошибка воспроизведения. `nil`, если система
       не сообщила причину.
     */
    private func handlePlaybackError(_ error: (any Error)?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let indexPath = self.currentStreamIndexPath else { return }
            self.playlistService.streamPlaybackFailed(error, at: indexPath)
        }
    }


}

extension UINavigationController {
    open override var childForHomeIndicatorAutoHidden: UIViewController? {
        self.topViewController
    }
    
    
}
