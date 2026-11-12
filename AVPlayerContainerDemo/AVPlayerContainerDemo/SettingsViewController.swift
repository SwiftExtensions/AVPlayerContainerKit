//
//  SettingsViewController.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 12.11.2026.
//

import UIKit

/**
 Контроллер настроек.

 Отображает настройки отображения плейлиста. Изменения применяются
 к сервису плейлиста сразу и сохраняются в стандартных настройках
 пользователя.
 */
final class SettingsViewController: UITableViewController {
    /**
     Сервис плейлиста.
     */
    private let playlistService: PlaylistService
    /**
     Идентификатор ячейки настройки.
     */
    private static let reuseIdentifier = "SettingCell"

    /**
     Создаёт контроллер настроек.

     - Parameter service: Сервис плейлиста.
     */
    init(service: PlaylistService) {
        self.playlistService = service
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Настройки"
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.reuseIdentifier)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: Self.reuseIdentifier,
            for: indexPath
        )
        var configuration = cell.defaultContentConfiguration()
        configuration.text = "Скрывать нерабочие потоки"
        cell.contentConfiguration = configuration
        cell.selectionStyle = .none
        let toggle = UISwitch()
        toggle.isOn = self.playlistService.isFailedStreamsHidden
        toggle.addTarget(self, action: #selector(failedStreamsHiddenChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle

        return cell
    }

    // MARK: - Actions

    /**
     Обрабатывает переключение настройки «скрывать нерабочие потоки».

     - Parameter sender: Переключатель настройки.
     */
    @objc private func failedStreamsHiddenChanged(_ sender: UISwitch) {
        self.playlistService.setFailedStreamsHidden(sender.isOn)
    }


}


