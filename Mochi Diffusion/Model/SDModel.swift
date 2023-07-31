//
//  SDModel.swift
//  Mochi Diffusion
//
//  Created by Joshua Park on 2/12/23.
//

import CoreML
import Foundation
import os.log

private let logger = Logger()

struct SDModel: Identifiable, Hashable {
    let url: URL
    let name: String
    let attention: SDModelAttentionType
    let controlNet: [String]
    let isXL: Bool

    var id: URL { url }

    init?(url: URL, name: String, controlNet: [String]) {
        guard let attention = identifyAttentionType(url) else {
            return nil
        }

        let isXL = identifyIfXL(url)

        self.url = url
        self.name = name
        self.attention = attention
        self.controlNet = controlNet
        self.isXL = isXL
    }
}

private func identifyAttentionType(_ url: URL) -> SDModelAttentionType? {
    let unetMetadataURL = url.appending(components: "Unet.mlmodelc", "metadata.json")
    let controlledUnetMetadataURL = url.appending(components: "ControlledUnet.mlmodelc", "metadata.json")

    let metadataURL: URL

    if FileManager.default.fileExists(atPath: unetMetadataURL.path(percentEncoded: false)) {
        metadataURL = unetMetadataURL
    } else {
        metadataURL = controlledUnetMetadataURL
    }

    struct ModelMetadata: Decodable {
        let mlProgramOperationTypeHistogram: [String: Int]
    }

    do {
        let jsonData = try Data(contentsOf: metadataURL)
        let metadatas = try JSONDecoder().decode([ModelMetadata].self, from: jsonData)

        guard metadatas.count == 1 else {
            return nil
        }

        return metadatas[0].mlProgramOperationTypeHistogram["Ios16.einsum"] != nil ? .splitEinsum : .original
    } catch {
        logger.warning("Failed to parse model metadata at '\(metadataURL)': \(error)")
        return nil
    }
}

private func identifyIfXL(_ url: URL) -> Bool {
    let unetMetadataURL = url.appending(components: "Unet.mlmodelc", "metadata.json")
    let metadataURL: URL = unetMetadataURL

    struct ModelMetadata: Decodable {
        let inputSchema: [[String: String]]
    }

    do {
        let jsonData = try Data(contentsOf: metadataURL)
        let metadatas = try JSONDecoder().decode([ModelMetadata].self, from: jsonData)

        guard metadatas.count == 1 else {
            return false
        }

        // XL models have 5 inputs total (added: time_ids and text_embeds)
        let inputNames = metadatas[0].inputSchema.compactMap { $0["name"] }
        return inputNames.contains("time_ids") && inputNames.contains("text_embeds")
    } catch {
        logger.warning("Failed to parse model metadata at '\(metadataURL)': \(error)")
        return false
    }
}
