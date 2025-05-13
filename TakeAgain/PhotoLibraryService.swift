//
//  PhotoLibraryService.swift
//  TakeAgain
//
//  Created by 고재현 on 5/13/25.
//


import Foundation
import Photos
import UIKit

struct PhotoLibraryService {
    static var alreadySavedURLs = Set<URL>()

    static func saveVideo(from url: URL?, completion: @escaping () -> Void) {
        guard let url = url else { return }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { success, error in
            if success {
                print("✅ 저장 성공")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: completion)
            } else {
                print("❌ 저장 실패: \(error?.localizedDescription ?? "알 수 없음")")
            }
        }
    }

    static func deleteAndSaveToRecentlyDeleted(from url: URL?, completion: @escaping () -> Void) {
        guard let url = url else { return }

        if alreadySavedURLs.contains(url) {
            print("⚠️ 이미 저장된 URL. 삭제만 진행")
            deleteLatestSavedAsset(completion: completion)
            return
        }

        alreadySavedURLs.insert(url)

        PHPhotoLibrary.shared().performChanges({
            guard let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url),
                  let placeholder = request.placeholderForCreatedAsset else {
                print("❌ Failed to create asset or placeholder.")
                return
            }

            let localId = placeholder.localIdentifier

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
                if let asset = assets.firstObject {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.deleteAssets([asset] as NSArray)
                    }) { deleted, delError in
                        if deleted {
                            print("✅ 삭제 성공")
                        } else {
                            print("❌ 삭제 실패: \(delError?.localizedDescription ?? "알 수 없음")")
                        }
                        completion()
                    }
                } else {
                    print("❌ 삭제 대상 asset 찾기 실패")
                    completion()
                }
            }
        }) { success, error in
            if success {
                print("✅ 저장 성공")
            } else {
                print("❌ 저장 실패: \(error?.localizedDescription ?? "알 수 없음")")
            }
        }
    }

    static func deleteLatestSavedAsset(completion: @escaping () -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        let assets = PHAsset.fetchAssets(with: fetchOptions)
        if let asset = assets.firstObject {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }) { deleted, delError in
                if deleted {
                    print("✅ 삭제 성공 (중복 방지 루틴)")
                } else {
                    print("❌ 삭제 실패 (중복 방지 루틴): \(delError?.localizedDescription ?? "알 수 없음")")
                }
                completion()
            }
        } else {
            print("❌ 삭제 대상 asset 찾기 실패 (중복 방지 루틴)")
            completion()
        }
    }

    static func fetchLatestThumbnail(completion: @escaping (UIImage?) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        let assets = PHAsset.fetchAssets(with: fetchOptions)
        guard let asset = assets.firstObject else {
            completion(nil)
            return
        }

        let imageManager = PHImageManager.default()
        let targetSize = CGSize(width: 50, height: 50)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
            completion(image)
        }
    }
}
