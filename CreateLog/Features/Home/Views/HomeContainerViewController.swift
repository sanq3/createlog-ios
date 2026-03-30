import SwiftUI
import UIKit

struct HomeContainerRepresentable: UIViewControllerRepresentable {
    @Binding var tabBarOffset: CGFloat
    @Binding var showSideMenu: Bool
    @Binding var sideMenuDragOffset: CGFloat

    func makeUIViewController(context: Context) -> HomeContainerViewController {
        let controller = HomeContainerViewController()
        controller.configureBindings(
            tabBarOffset: { value in
                tabBarOffset = value
            },
            showSideMenu: { value in
                showSideMenu = value
            },
            sideMenuDragOffset: { value in
                sideMenuDragOffset = value
            }
        )
        controller.syncSideMenuState(isOpen: showSideMenu)
        return controller
    }

    func updateUIViewController(_ uiViewController: HomeContainerViewController, context: Context) {
        uiViewController.configureBindings(
            tabBarOffset: { value in
                tabBarOffset = value
            },
            showSideMenu: { value in
                showSideMenu = value
            },
            sideMenuDragOffset: { value in
                sideMenuDragOffset = value
            }
        )
        uiViewController.syncSideMenuState(isOpen: showSideMenu)
    }
}

private enum HomeHorizontalMode {
    case page
    case sideMenu
}

@MainActor
final class HomeContainerViewController: UIViewController {
    private let headerModel = HomeHeaderModel()
    private lazy var headerHostingController = UIHostingController(
        rootView: HomeHeaderChromeView(model: headerModel)
    )

    private let pagesClipView = UIView()
    private let pagesTrackView = UIView()
    private let pagesStackView = UIStackView()

    private lazy var timelineController = HomeTimelinePageViewController(posts: MockData.posts)
    private lazy var followingController = HomeTimelinePageViewController(posts: filteredFollowingPosts)

    private var setTabBarOffset: ((CGFloat) -> Void)?
    private var setShowSideMenu: ((Bool) -> Void)?
    private var setSideMenuDragOffset: ((CGFloat) -> Void)?

    private var currentPage = 0
    private var horizontalMode: HomeHorizontalMode?
    private var pageDragTranslation: CGFloat = 0
    private var headerHiddenOffset: CGFloat = 0
    private var tabBarOffsetValue: CGFloat = 0
    private var currentScrollOffset: CGFloat = 0
    private var headerHeight: CGFloat = 0
    private var lastMeasuredWidth: CGFloat = 0
    private var isSideMenuOpen = false

    private var headerHeightConstraint: NSLayoutConstraint?

    private let tabBarHeight: CGFloat = 90
    private let topContentSpacing: CGFloat = 12
    private let bottomContentInset: CGFloat = 60
    private let swipeVelocityThreshold: CGFloat = 500
    private let menuWidthRatio: CGFloat = 0.82
    private let noiseThreshold: CGFloat = 0.5
    private let horizontalActivationThreshold: CGFloat = 6

    private var filteredFollowingPosts: [Post] {
        let handles = Set(MockData.users.filter(\.isFollowing).map(\.handle))
        let filtered = MockData.posts.filter { handles.contains($0.handle) }
        return filtered.isEmpty ? Array(MockData.posts.prefix(3)) : filtered
    }

    private var currentTimelineController: HomeTimelinePageViewController {
        currentPage == 0 ? timelineController : followingController
    }

    private lazy var horizontalPanGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleHorizontalPan(_:)))
        gesture.delegate = self
        gesture.maximumNumberOfTouches = 1
        gesture.cancelsTouchesInView = true
        gesture.delaysTouchesBegan = true
        return gesture
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Color.clBackground)

        timelineController.delegate = self
        followingController.delegate = self

        setupHeader()
        setupPages()
        bindHeaderActions()

        view.addGestureRecognizer(horizontalPanGesture)

        applyPageTransform()
        updateHeaderProgress(animated: false)
        applyChrome(animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateHeaderHeightIfNeeded()

        let width = view.bounds.width
        guard width > 0 else { return }

        if abs(lastMeasuredWidth - width) > 1 {
            lastMeasuredWidth = width
            applyPageTransform()
            updateHeaderProgress(animated: false)
        }
    }

    func configureBindings(
        tabBarOffset: @escaping (CGFloat) -> Void,
        showSideMenu: @escaping (Bool) -> Void,
        sideMenuDragOffset: @escaping (CGFloat) -> Void
    ) {
        setTabBarOffset = tabBarOffset
        setShowSideMenu = showSideMenu
        setSideMenuDragOffset = sideMenuDragOffset
    }

    func syncSideMenuState(isOpen: Bool) {
        isSideMenuOpen = isOpen
    }

    private func setupHeader() {
        addChild(headerHostingController)
        view.addSubview(headerHostingController.view)
        headerHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        headerHostingController.view.backgroundColor = .clear

        let heightConstraint = headerHostingController.view.heightAnchor.constraint(equalToConstant: 92)
        headerHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            headerHostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerHostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerHostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heightConstraint,
        ])

        headerHostingController.didMove(toParent: self)
    }

    private func setupPages() {
        pagesClipView.translatesAutoresizingMaskIntoConstraints = false
        pagesClipView.clipsToBounds = true
        pagesClipView.backgroundColor = .clear
        view.addSubview(pagesClipView)

        NSLayoutConstraint.activate([
            pagesClipView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pagesClipView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pagesClipView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pagesClipView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        pagesTrackView.translatesAutoresizingMaskIntoConstraints = false
        pagesTrackView.backgroundColor = .clear
        pagesClipView.addSubview(pagesTrackView)

        NSLayoutConstraint.activate([
            pagesTrackView.topAnchor.constraint(equalTo: pagesClipView.topAnchor),
            pagesTrackView.leadingAnchor.constraint(equalTo: pagesClipView.leadingAnchor),
            pagesTrackView.bottomAnchor.constraint(equalTo: pagesClipView.bottomAnchor),
            pagesTrackView.widthAnchor.constraint(equalTo: pagesClipView.widthAnchor, multiplier: 2),
        ])

        pagesStackView.translatesAutoresizingMaskIntoConstraints = false
        pagesStackView.axis = .horizontal
        pagesStackView.distribution = .fillEqually
        pagesStackView.alignment = .fill
        pagesTrackView.addSubview(pagesStackView)

        NSLayoutConstraint.activate([
            pagesStackView.topAnchor.constraint(equalTo: pagesTrackView.topAnchor),
            pagesStackView.leadingAnchor.constraint(equalTo: pagesTrackView.leadingAnchor),
            pagesStackView.trailingAnchor.constraint(equalTo: pagesTrackView.trailingAnchor),
            pagesStackView.bottomAnchor.constraint(equalTo: pagesTrackView.bottomAnchor),
        ])

        embedPageController(timelineController)
        embedPageController(followingController)
    }

    private func embedPageController(_ controller: HomeTimelinePageViewController) {
        addChild(controller)
        pagesStackView.addArrangedSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.didMove(toParent: self)
    }

    private func bindHeaderActions() {
        headerModel.onAvatarTap = { [weak self] in
            guard let self else { return }
            HapticManager.light()
            self.openSideMenu()
        }

        headerModel.onBellTap = { [weak self] in
            self?.pushNotifications()
        }

        headerModel.onTabTap = { [weak self] index in
            guard let self else { return }
            HapticManager.light()
            self.switchToPage(index, animated: true)
        }
    }

    private func updateHeaderHeightIfNeeded() {
        let targetSize = headerHostingController.sizeThatFits(
            in: CGSize(width: view.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        )
        guard abs(headerHeight - targetSize.height) > 0.5 else { return }

        headerHeight = targetSize.height
        headerHeightConstraint?.constant = targetSize.height
        updatePageInsets()
        applyChrome(animated: false)
    }

    private func updatePageInsets() {
        let topInset = headerHeight + topContentSpacing
        timelineController.updateInsets(top: topInset, bottom: bottomContentInset)
        followingController.updateInsets(top: topInset, bottom: bottomContentInset)
    }

    private func switchToPage(_ index: Int, animated: Bool) {
        guard index != currentPage else {
            settlePageAnimation(targetIndex: index, animated: animated)
            return
        }

        currentPage = index
        headerModel.currentPage = index
        pageDragTranslation = 0
        settlePageAnimation(targetIndex: index, animated: animated)
        synchronizeChromeWithCurrentPage(animated: animated)
    }

    private func applyPageTransform() {
        let x = -CGFloat(currentPage) * view.bounds.width + pageDragTranslation
        pagesTrackView.transform = CGAffineTransform(translationX: x, y: 0)
    }

    private func updateHeaderProgress(animated: Bool) {
        let width = max(view.bounds.width, 1)
        let progress = max(0, min(1, CGFloat(currentPage) - pageDragTranslation / width))

        if animated {
            withAnimation(.spring(duration: 0.28, bounce: 0.08)) {
                headerModel.progress = progress
            }
        } else {
            headerModel.progress = progress
        }
    }

    private func settlePageAnimation(targetIndex: Int, animated: Bool) {
        let animations = {
            self.pageDragTranslation = 0
            self.applyPageTransform()
        }

        if animated {
            UIView.animate(
                withDuration: 0.28,
                delay: 0,
                usingSpringWithDamping: 0.92,
                initialSpringVelocity: 0.8,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                animations()
            }
            updateHeaderProgress(animated: true)
        } else {
            animations()
            updateHeaderProgress(animated: false)
        }
    }

    private func applyChrome(animated: Bool) {
        let block = {
            self.headerHostingController.view.transform = CGAffineTransform(
                translationX: 0,
                y: -self.headerHiddenOffset
            )
            self.setTabBarOffset?(self.tabBarOffsetValue)
        }

        if animated {
            UIView.animate(
                withDuration: 0.2,
                delay: 0,
                usingSpringWithDamping: 1,
                initialSpringVelocity: 0,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                block()
            }
        } else {
            block()
        }
    }

    private func openSideMenu() {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            setSideMenuDragOffset?(0)
            setShowSideMenu?(true)
        }
    }

    private func pushNotifications() {
        let controller = UIHostingController(rootView: NotificationsView())
        navigationController?.pushViewController(controller, animated: true)
    }

    private func pushPostDetail(_ post: Post) {
        let controller = UIHostingController(rootView: PostDetailView(post: post))
        navigationController?.pushViewController(controller, animated: true)
    }

    private func synchronizeChromeWithCurrentPage(animated: Bool) {
        let targetOffset = currentTimelineController.currentContentOffset
        currentScrollOffset = targetOffset

        guard targetOffset <= 0 else { return }

        headerHiddenOffset = 0
        tabBarOffsetValue = 0
        applyChrome(animated: animated)
    }

    @objc
    private func handleHorizontalPan(_ recognizer: UIPanGestureRecognizer) {
        guard !isSideMenuOpen else { return }

        let translationX = recognizer.translation(in: view).x
        let velocityX = recognizer.velocity(in: view).x

        switch recognizer.state {
        case .began:
            horizontalMode = nil
        case .changed:
            if horizontalMode == nil {
                horizontalMode = resolveHorizontalMode(for: translationX)
            }

            guard let horizontalMode else { return }

            switch horizontalMode {
            case .page:
                pageDragTranslation = clampedPageTranslation(for: translationX)
                applyPageTransform()
                updateHeaderProgress(animated: false)
            case .sideMenu:
                let drag = max(0, min(view.bounds.width * menuWidthRatio, translationX))
                setSideMenuDragOffset?(drag)
            }
        case .ended, .cancelled, .failed:
            guard let horizontalMode else { return }

            switch horizontalMode {
            case .page:
                settlePagePan(translationX: translationX, velocityX: velocityX)
            case .sideMenu:
                settleSideMenuPan(translationX: translationX, velocityX: velocityX)
            }

            self.horizontalMode = nil
        default:
            break
        }
    }

    private func resolveHorizontalMode(for translationX: CGFloat) -> HomeHorizontalMode? {
        guard abs(translationX) >= horizontalActivationThreshold else {
            return nil
        }

        if currentPage == 0 && translationX > 0 {
            return .sideMenu
        }

        return .page
    }

    private func clampedPageTranslation(for translationX: CGFloat) -> CGFloat {
        switch currentPage {
        case 0:
            return max(-view.bounds.width, min(0, translationX))
        case 1:
            return min(view.bounds.width, max(0, translationX))
        default:
            return 0
        }
    }

    private func settlePagePan(translationX: CGFloat, velocityX: CGFloat) {
        var targetIndex = currentPage

        if currentPage == 0 {
            if translationX < -(view.bounds.width * 0.5) || velocityX < -swipeVelocityThreshold {
                targetIndex = 1
            }
        } else if translationX > view.bounds.width * 0.5 || velocityX > swipeVelocityThreshold {
            targetIndex = 0
        }

        currentPage = targetIndex
        headerModel.currentPage = targetIndex
        settlePageAnimation(targetIndex: targetIndex, animated: true)
        synchronizeChromeWithCurrentPage(animated: true)
    }

    private func settleSideMenuPan(translationX: CGFloat, velocityX: CGFloat) {
        let menuWidth = view.bounds.width * menuWidthRatio
        let shouldOpen = translationX > menuWidth * 0.5 || velocityX > swipeVelocityThreshold

        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            setShowSideMenu?(shouldOpen)
            setSideMenuDragOffset?(0)
        }
    }
}

extension HomeContainerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard
            !isSideMenuOpen,
            let panGesture = gestureRecognizer as? UIPanGestureRecognizer
        else {
            return false
        }

        let velocity = panGesture.velocity(in: view)
        return abs(velocity.x) > abs(velocity.y) * 1.2
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }
}

@MainActor
extension HomeContainerViewController: HomeTimelinePageViewControllerDelegate {
    func timelinePage(
        _ controller: HomeTimelinePageViewController,
        didScrollTo offset: CGFloat,
        delta: CGFloat
    ) {
        guard controller === currentTimelineController else { return }

        currentScrollOffset = offset

        guard offset > 0 else {
            headerHiddenOffset = 0
            tabBarOffsetValue = 0
            applyChrome(animated: false)
            return
        }

        guard abs(delta) > noiseThreshold else { return }

        headerHiddenOffset = min(headerHeight, max(0, headerHiddenOffset + delta))
        tabBarOffsetValue = min(tabBarHeight, max(0, tabBarOffsetValue + delta))
        applyChrome(animated: false)
    }

    func timelinePageDidEndScrolling(_ controller: HomeTimelinePageViewController) {
        guard controller === currentTimelineController else { return }

        if currentScrollOffset <= 0 {
            headerHiddenOffset = 0
            tabBarOffsetValue = 0
            applyChrome(animated: true)
            return
        }

        let headerHiddenRatio = headerHeight > 0 ? headerHiddenOffset / headerHeight : 0
        let tabBarHiddenRatio = tabBarHeight > 0 ? tabBarOffsetValue / tabBarHeight : 0
        let shouldHide = max(headerHiddenRatio, tabBarHiddenRatio) > 0.5

        headerHiddenOffset = shouldHide ? headerHeight : 0
        tabBarOffsetValue = shouldHide ? tabBarHeight : 0
        applyChrome(animated: true)
    }

    func timelinePage(_ controller: HomeTimelinePageViewController, didSelect post: Post) {
        pushPostDetail(post)
    }
}

@MainActor
protocol HomeTimelinePageViewControllerDelegate: AnyObject {
    func timelinePage(_ controller: HomeTimelinePageViewController, didScrollTo offset: CGFloat, delta: CGFloat)
    func timelinePageDidEndScrolling(_ controller: HomeTimelinePageViewController)
    func timelinePage(_ controller: HomeTimelinePageViewController, didSelect post: Post)
}

final class HomeTimelinePageViewController: UIViewController {
    weak var delegate: HomeTimelinePageViewControllerDelegate?

    private let posts: [Post]
    private let tableView = UITableView(frame: .zero, style: .plain)

    private var hasAppliedInitialOffset = false
    private(set) var currentContentOffset: CGFloat = 0

    init(posts: [Post]) {
        self.posts = posts
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(Color.clBackground)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.isDirectionalLockEnabled = true
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PostCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 280

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func updateInsets(top: CGFloat, bottom: CGFloat) {
        let previousTop = tableView.contentInset.top

        tableView.contentInset.top = top
        tableView.verticalScrollIndicatorInsets.top = top
        tableView.contentInset.bottom = bottom
        tableView.verticalScrollIndicatorInsets.bottom = bottom

        if !hasAppliedInitialOffset {
            tableView.setContentOffset(CGPoint(x: 0, y: -top), animated: false)
            currentContentOffset = 0
            hasAppliedInitialOffset = true
            return
        }

        let topDelta = top - previousTop
        if abs(topDelta) > 0.5 {
            tableView.contentOffset.y -= topDelta
        }

        currentContentOffset = max(0, tableView.contentOffset.y + tableView.contentInset.top)
    }
}

extension HomeTimelinePageViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        posts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PostCell", for: indexPath)
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = .clear
        cell.contentConfiguration = UIHostingConfiguration {
            PostCardView(post: posts[indexPath.row])
                .contentShape(Rectangle())
        }
        .margins(.all, 0)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.timelinePage(self, didSelect: posts[indexPath.row])
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = max(0, scrollView.contentOffset.y + scrollView.contentInset.top)
        let delta = offset - currentContentOffset
        currentContentOffset = offset
        delegate?.timelinePage(self, didScrollTo: offset, delta: delta)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            delegate?.timelinePageDidEndScrolling(self)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        delegate?.timelinePageDidEndScrolling(self)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        delegate?.timelinePageDidEndScrolling(self)
    }
}

@MainActor
final class HomeHeaderModel: ObservableObject {
    @Published var currentPage: Int = 0
    @Published var progress: CGFloat = 0

    var onAvatarTap: (() -> Void)?
    var onBellTap: (() -> Void)?
    var onTabTap: ((Int) -> Void)?
}

private struct HomeHeaderChromeView: View {
    @ObservedObject var model: HomeHeaderModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Button(action: { model.onAvatarTap?() }) {
                        AvatarView(
                            initials: MockData.currentUser.initials,
                            size: 28,
                            status: MockData.currentUser.status
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: { model.onBellTap?() }) {
                        Image(systemName: "bell")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(Color.clTextSecondary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 6) {
                    HStack(spacing: -5) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color(hue: Double(index) * 0.3, saturation: 0.2, brightness: 0.5))
                                .frame(width: 18, height: 18)
                                .overlay(Circle().strokeBorder(Color.clBackground, lineWidth: 1.5))
                        }
                    }

                    Text("3人が作業中")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.clTextSecondary)

                    Circle()
                        .fill(Color.clSuccess)
                        .frame(width: 5, height: 5)
                        .modifier(PulseModifier())
                }
                .allowsHitTesting(false)
            }
            .frame(height: 36)
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    tabButton(title: "タイムライン", index: 0)
                    tabButton(title: "フォロー中", index: 1)
                }
                .frame(maxWidth: .infinity)

                GeometryReader { geometry in
                    let tabWidth = geometry.size.width / 2
                    let clampedProgress = max(0, min(1, model.progress))

                    Capsule()
                        .fill(Color.clAccent)
                        .frame(width: 28, height: 3)
                        .position(
                            x: tabWidth / 2 + clampedProgress * tabWidth,
                            y: 1.5
                        )
                }
                .frame(height: 3)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color.clBackground)
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button(action: { model.onTabTap?(index) }) {
            Text(title)
                .font(.system(size: 15, weight: model.currentPage == index ? .bold : .regular))
                .foregroundStyle(model.currentPage == index ? Color.clTextPrimary : Color.clTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
