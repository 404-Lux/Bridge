import SwiftUI
import PhotosUI

public class PhotoManager {
    public static let shared = PhotoManager()

    private init() {}

    /// Extracts JPEG binary data from a PhotosPickerItem
    public func loadJPEGData(from item: PhotosPickerItem, completion: @escaping (Data?, String?) -> Void) {
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data), let jpegData = image.jpegData(compressionQuality: 0.9) {
                        let filename = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
                        completion(jpegData, filename)
                    } else {
                        completion(nil, nil)
                    }
                case .failure:
                    completion(nil, nil)
                }
            }
        }
    }
}
