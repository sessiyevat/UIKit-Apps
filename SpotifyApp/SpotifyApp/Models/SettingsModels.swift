//
//  SettingsModels.swift
//  SpotifyApp
//
//  Created by Tommy on 2/13/23.
//

import Foundation

struct Section{
    let title: String
    let options: [Option]
}

struct Option {
    let title: String
    let handler: () -> Void
}
