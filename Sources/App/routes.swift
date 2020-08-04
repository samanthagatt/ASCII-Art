import Foundation
import Routing
import Vapor
import SwiftGD

/// Register your application's routes here.
///
/// [Learn More →](https://docs.vapor.codes/3.0/getting-started/structure/#routesswift)
public func routes(_ router: Router) throws {
    router.get { req -> Future<View> in
        let context: [String: String] = [:]
        return try req.view().render("home", context)
    }
    router.get("fetch") { req -> Future<String> in
        try image(from: req).map(to: String.self) { img in
            guard let img = img else { throw Abort(.internalServerError) }
            let asciis = ["M", "#", "m", "@", "%", "C", "t", "]", "?", "~"]
            let blockSize = req.query["blockSize"] ?? 2
            var rows: [[String]] = []
            // Avoids continuous reallocation when you already know how long it will be
            rows.reserveCapacity(img.size.height / blockSize)
            for y in stride(from: 0, to: img.size.height, by: blockSize) {
                var row: [String] = []
                row.reserveCapacity(img.size.width / blockSize)
                for x in stride(from: 0, to: img.size.width, by: blockSize) {
                    let color = img.get(pixel: Point(x: x, y: y))
                    let red = color.redComponent * 0.299
                    let green = color.greenComponent * 0.587
                    let blue = color.blueComponent * 0.114
                    let brightness = red + green + blue
                    let sum = Int(round(brightness * 9))
                    row.append(asciis[sum])
                }
                rows.append(row)
            }
            return rows.reduce("") { $0 + $1.joined(separator: "•") + "\n"}
        }
    }
}

func image(from req: Request) throws -> Future<Image?> {
    guard let uri: String = req.query["url"] else { throw Abort(.badRequest) }
    return try req.client().get(uri).flatMap(to: Image?.self) { res in
        let temp = NSTemporaryDirectory().appending("input.jpg")
        let url = URL(fileURLWithPath: temp)
        return res.http.body.consumeData(max: 90_000_000, on: req)
            .map(to: Image?.self) { data in
                try data.write(to: url)
                return Image(url: url)
        }
    }
}
