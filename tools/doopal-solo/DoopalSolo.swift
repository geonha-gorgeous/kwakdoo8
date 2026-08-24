// DoopalSolo — a standalone desktop pet for the kwakdoo8 (Doopal) sprite atlas.
//
// The Codex desktop app derives its pet state from task and notification state, so
// without Codex activity the pet stays in `idle` forever and the other rows of the
// atlas are never seen. This binary renders the same atlas with the same frame
// timings as the app, but picks its own motions at random intervals.
//
// Build: ./build.sh   Run: ./run.sh   Help: ./run.sh --help

import AppKit
import CoreGraphics
import Foundation
import ImageIO

// MARK: - Atlas contract

enum Atlas {
    static let columns = 8
    static let rows = 11
    static let expectedWidth = 1536
    static let expectedHeight = 2288
    static let lookFirstRow = 9
    static let lookDirections = 16
    /// The desktop app renders the pet at 7.04rem wide with a 192:208 aspect ratio.
    static let baseWidth: CGFloat = 112.64
    static let aspect: CGFloat = 208.0 / 192.0
}

struct Frame {
    let row: Int
    let column: Int
    let durationMs: Int
}

/// A frame list plus the index playback jumps back to after the last frame.
struct Playback {
    let frames: [Frame]
    let loopStartIndex: Int?

    var leadDurationMs: Int {
        let end = loopStartIndex ?? frames.count
        return frames.prefix(end).reduce(0) { $0 + $1.durationMs }
    }
}

enum Action: String, CaseIterable {
    case waving
    case jumping
    case waiting
    case review
    case running
    case runningRight = "running-right"
    case runningLeft = "running-left"
    case failed
}

struct LookHold {
    let direction: Int
    let holdMs: Int
}

enum Motion {
    case idle
    case action(Action)
    case lookAround([LookHold])
    case sequence([Frame])
}

// MARK: - Frame tables (mirrored from the desktop app's pet renderer)

enum Sprite {
    static let idleSlowdown = 6
    static let actionRepeats = 3

    /// Every frame runs `mid` ms except the last, which holds for `last` ms.
    static func strip(row: Int, count: Int, mid: Int, last: Int) -> [Frame] {
        (0..<count).map { Frame(row: row, column: $0, durationMs: $0 == count - 1 ? last : mid) }
    }

    /// Row 0 at its authored speed. The app only ever plays it slowed down.
    static let idleBase: [Frame] = [
        Frame(row: 0, column: 0, durationMs: 280),
        Frame(row: 0, column: 1, durationMs: 110),
        Frame(row: 0, column: 2, durationMs: 110),
        Frame(row: 0, column: 3, durationMs: 140),
        Frame(row: 0, column: 4, durationMs: 140),
        Frame(row: 0, column: 5, durationMs: 320),
    ]

    static let idle: [Frame] = idleBase.map {
        Frame(row: $0.row, column: $0.column, durationMs: $0.durationMs * idleSlowdown)
    }

    static let actionFrames: [Action: [Frame]] = [
        .runningRight: strip(row: 1, count: 8, mid: 120, last: 220),
        .runningLeft: strip(row: 2, count: 8, mid: 120, last: 220),
        .waving: strip(row: 3, count: 4, mid: 140, last: 280),
        .jumping: strip(row: 4, count: 5, mid: 140, last: 280),
        .failed: strip(row: 5, count: 8, mid: 140, last: 240),
        .waiting: strip(row: 6, count: 6, mid: 150, last: 260),
        .running: strip(row: 7, count: 6, mid: 120, last: 220),
        .review: strip(row: 8, count: 6, mid: 150, last: 280),
    ]

    static func frames(for action: Action) -> [Frame] {
        actionFrames[action] ?? idle
    }

    static func lookFrame(direction: Int, holdMs: Int) -> Frame {
        let d = ((direction % Atlas.lookDirections) + Atlas.lookDirections) % Atlas.lookDirections
        return Frame(row: Atlas.lookFirstRow + d / Atlas.columns,
                     column: d % Atlas.columns,
                     durationMs: holdMs)
    }

    /// Like the app: an action plays three times, then the pet settles back into idle.
    static func playback(_ motion: Motion) -> Playback {
        switch motion {
        case .idle:
            return Playback(frames: idle, loopStartIndex: 0)
        case .action(let action):
            let one = frames(for: action)
            let lead = Array(repeating: one, count: actionRepeats).flatMap { $0 }
            return Playback(frames: lead + idle, loopStartIndex: lead.count)
        case .lookAround(let holds):
            let lead = holds.map { lookFrame(direction: $0.direction, holdMs: $0.holdMs) }
            return Playback(frames: lead + idle, loopStartIndex: lead.count)
        case .sequence(let lead):
            return Playback(frames: lead + idle, loopStartIndex: lead.count)
        }
    }

    /// Every state once, then all sixteen look directions. Used by "Play All Motions".
    static func paradeFrames() -> [Frame] {
        var out: [Frame] = idle
        for action in Action.allCases {
            out += frames(for: action)
            out += frames(for: action)
            out.append(Frame(row: 0, column: 0, durationMs: 400))
        }
        for d in 0..<Atlas.lookDirections {
            out.append(lookFrame(direction: d, holdMs: 260))
        }
        return out
    }
}

// MARK: - Atlas image

final class AtlasImage {
    let image: CGImage
    let cellWidth: Int
    let cellHeight: Int
    private var cache: [Int: CGImage] = [:]

    init?(url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        self.image = image
        self.cellWidth = image.width / Atlas.columns
        self.cellHeight = image.height / Atlas.rows
    }

    var describesExpectedAtlas: Bool {
        image.width == Atlas.expectedWidth && image.height == Atlas.expectedHeight
    }

    func cell(row: Int, column: Int) -> CGImage? {
        let key = row * Atlas.columns + column
        if let cached = cache[key] { return cached }
        let rect = CGRect(x: column * cellWidth, y: row * cellHeight,
                          width: cellWidth, height: cellHeight)
        guard let cropped = image.cropping(to: rect) else { return nil }
        cache[key] = cropped
        return cropped
    }

    func cell(_ frame: Frame) -> CGImage? {
        cell(row: frame.row, column: frame.column)
    }
}

// MARK: - Locating the installed spritesheet

enum SpriteLocator {
    static func spritesheetName(in directory: URL) -> String {
        let manifest = directory.appendingPathComponent("pet.json")
        guard let data = try? Data(contentsOf: manifest),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = json["spritesheetPath"] as? String,
              !path.isEmpty else { return "spritesheet.webp" }
        return path
    }

    static func candidates(explicit: String?) -> [URL] {
        if let explicit {
            return [URL(fileURLWithPath: (explicit as NSString).expandingTildeInPath)]
        }
        var urls: [URL] = []
        let env = ProcessInfo.processInfo.environment["CODEX_HOME"]
        let codexHome = env.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        for directory in ["pets", "avatars"] {
            for pet in ["doopal", "dupal"] {
                let base = codexHome.appendingPathComponent(directory).appendingPathComponent(pet)
                urls.append(base.appendingPathComponent(spritesheetName(in: base)))
            }
        }
        urls += repositoryCandidates()
        return urls
    }

    /// Fall back to the packaged release in this repository: tools/doopal-solo/build/<bin>
    private static func repositoryCandidates() -> [URL] {
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        var root = executable.deletingLastPathComponent()
        var urls: [URL] = []
        for _ in 0..<8 {
            root = root.deletingLastPathComponent()
            let latestFile = root.appendingPathComponent("LATEST")
            guard let latest = try? String(contentsOf: latestFile, encoding: .utf8) else { continue }
            let version = latest.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !version.isEmpty else { continue }
            for pet in ["doopal", "dupal"] {
                let base = root.appendingPathComponent("versions/\(version)/\(pet)")
                urls.append(base.appendingPathComponent(spritesheetName(in: base)))
            }
            break
        }
        return urls
    }

    static func resolve(explicit: String?) -> URL? {
        candidates(explicit: explicit).first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

// MARK: - Settings and persisted window state

struct Settings {
    var minIntervalSeconds: Double = 180
    var maxIntervalSeconds: Double = 600
    var lookAround = true
    /// Stay visible when the user switches Mission Control Spaces or fullscreens an app.
    var allSpaces = true
    var scale: CGFloat = 1
    var verbose = false
    var spritesheetPath: String?

    static let configURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/doopal-solo.json")

    static func load() -> Settings {
        var settings = Settings()
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return settings
        }
        if let v = json["minIntervalSeconds"] as? Double { settings.minIntervalSeconds = v }
        if let v = json["maxIntervalSeconds"] as? Double { settings.maxIntervalSeconds = v }
        if let v = json["lookAround"] as? Bool { settings.lookAround = v }
        if let v = json["allSpaces"] as? Bool { settings.allSpaces = v }
        if let v = json["scale"] as? Double { settings.scale = CGFloat(v) }
        if let v = json["spritesheetPath"] as? String, !v.isEmpty { settings.spritesheetPath = v }
        return settings
    }

    mutating func normalize() {
        minIntervalSeconds = max(1, minIntervalSeconds)
        maxIntervalSeconds = max(minIntervalSeconds, maxIntervalSeconds)
        scale = min(max(scale, 0.5), 4)
    }
}

struct PersistedState {
    var origin: CGPoint?
    var scale: CGFloat?

    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/doopal-solo/state.json")

    static func load() -> PersistedState {
        var state = PersistedState()
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return state
        }
        if let x = json["x"] as? Double, let y = json["y"] as? Double {
            state.origin = CGPoint(x: x, y: y)
        }
        if let scale = json["scale"] as? Double { state.scale = CGFloat(scale) }
        return state
    }

    func save() {
        var json: [String: Any] = [:]
        if let origin { json["x"] = Double(origin.x); json["y"] = Double(origin.y) }
        if let scale { json["scale"] = Double(scale) }
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]) else { return }
        try? FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try? data.write(to: Self.url, options: .atomic)
    }
}

// MARK: - View

final class PetView: NSView {
    var onHoverChange: ((Bool) -> Void)?
    var onDragDirection: ((CGFloat) -> Void)?
    var onDragEnd: (() -> Void)?
    var petMenu: NSMenu?

    private var trackingArea: NSTrackingArea?
    private var dragStart: NSPoint?
    private var windowOriginAtDragStart: CGPoint?
    private var hasDragged = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .nearest
        layer?.contentsGravity = .resizeAspect
        layer?.isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func show(_ image: CGImage?) {
        layer?.contents = image
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self,
                                  userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { onHoverChange?(true) }
    override func mouseExited(with event: NSEvent) { onHoverChange?(false) }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        windowOriginAtDragStart = window?.frame.origin
        hasDragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart, let origin = windowOriginAtDragStart, let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - dragStart.x
        let dy = now.y - dragStart.y
        if !hasDragged && abs(dx) < 4 && abs(dy) < 4 { return }
        hasDragged = true
        window.setFrameOrigin(CGPoint(x: origin.x + dx, y: origin.y + dy))
        onDragDirection?(dx)
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        windowOriginAtDragStart = nil
        if hasDragged { onDragEnd?() }
        hasDragged = false
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let petMenu else { return }
        petMenu.popUp(positioning: nil, at: convert(event.locationInWindow, from: nil), in: self)
    }
}

// MARK: - Animator

final class PetAnimator {
    private let atlas: AtlasImage
    private let view: PetView
    private var playback: Playback
    private var index = 0
    private var pending: DispatchWorkItem?

    init(atlas: AtlasImage, view: PetView) {
        self.atlas = atlas
        self.view = view
        self.playback = Sprite.playback(.idle)
    }

    /// Starts `motion` and returns how long its non-idle lead-in runs.
    @discardableResult
    func play(_ motion: Motion) -> TimeInterval {
        pending?.cancel()
        pending = nil
        playback = Sprite.playback(motion)
        index = 0
        render()
        scheduleNext()
        return TimeInterval(playback.leadDurationMs) / 1000
    }

    private func render() {
        guard index < playback.frames.count else { return }
        view.show(atlas.cell(playback.frames[index]))
    }

    private func scheduleNext() {
        guard playback.frames.count > 1 || playback.loopStartIndex != nil else { return }
        guard index < playback.frames.count else { return }
        let delay = TimeInterval(playback.frames[index].durationMs) / 1000
        let work = DispatchWorkItem { [weak self] in self?.advance() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func advance() {
        let next = index + 1
        if next >= playback.frames.count {
            guard let loopStart = playback.loopStartIndex else { return }
            index = loopStart
        } else {
            index = next
        }
        render()
        scheduleNext()
    }
}

// MARK: - Random motion scheduler

enum MoveKind: Hashable {
    case action(Action)
    case lookAround

    var label: String {
        switch self {
        case .action(let action): return action.rawValue
        case .lookAround: return "look-around"
        }
    }
}

struct MotionPicker {
    /// Every non-idle row, plus the look directions, with equal odds. Rows are not
    /// weighted or filtered on purpose: whatever a new release draws in a row simply
    /// shows up, so changing the artwork never means changing this app.
    static let kinds: [MoveKind] = Action.allCases.map { MoveKind.action($0) } + [.lookAround]

    var includeLookAround = true
    var previous: MoveKind?

    mutating func next() -> MoveKind {
        var pool = Self.kinds.filter { $0 != previous }
        if !includeLookAround { pool = pool.filter { $0 != .lookAround } }
        if pool.isEmpty { pool = Self.kinds }
        let kind = pool[Int.random(in: 0..<pool.count)]
        previous = kind
        return kind
    }

    static func motion(for kind: MoveKind) -> Motion {
        switch kind {
        case .action(let action):
            return .action(action)
        case .lookAround:
            var holds: [LookHold] = []
            var last = -1
            for _ in 0..<Int.random(in: 1...3) {
                var direction = Int.random(in: 0..<Atlas.lookDirections)
                if direction == last { direction = (direction + 1) % Atlas.lookDirections }
                last = direction
                holds.append(LookHold(direction: direction, holdMs: Int.random(in: 600...1200)))
            }
            return .lookAround(holds)
        }
    }
}

// MARK: - Controller

final class PetController: NSObject {
    private let atlas: AtlasImage
    private let window: NSWindow
    private let view: PetView
    private let animator: PetAnimator
    private var settings: Settings
    private var picker: MotionPicker
    private var state: PersistedState
    private var nextMove: DispatchWorkItem?
    private var releaseHold: DispatchWorkItem?
    private var isPaused = false
    private var isHovering = false
    private var isBusy = false
    private var isHolding = false
    private var dragDirection = 0
    private let startedAt = Date()

    init(atlas: AtlasImage, settings: Settings) {
        self.atlas = atlas
        self.settings = settings
        self.picker = MotionPicker(includeLookAround: settings.lookAround)
        self.state = PersistedState.load()

        let scale = state.scale ?? settings.scale
        let size = Self.size(for: scale)
        let view = PetView(frame: NSRect(origin: .zero, size: size))
        self.view = view
        self.animator = PetAnimator(atlas: atlas, view: view)
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: .borderless,
                          backing: .buffered,
                          defer: false)
        super.init()

        self.settings.scale = scale
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = Self.collectionBehavior(allSpaces: settings.allSpaces)
        window.isMovableByWindowBackground = false
        window.acceptsMouseMovedEvents = true
        window.contentView = view
        window.setFrameOrigin(state.origin ?? Self.defaultOrigin(for: size))

        view.petMenu = buildMenu()
        view.onHoverChange = { [weak self] hovering in self?.handleHover(hovering) }
        view.onDragDirection = { [weak self] dx in self?.handleDrag(dx) }
        view.onDragEnd = { [weak self] in self?.handleDragEnd() }
    }

    private static func collectionBehavior(allSpaces: Bool) -> NSWindow.CollectionBehavior {
        allSpaces ? [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary] : [.fullScreenAuxiliary]
    }

    private static func size(for scale: CGFloat) -> NSSize {
        let width = (Atlas.baseWidth * scale).rounded()
        return NSSize(width: width, height: (width * Atlas.aspect).rounded())
    }

    private static func defaultOrigin(for size: NSSize) -> CGPoint {
        guard let frame = NSScreen.main?.visibleFrame else { return CGPoint(x: 100, y: 100) }
        return CGPoint(x: frame.maxX - size.width - 40, y: frame.minY + 40)
    }

    /// Tracking areas can miss an exit while a context menu is open, which would wedge
    /// the pet in its hover pose, so the pointer position decides.
    private var pointerIsOverPet: Bool {
        window.frame.contains(NSEvent.mouseLocation)
    }

    private func log(_ message: String) {
        guard settings.verbose else { return }
        let elapsed = Date().timeIntervalSince(startedAt)
        FileHandle.standardError.write(String(format: "%8.1fs  %@\n", elapsed, message).data(using: .utf8)!)
    }

    /// Keeps `motion` on screen for its full lead-in. Hover and scheduled motions stay out
    /// of the way until it finishes, which is what makes the menu actions usable: the
    /// pointer is necessarily over the pet while the menu is open.
    private func holdMotion(for duration: TimeInterval) {
        releaseHold?.cancel()
        isHolding = true
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.isHolding = false
            self.releaseHold = nil
            guard !self.isBusy else { return }
            let hovering = self.pointerIsOverPet
            self.isHovering = hovering
            self.animator.play(hovering ? .action(.jumping) : .idle)
            self.log("hold released, back to \(hovering ? "hover" : "idle")")
            self.scheduleNextMove()
        }
        releaseHold = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func start() {
        window.orderFrontRegardless()
        animator.play(.idle)
        scheduleNextMove()
    }

    // MARK: Scheduling

    private func scheduleNextMove(after extra: TimeInterval = 0) {
        nextMove?.cancel()
        guard !isPaused else { return }
        let delay = extra + Double.random(in: settings.minIntervalSeconds...settings.maxIntervalSeconds)
        let work = DispatchWorkItem { [weak self] in self?.fireMove() }
        nextMove = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func fireMove() {
        guard !isPaused else { return }
        // Never interrupt hover, a drag or a menu action; try again after a short breather.
        if isBusy || isHolding || pointerIsOverPet {
            log("skipped a scheduled motion")
            scheduleNextMove(after: 15)
            return
        }
        let lead = performRandomMove()
        scheduleNextMove(after: lead)
    }

    @discardableResult
    private func performRandomMove() -> TimeInterval {
        picker.includeLookAround = settings.lookAround
        let kind = picker.next()
        let lead = animator.play(MotionPicker.motion(for: kind))
        log("playing \(kind.label) for \(String(format: "%.1f", lead))s")
        return lead
    }

    // MARK: Interaction

    private func handleHover(_ hovering: Bool) {
        isHovering = hovering
        guard !isBusy, !isHolding else { return }
        log(hovering ? "hover" : "hover ended")
        animator.play(hovering ? .action(.jumping) : .idle)
    }

    private func handleDrag(_ dx: CGFloat) {
        isBusy = true
        isHolding = false
        releaseHold?.cancel()
        releaseHold = nil
        let direction = dx >= 4 ? 1 : (dx <= -4 ? -1 : 0)
        guard direction != 0, direction != dragDirection else { return }
        dragDirection = direction
        animator.play(.action(direction > 0 ? .runningRight : .runningLeft))
    }

    private func handleDragEnd() {
        isBusy = false
        dragDirection = 0
        isHovering = pointerIsOverPet
        animator.play(isHovering ? .action(.jumping) : .idle)
        state.origin = window.frame.origin
        state.scale = settings.scale
        state.save()
    }

    // MARK: Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Doopal", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())

        let now = NSMenuItem(title: "Do a Random Action", action: #selector(doRandomAction), keyEquivalent: "")
        now.target = self
        menu.addItem(now)

        let parade = NSMenuItem(title: "Play All Motions", action: #selector(playParade), keyEquivalent: "")
        parade.target = self
        menu.addItem(parade)

        let pause = NSMenuItem(title: "Pause Random Actions", action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        pause.tag = 1
        menu.addItem(pause)

        let look = NSMenuItem(title: "Look Around Sometimes", action: #selector(toggleLookAround), keyEquivalent: "")
        look.target = self
        look.tag = 2
        menu.addItem(look)

        let spaces = NSMenuItem(title: "Show on All Desktops", action: #selector(toggleAllSpaces), keyEquivalent: "")
        spaces.target = self
        spaces.tag = 3
        menu.addItem(spaces)

        menu.addItem(.separator())
        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for scale in [1.0, 1.5, 2.0] as [CGFloat] {
            let item = NSMenuItem(title: String(format: "%g×", scale), action: #selector(changeScale(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = scale
            sizeMenu.addItem(item)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Doopal", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        menu.delegate = self
        return menu
    }

    @objc private func doRandomAction() {
        nextMove?.cancel()
        holdMotion(for: performRandomMove())
    }

    @objc private func playParade() {
        nextMove?.cancel()
        let lead = animator.play(.sequence(Sprite.paradeFrames()))
        log("playing every motion for \(String(format: "%.1f", lead))s")
        holdMotion(for: lead)
    }

    @objc private func togglePause() {
        isPaused.toggle()
        if isPaused {
            nextMove?.cancel()
            nextMove = nil
        } else {
            scheduleNextMove()
        }
    }

    @objc private func toggleLookAround() {
        settings.lookAround.toggle()
    }

    @objc private func toggleAllSpaces() {
        settings.allSpaces.toggle()
        window.collectionBehavior = Self.collectionBehavior(allSpaces: settings.allSpaces)
    }

    @objc private func changeScale(_ sender: NSMenuItem) {
        guard let scale = sender.representedObject as? CGFloat else { return }
        settings.scale = scale
        let size = Self.size(for: scale)
        let origin = window.frame.origin
        window.setFrame(NSRect(origin: origin, size: size), display: true)
        view.frame = NSRect(origin: .zero, size: size)
        state.origin = origin
        state.scale = scale
        state.save()
    }

    @objc private func quit() {
        state.origin = window.frame.origin
        state.scale = settings.scale
        state.save()
        NSApp.terminate(nil)
    }
}

extension PetController: NSMenuDelegate {
    func menuDidClose(_ menu: NSMenu) {
        let hovering = pointerIsOverPet
        guard hovering != isHovering else { return }
        handleHover(hovering)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.item(withTag: 1)?.title = isPaused ? "Resume Random Actions" : "Pause Random Actions"
        menu.item(withTag: 2)?.state = settings.lookAround ? .on : .off
        menu.item(withTag: 3)?.state = settings.allSpaces ? .on : .off
        if let sizeMenu = menu.items.first(where: { $0.title == "Size" })?.submenu {
            for item in sizeMenu.items {
                let scale = item.representedObject as? CGFloat
                item.state = scale == settings.scale ? .on : .off
            }
        }
    }
}

// MARK: - Offscreen frame dump (verification without screen capture)

enum FrameDump {
    static func run(atlas: AtlasImage, directory: String) -> Int32 {
        let dir = URL(fileURLWithPath: (directory as NSString).expandingTildeInPath)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            FileHandle.standardError.write("cannot create \(dir.path): \(error)\n".data(using: .utf8)!)
            return 1
        }
        var wrote = 0
        var strips: [(String, [Frame])] = [("idle", Sprite.idle)]
        for action in Action.allCases {
            strips.append((action.rawValue, Sprite.frames(for: action)))
        }
        strips.append(("look-row9", (0..<8).map { Sprite.lookFrame(direction: $0, holdMs: 0) }))
        strips.append(("look-row10", (8..<16).map { Sprite.lookFrame(direction: $0, holdMs: 0) }))

        for (name, frames) in strips {
            guard let image = strip(atlas: atlas, frames: frames) else { continue }
            let url = dir.appendingPathComponent("state-\(name).png")
            guard write(image: image, to: url) else { continue }
            wrote += 1
            print("\(url.path)  (\(frames.count) frames)")
        }
        print("wrote \(wrote) strips")
        return wrote > 0 ? 0 : 1
    }

    private static func strip(atlas: AtlasImage, frames: [Frame]) -> CGImage? {
        guard !frames.isEmpty else { return nil }
        let width = atlas.cellWidth * frames.count
        let height = atlas.cellHeight
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .none
        // Checkerboard so transparent padding is visible in the dump.
        context.setFillColor(CGColor(gray: 0.16, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for (i, frame) in frames.enumerated() {
            guard let cell = atlas.cell(frame) else { continue }
            context.draw(cell, in: CGRect(x: i * atlas.cellWidth, y: 0,
                                          width: atlas.cellWidth, height: atlas.cellHeight))
        }
        return context.makeImage()
    }

    static func write(image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
}

// MARK: - Iconset generation (build.sh turns this into Doopal.icns)

enum IconDump {
    private static let variants: [(base: Int, scale: Int)] = [
        (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
    ]

    static func run(atlas: AtlasImage, directory: String) -> Int32 {
        let dir = URL(fileURLWithPath: (directory as NSString).expandingTildeInPath)
        guard let cell = atlas.cell(row: 0, column: 0) else {
            FileHandle.standardError.write("cannot read the idle frame\n".data(using: .utf8)!)
            return 1
        }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            FileHandle.standardError.write("cannot create \(dir.path): \(error)\n".data(using: .utf8)!)
            return 1
        }
        var wrote = 0
        for variant in variants {
            let pixels = variant.base * variant.scale
            guard let context = CGContext(data: nil, width: pixels, height: pixels,
                                          bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
            context.interpolationQuality = .none
            // Fit the cell inside the icon with a small margin, sitting on the baseline.
            let height = CGFloat(pixels) * 0.94
            let width = height * CGFloat(atlas.cellWidth) / CGFloat(atlas.cellHeight)
            let rect = CGRect(x: (CGFloat(pixels) - width) / 2,
                              y: CGFloat(pixels) * 0.03,
                              width: width, height: height)
            context.draw(cell, in: rect)
            guard let image = context.makeImage() else { continue }
            let suffix = variant.scale == 1 ? "" : "@\(variant.scale)x"
            let name = "icon_\(variant.base)x\(variant.base)\(suffix).png"
            if FrameDump.write(image: image, to: dir.appendingPathComponent(name)) { wrote += 1 }
        }
        print("wrote \(wrote) icon images to \(dir.path)")
        return wrote == variants.count ? 0 : 1
    }
}

// MARK: - Scheduler self-test (no window, no permissions)

enum SelfTest {
    static func run(settings: Settings, samples: Int) -> Int32 {
        var picker = MotionPicker(includeLookAround: settings.lookAround)
        var counts: [String: Int] = [:]
        var intervals: [Double] = []
        var previous: String?
        var repeats = 0
        var clock = 0.0

        for i in 0..<samples {
            let interval = Double.random(in: settings.minIntervalSeconds...settings.maxIntervalSeconds)
            let kind = picker.next()
            let motion = MotionPicker.motion(for: kind)
            let lead = Double(Sprite.playback(motion).leadDurationMs) / 1000
            if kind.label == previous { repeats += 1 }
            previous = kind.label
            counts[kind.label, default: 0] += 1
            intervals.append(interval)
            clock += interval + lead
            if i < 12 {
                let label = kind.label.padding(toLength: 14, withPad: " ", startingAt: 0)
                print(String(format: "  +%6.1fs  %@  motion %4.1fs", interval, label, lead))
            }
        }

        let mean = intervals.reduce(0, +) / Double(intervals.count)
        print(String(format: "\nintervals: min %.1fs  max %.1fs  mean %.1fs  (configured %.0f–%.0fs)",
                     intervals.min() ?? 0, intervals.max() ?? 0, mean,
                     settings.minIntervalSeconds, settings.maxIntervalSeconds))
        print(String(format: "%d motions over %.1f hours of simulated time", samples, clock / 3600))
        print("back-to-back repeats: \(repeats) (expected 0)")
        for (label, count) in counts.sorted(by: { $0.value > $1.value }) {
            let share = Double(count) / Double(samples) * 100
            let padded = label.padding(toLength: 14, withPad: " ", startingAt: 0)
            print(String(format: "  %@ %5d  %5.1f%%", padded, count, share))
        }
        let inRange = intervals.allSatisfy {
            $0 >= settings.minIntervalSeconds - 0.001 && $0 <= settings.maxIntervalSeconds + 0.001
        }
        let ok = repeats == 0 && inRange
        print(ok ? "\nOK" : "\nFAILED")
        return ok ? 0 : 1
    }
}

// MARK: - Command line

struct Options {
    var settings = Settings.load()
    var dumpFrames: String?
    var dumpIcon: String?
    var selfTest: Int?
    var showHelp = false
}

func parseArguments() -> Options? {
    var options = Options()
    var arguments = Array(CommandLine.arguments.dropFirst())
    func value(_ flag: String) -> String? {
        guard let first = arguments.first else {
            FileHandle.standardError.write("\(flag) needs a value\n".data(using: .utf8)!)
            return nil
        }
        arguments.removeFirst()
        return first
    }
    while let argument = arguments.first {
        arguments.removeFirst()
        switch argument {
        case "-h", "--help":
            options.showHelp = true
        case "--min-interval":
            guard let raw = value(argument), let v = Double(raw) else { return nil }
            options.settings.minIntervalSeconds = v
        case "--max-interval":
            guard let raw = value(argument), let v = Double(raw) else { return nil }
            options.settings.maxIntervalSeconds = v
        case "--scale":
            guard let raw = value(argument), let v = Double(raw) else { return nil }
            options.settings.scale = CGFloat(v)
        case "--no-look":
            options.settings.lookAround = false
        case "--single-space":
            options.settings.allSpaces = false
        case "--verbose":
            options.settings.verbose = true
        case "--sprite":
            guard let raw = value(argument) else { return nil }
            options.settings.spritesheetPath = raw
        case "--dump-frames":
            guard let raw = value(argument) else { return nil }
            options.dumpFrames = raw
        case "--dump-icon":
            guard let raw = value(argument) else { return nil }
            options.dumpIcon = raw
        case "--selftest":
            if let raw = arguments.first, let n = Int(raw) {
                arguments.removeFirst()
                options.selfTest = n
            } else {
                options.selfTest = 400
            }
        default:
            FileHandle.standardError.write("unknown option: \(argument)\n".data(using: .utf8)!)
            return nil
        }
    }
    options.settings.normalize()
    return options
}

let help = """
DoopalSolo — 두팔이 as a standalone desktop pet.

Renders the installed Doopal spritesheet with the same frame timings the Codex
desktop app uses, and plays one random motion every few minutes on its own,
drawn evenly from every non-idle row.

Usage: doopal-solo [options]

  --min-interval SEC   shortest wait between random motions (default 180)
  --max-interval SEC   longest wait between random motions (default 600)
  --scale N            pet size multiplier, 0.5–4 (default 1)
  --no-look            never use the look-direction frames
  --single-space       stay on the Space the pet was placed on
  --verbose            log motions, hover and drags to stderr
  --sprite PATH        use a specific spritesheet instead of the installed one
  --dump-frames DIR    write one PNG strip per state and exit
  --dump-icon DIR      write an .iconset of the idle pose and exit
  --selftest [N]       simulate N scheduling decisions and exit
  -h, --help           show this help

Config file (optional): ~/.config/doopal-solo.json
  { "minIntervalSeconds": 180, "maxIntervalSeconds": 600,
    "lookAround": true, "allSpaces": true, "scale": 1 }

Window position and size are remembered in
~/Library/Application Support/doopal-solo/state.json

Right-click the pet for actions, size, pause and quit. Drag it to move it.
"""

guard let options = parseArguments() else { exit(2) }
if options.showHelp {
    print(help)
    exit(0)
}

if let samples = options.selfTest {
    exit(SelfTest.run(settings: options.settings, samples: samples))
}

guard let spriteURL = SpriteLocator.resolve(explicit: options.settings.spritesheetPath) else {
    let tried = SpriteLocator.candidates(explicit: options.settings.spritesheetPath)
        .map { "  \($0.path)" }.joined(separator: "\n")
    FileHandle.standardError.write("""
    No Doopal spritesheet found. Install the pet with ./scripts/install.sh, or pass
    --sprite PATH. Looked in:
    \(tried)

    """.data(using: .utf8)!)
    exit(1)
}

guard let atlas = AtlasImage(url: spriteURL) else {
    FileHandle.standardError.write("cannot decode \(spriteURL.path)\n".data(using: .utf8)!)
    exit(1)
}

if !atlas.describesExpectedAtlas {
    FileHandle.standardError.write("""
    warning: \(spriteURL.lastPathComponent) is \(atlas.image.width)x\(atlas.image.height), \
    expected \(Atlas.expectedWidth)x\(Atlas.expectedHeight); \
    using a \(atlas.cellWidth)x\(atlas.cellHeight) cell grid.

    """.data(using: .utf8)!)
}

if let directory = options.dumpFrames {
    exit(FrameDump.run(atlas: atlas, directory: directory))
}

if let directory = options.dumpIcon {
    exit(IconDump.run(atlas: atlas, directory: directory))
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let controller = PetController(atlas: atlas, settings: options.settings)
controller.start()
application.run()
