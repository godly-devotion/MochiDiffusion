//
//  Pipeline.swift
//  Diffusion
//
//  Created by Pedro Cuenca on December 2022.
//  See LICENSE at https://github.com/huggingface/swift-coreml-diffusers/LICENSE
//

import Foundation
import CoreML
import Combine

import StableDiffusion

typealias StableDiffusionProgress = StableDiffusionPipeline.Progress

class Pipeline {
    let pipeline: StableDiffusionPipeline
    
    var progress: StableDiffusionProgress? = nil {
        didSet {
            progressPublisher.value = progress
        }
    }
    lazy private(set) var progressPublisher: CurrentValueSubject<StableDiffusionProgress?, Never> = CurrentValueSubject(progress)
    
    init(_ pipeline: StableDiffusionPipeline) {
        self.pipeline = pipeline
    }
    
    func generate(
        prompt: String,
        negativePrompt: String = "",
        batchSize: Int = 1,
        numInferenceSteps stepCount: Int = 50,
        seed: UInt32 = 0,
        guidanceScale: Float = 7.5,
        scheduler: StableDiffusionScheduler
    ) throws -> ([CGImage], UInt32) {
        let beginDate = Date()
        print("Generating...")
        let images = try pipeline.generateImages(
            prompt: prompt,
            negativePrompt: negativePrompt,
            imageCount: batchSize,
            stepCount: stepCount,
            seed: seed,
            guidanceScale: guidanceScale,
            disableSafety: true,
            scheduler: scheduler
        ) { progress in
            handleProgress(progress)
            return true
        }
        print("Got images: \(images) in \(Date().timeIntervalSince(beginDate))")
        
        let imgs = images.compactMap({$0})
        if imgs.count != batchSize {
            throw "Generation failed: got \(imgs.count) instead of \(batchSize)"
        }
        return (imgs, seed)
    }
    
    func handleProgress(_ progress: StableDiffusionPipeline.Progress) {
        self.progress = progress
    }
}
