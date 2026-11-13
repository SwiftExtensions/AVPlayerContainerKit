//
//  PlaylistServiceEvent.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 13.11.2026.
//

/**
 События сервиса плейлиста.

 Объединяет два домена событий: плейлиста и потока вещания.
 */
enum PlaylistServiceEvent {
    /**
     Событие плейлиста.
     */
    case playlist(PlaylistEvent)
    /**
     Событие потока вещания.
     */
    case stream(StreamEvent)


}


