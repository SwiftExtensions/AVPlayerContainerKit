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
     Индекс строки настройки времени проверки потока.
     */
    private static let validationTimeoutRow = 1

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
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Готово",
            style: .done,
            target: self,
            action: #selector(done)
        )
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.reuseIdentifier)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // значение времени проверки могло измениться на экране выбора
        self.tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 2 }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: Self.reuseIdentifier,
            for: indexPath
        )
        if indexPath.row == Self.validationTimeoutRow {
            // раскладка «в линию»: название слева, значение справа
            var configuration = UIListContentConfiguration.valueCell()
            configuration.text = "Время проверки потока"
            configuration.image = UIImage(systemName: "timer")
            configuration.secondaryText = "\(Int(self.playlistService.validationTimeout)) с"
            cell.contentConfiguration = configuration
            cell.accessoryType = .disclosureIndicator
        } else {
            var configuration = cell.defaultContentConfiguration()
            configuration.text = "Скрывать нерабочие потоки"
            configuration.image = UIImage(systemName: "eye.slash")
            cell.contentConfiguration = configuration
            cell.selectionStyle = .none
            let toggle = UISwitch()
            toggle.isOn = self.playlistService.isFailedStreamsHidden
            toggle.addTarget(self, action: #selector(failedStreamsHiddenChanged(_:)), for: .valueChanged)
            cell.accessoryView = toggle
        }

        return cell
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row == Self.validationTimeoutRow else { return }
        let controller = ValidationTimeoutViewController(service: self.playlistService)
        self.navigationController?.pushViewController(controller, animated: true)
    }

    // MARK: - Actions

    /**
     Обрабатывает переключение настройки «скрывать нерабочие потоки».

     - Parameter sender: Переключатель настройки.
     */
    @objc private func failedStreamsHiddenChanged(_ sender: UISwitch) {
        self.playlistService.setFailedStreamsHidden(sender.isOn)
    }
    /**
     Закрывает настройки.
     */
    @objc private func done() {
        self.dismiss(animated: true)
    }


}


