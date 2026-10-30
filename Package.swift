// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlashcardsCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FlashcardsCore", targets: ["FlashcardsCore"]),
    ],
    targets: [
        .target(
            name: "FlashcardsCore",
            path: "src",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "FlashcardsCoreTests",
            dependencies: ["FlashcardsCore"],
            path: "tests",
            exclude: [
                "ui",
                "play/swipe-cards/swipe-cards.feature",
                "play/answers/answers.feature",
                "people/manage-profiles/manage-profiles.feature",
                "people/manage-groups/manage-groups.feature",
                "library/choose-decks/choose-decks.feature",
                "library/custom-cards/custom-cards.feature",
                "library/custom-cards/custom-cards-v2.feature",
                "library/card-audience/card-audience.feature",
                "people/tag-people/tag-people.feature",
                "data/backup-database/backup-database.feature",
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
