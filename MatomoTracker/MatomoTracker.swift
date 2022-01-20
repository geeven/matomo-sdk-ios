import Foundation

/// The Matomo Tracker is a Swift framework to send analytics to the Matomo server.
///
/// ## Basic Usage
/// * Use the track methods to track your views, events and more.
final public class MatomoTracker: NSObject {
    
    /// Defines if the user opted out of tracking. When set to true, every event
    /// will be discarded immediately. This property is persisted between app launches.
    @objc public var isOptedOut: Bool {
        get {
            return matomoUserDefaults.optOut
        }
        set {
            matomoUserDefaults.optOut = newValue
        }
    }
    
    /// Will be used to associate all future events with a given userID. This property
    /// is persisted between app launches.
    @objc public var userId: String? {
        get {
            return matomoUserDefaults.visitorUserId
        }
        set {
            matomoUserDefaults.visitorUserId = newValue
            visitor = Visitor.current(in: matomoUserDefaults)
        }
    }
    
    @available(*, deprecated, message: "use userId instead")
    @objc public var visitorId: String? {
        get {
            return userId
        }
        set {
            userId = newValue
        }
    }
    
    /// Will be used to associate all future events with a given visitorId / cid. This property
    /// is persisted between app launches.
    /// The `forcedVisitorId` can only be a 16 character long hexadecimal string. Setting an invalid
    /// string will have no effect.
    @objc public var forcedVisitorId: String? {
        get {
            return matomoUserDefaults.forcedVisitorId
        }
        set {
            logger.debug("Setting the forcedVisitorId to \(forcedVisitorId ?? "nil")")
            if let newValue = newValue {
                let isValidString = UInt64(newValue, radix: 16) != nil && newValue.count == 16
                if isValidString {
                    matomoUserDefaults.forcedVisitorId = newValue
                } else {
                    logger.error("forcedVisitorId is invalid. It must be a 16 character long hex string.")
                    logger.error("forcedVisitorId is still \(forcedVisitorId ?? "nil")")
                }
            } else {
                matomoUserDefaults.forcedVisitorId = nil
            }
            visitor = Visitor.current(in: matomoUserDefaults)
        }
    }
    
    internal var matomoUserDefaults: MatomoUserDefaults
    private let dispatcher: Dispatcher
    private var queue: Queue
    internal let siteId: String

    internal var dimensions: [CustomDimension] = []
    
    internal var customVariables: [CustomVariable] = []
    
    /// This logger is used to perform logging of all sorts of Matomo related information.
    /// Per default it is a `DefaultLogger` with a `minLevel` of `LogLevel.warning`. You can
    /// set your own Logger with a custom `minLevel` or a complete custom logging mechanism.
    @objc public var logger: Logger = DefaultLogger(minLevel: .warning)
    
    /// The `contentBase` is used to build the url of an Event, if the Event hasn't got a url set.
    /// This autogenerated url will then have the format <contentBase>/<actions>.
    /// Per default the `contentBase` is http://<Application Bundle Name>.
    /// Set the `contentBase` to nil, if you don't want to auto generate a url.
    @objc public var contentBase: URL?
    
    internal static var _sharedInstance: MatomoTracker?
    
    /// Create and Configure a new Tracker
    ///
    /// - Parameters:
    ///   - siteId: The unique site id generated by the server when a new site was created.
    ///   - queue: The queue to use to store all analytics until it is dispatched to the server.
    ///   - dispatcher: The dispatcher to use to transmit all analytics to the server.
    required public init(siteId: String, queue: Queue, dispatcher: Dispatcher) {
        self.siteId = siteId
        self.queue = queue
        self.dispatcher = dispatcher
        self.contentBase = URL(string: "http://\(Application.makeCurrentApplication().bundleIdentifier ?? "unknown")")
        self.matomoUserDefaults = MatomoUserDefaults(suiteName: "\(siteId)\(dispatcher.baseURL.absoluteString)")
        self.visitor = Visitor.current(in: matomoUserDefaults)
        self.session = Session.current(in: matomoUserDefaults)
        super.init()
        startNewSession()
        startDispatchTimer()
    }
    
    /// Create and Configure a new Tracker
    ///
    /// A volatile memory queue will be used to store the analytics data. All not transmitted data will be lost when the application gets terminated.
    /// The URLSessionDispatcher will be used to transmit the data to the server.
    ///
    /// - Parameters:
    ///   - siteId: The unique site id generated by the server when a new site was created.
    ///   - baseURL: The url of the Matomo server. This url has to end in `piwik.php` or `matomo.php`.
    ///   - userAgent: An optional parameter for custom user agent.
    @objc convenience public init(siteId: String, baseURL: URL, userAgent: String? = nil) {
        let validSuffix = baseURL.absoluteString.hasSuffix("piwik.php") ||
            baseURL.absoluteString.hasSuffix("matomo.php")
        assert(validSuffix, "The baseURL is expected to end in piwik.php or matomo.php")
        
        let queue = MemoryQueue()
        let dispatcher = URLSessionDispatcher(baseURL: baseURL, userAgent: userAgent)
        self.init(siteId: siteId, queue: queue, dispatcher: dispatcher)
    }
    
    internal func queue(event: Event) {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync {
                self.queue(event: event)
            }
            return
        }
        guard !isOptedOut else { return }
        logger.verbose("Queued event: \(event)")
        queue.enqueue(event: event)
        nextEventStartsANewSession = false
    }
    
    // MARK: dispatching
    
    private let numberOfEventsDispatchedAtOnce = 20
    private(set) var isDispatching = false
    
    
    /// Manually start the dispatching process. You might want to call this method in AppDelegates `applicationDidEnterBackground` to transmit all data
    /// whenever the user leaves the application.
    @objc public func dispatch() {
        guard !isDispatching else {
            logger.verbose("MatomoTracker is already dispatching.")
            return
        }
        guard queue.eventCount > 0 else {
            logger.info("No need to dispatch. Dispatch queue is empty.")
            startDispatchTimer()
            return
        }
        logger.info("Start dispatching events")
        isDispatching = true
        dispatchBatch()
    }
    
    private func dispatchBatch() {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync {
                self.dispatchBatch()
            }
            return
        }
        queue.first(limit: numberOfEventsDispatchedAtOnce) { [weak self] events in
            guard let self = self else { return }
            guard events.count > 0 else {
                // there are no more events queued, finish dispatching
                self.isDispatching = false
                self.startDispatchTimer()
                self.logger.info("Finished dispatching events")
                return
            }
            self.dispatcher.send(events: events, success: { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.queue.remove(events: events, completion: {
                        self.logger.info("Dispatched batch of \(events.count) events.")
                        DispatchQueue.main.async {
                            self.dispatchBatch()
                        }
                    })
                }
            }, failure: { [weak self] error in
                guard let self = self else { return }
                self.isDispatching = false
                self.startDispatchTimer()
                self.logger.warning("Failed dispatching events with error \(error)")
            })
        }
    }
    
    // MARK: dispatch timer
    
    @objc public var dispatchInterval: TimeInterval = 30.0 {
        didSet {
            startDispatchTimer()
        }
    }
    private var dispatchTimer: Timer?
    
    private func startDispatchTimer() {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync {
                self.startDispatchTimer()
            }
            return
        }
        guard dispatchInterval > 0  else { return } // Discussion: Do we want the possibility to dispatch synchronous? That than would be dispatchInterval = 0
        if let dispatchTimer = dispatchTimer {
            dispatchTimer.invalidate()
            self.dispatchTimer = nil
        }
        // Dispatchin asynchronous here to break the retain cycle
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dispatchTimer = Timer.scheduledTimer(timeInterval: self.dispatchInterval, target: self, selector: #selector(self.dispatch), userInfo: nil, repeats: false)
        }
    }
    
    internal var visitor: Visitor
    internal var session: Session
    internal var nextEventStartsANewSession = true

    internal var campaignName: String? = nil
    internal var campaignKeyword: String? = nil
    
    /// Adds the name and keyword for the current campaign.
    /// This is usually very helpfull if you use deeplinks into your app.
    ///
    /// More information on campaigns: [https://matomo.org/docs/tracking-campaigns/](https://matomo.org/docs/tracking-campaigns/)
    ///
    /// - Parameters:
    ///   - name: The name of the campaign.
    ///   - keyword: The keyword of the campaign.
    @objc public func trackCampaign(name: String?, keyword: String?) {
        campaignName = name
        campaignKeyword = keyword
    }
    
    /// There are several ways to track content impressions and interactions manually, semi-automatically and automatically. Please be aware that content impressions will be tracked using bulk tracking which will always send a POST request, even if  GET is configured which is the default. For more details have a look at the in-depth guide to Content Tracking.
    /// More information on content: [https://matomo.org/docs/content-tracking/](https://matomo.org/docs/content-tracking/)
    ///
    /// - Parameters:
    ///   - name: The name of the content. For instance 'Ad Foo Bar'
    ///   - piece: The actual content piece. For instance the path to an image, video, audio, any text
    ///   - target: The target of the content. For instance the URL of a landing page
    ///   - interaction: The name of the interaction with the content. For instance a 'click'
    @objc public func trackContentImpression(name: String, piece: String?, target: String?) {
        track(Event(tracker: self, action: [], contentName: name, contentPiece: piece, contentTarget: target, isCustomAction: false))
    }
    @objc public func trackContentInteraction(name: String, interaction: String, piece: String?, target: String?) {
        track(Event(tracker: self, action: [], contentName: name, contentInteraction: interaction, contentPiece: piece, contentTarget: target, isCustomAction: false))
    }
}

extension MatomoTracker {
    /// Starts a new Session
    ///
    /// Use this function to manually start a new Session. A new Session will be automatically created only on app start.
    /// You can use the AppDelegates `applicationWillEnterForeground` to start a new visit whenever the app enters foreground.
    @objc public func startNewSession() {
        matomoUserDefaults.previousVisit = matomoUserDefaults.currentVisit
        matomoUserDefaults.currentVisit = Date()
        matomoUserDefaults.totalNumberOfVisits += 1
        nextEventStartsANewSession = true
        self.session = Session.current(in: matomoUserDefaults)
    }
}

extension MatomoTracker {
    
    /// Tracks a custom Event
    ///
    /// - Parameter event: The event that should be tracked.
    public func track(_ event: Event) {
        queue(event: event)
        
        if (event.campaignName == campaignName && event.campaignKeyword == campaignKeyword) {
            campaignName = nil
            campaignKeyword = nil
        }
    }
    
    /// Tracks a screenview.
    ///
    /// This method can be used to track hierarchical screen names, e.g. screen/settings/register. Use this to create a hierarchical and logical grouping of screen views in the Matomo web interface.
    ///
    /// - Parameter view: An array of hierarchical screen names.
    /// - Parameter url: The optional url of the page that was viewed.
    /// - Parameter dimensions: An optional array of dimensions, that will be set only in the scope of this view.
    public func track(view: [String], url: URL? = nil, dimensions: [CustomDimension] = []) {
        let event = Event(tracker: self, action: view, url: url, dimensions: dimensions, isCustomAction: false)
        queue(event: event)
    }
    
    /// Tracks an event as described here: https://matomo.org/docs/event-tracking/
    ///
    /// - Parameters:
    ///   - category: The Category of the Event
    ///   - action: The Action of the Event
    ///   - name: The optional name of the Event
    ///   - value: The optional value of the Event
    ///   - dimensions: An optional array of dimensions, that will be set only in the scope of this event.
    ///   - url: The optional url of the page that was viewed.
    public func track(eventWithCategory category: String, action: String, name: String? = nil, value: Float? = nil, dimensions: [CustomDimension] = [], url: URL? = nil, pc: String = "", module:String = "", component: String = "",ul: String = "",um: String = "",ua: String = "",jjbid: String = "") {
        let event = Event(tracker: self, action: [], url: url, eventCategory: category, eventAction: action, eventName: name, eventValue: value, dimensions: dimensions, isCustomAction: true, pc: pc, module: module,component: component, ul: ul, um:um, ua: ua, jjbid: jjbid)
        queue(event: event)
    }
    
    /// Tracks a goal as described here: https://matomo.org/docs/tracking-goals-web-analytics/
    ///
    /// - Parameters:
    ///   - goalId: The defined ID of the Goal
    ///   - revenue: The monetary value that was generated by the Goal
    public func trackGoal(id goalId: Int?, revenue: Float?) {
        let event = Event(tracker: self, action: [], goalId: goalId, revenue: revenue, isCustomAction: false)
        queue(event: event)
    }

    /// Tracks an order as described here: https://matomo.org/docs/ecommerce-analytics/#tracking-ecommerce-orders-items-purchased-required
    ///
    /// - Parameters:
    ///   - id: The unique ID of the order
    ///   - items: The array of items to be ordered
    ///   - revenue: The grand total for the order (includes tax, shipping and subtracted discount)
    ///   - subTotal: The sub total of the order (excludes shipping)
    ///   - tax: The tax amount of the order
    ///   - shippingCost: The shipping cost of the order
    ///   - discount: The discount offered
    public func trackOrder(id: String, items: [OrderItem], revenue: Float, subTotal: Float? = nil, tax: Float? = nil, shippingCost: Float? = nil, discount: Float? = nil) {
        let lastOrderDate = matomoUserDefaults.lastOrder

        let event = Event(tracker: self, action: [], orderId: id, orderItems: items, orderRevenue: revenue, orderSubTotal: subTotal, orderTax: tax, orderShippingCost: shippingCost, orderDiscount: discount, orderLastDate: lastOrderDate, isCustomAction: false)
        queue(event: event)
        
        matomoUserDefaults.lastOrder = Date()
    }
}

extension MatomoTracker {
    
    /// Tracks a search result page as described here: https://matomo.org/docs/site-search/
    ///
    /// - Parameters:
    ///   - query: The string the user was searching for
    ///   - category: An optional category which the user was searching in
    ///   - resultCount: The number of results that were displayed for that search
    ///   - dimensions: An optional array of dimensions, that will be set only in the scope of this event.
    ///   - url: The optional url of the page that was viewed.
    public func trackSearch(query: String, category: String?, resultCount: Int?, dimensions: [CustomDimension] = [], url: URL? = nil) {
        let event = Event(tracker: self, action: [], url: url, searchQuery: query, searchCategory: category, searchResultsCount: resultCount, dimensions: dimensions, isCustomAction: false)
        queue(event: event)
    }
}

extension MatomoTracker {
    /// Set a permanent custom dimension.
    ///
    /// Use this method to set a dimension that will be send with every event. This is best for Custom Dimensions in scope "Visit". A typical example could be any device information or the version of the app the visitor is using.
    ///
    /// For more information on custom dimensions visit https://matomo.org/docs/custom-dimensions/
    ///
    /// - Parameter value: The value you want to set for this dimension.
    /// - Parameter index: The index of the dimension. A dimension with this index must be setup in the Matomo backend.
    @available(*, deprecated, message: "use setDimension: instead")
    public func set(value: String, forIndex index: Int) {
        let dimension = CustomDimension(index: index, value: value)
        remove(dimensionAtIndex: dimension.index)
        dimensions.append(dimension)
    }
    
    /// Set a permanent custom dimension.
    ///
    /// Use this method to set a dimension that will be send with every event. This is best for Custom Dimensions in scope "Visit". A typical example could be any device information or the version of the app the visitor is using.
    ///
    /// For more information on custom dimensions visit https://matomo.org/docs/custom-dimensions/
    ///
    /// - Parameter dimension: The Dimension to set
    public func set(dimension: CustomDimension) {
        remove(dimensionAtIndex: dimension.index)
        dimensions.append(dimension)
    }
    
    /// Set a permanent custom dimension by value and index.
    ///
    /// This is a convenience alternative to set(dimension:) and calls the exact same functionality. Also, it is accessible from Objective-C.
    ///
    /// - Parameter value: The value for the new Custom Dimension
    /// - Parameter forIndex: The index of the new Custom Dimension
    @objc public func setDimension(_ value: String, forIndex index: Int) {
        set(dimension: CustomDimension( index: index, value: value ));
    }
    
    /// Removes a previously set custom dimension.
    ///
    /// Use this method to remove a dimension that was set using the `set(value: String, forDimension index: Int)` method.
    ///
    /// - Parameter index: The index of the dimension.
    @objc public func remove(dimensionAtIndex index: Int) {
        dimensions = dimensions.filter({ dimension in
            dimension.index != index
        })
    }
}


extension MatomoTracker {

    /// Set a permanent new Custom Variable.
    ///
    /// - Parameter dimension: The Custom Variable to set
    public func set(customVariable: CustomVariable) {
        removeCustomVariable(withIndex: customVariable.index)
        customVariables.append(customVariable)
    }

    /// Set a permanent new Custom Variable.
    ///
    /// - Parameter name: The index of the new Custom Variable
    /// - Parameter name: The name of the new Custom Variable
    /// - Parameter value: The value of the new Custom Variable
    @objc public func setCustomVariable(withIndex index: UInt, name: String, value: String) {
        set(customVariable: CustomVariable(index: index, name: name, value: value))
    }
    
    /// Remove a previously set Custom Variable.
    ///
    /// - Parameter index: The index of the Custom Variable.
    @objc public func removeCustomVariable(withIndex index: UInt) {
        customVariables = customVariables.filter { $0.index != index }
    }
}

// Objective-c compatibility extension
extension MatomoTracker {
    @objc public func track(view: [String], url: URL? = nil) {
        track(view: view, url: url, dimensions: [])
    }
    
    @objc public func track(eventWithCategory category: String, action: String, name: String? = nil, number: NSNumber? = nil, url: URL? = nil, pc: String = "", module:String = "", component: String = "", ul: String = "",um: String = "",ua: String = "",jjbid: String = "") {
        let value = number == nil ? nil : number!.floatValue
        track(eventWithCategory: category, action: action, name: name, value: value, url: url, pc: pc, module: module, component: component, ul: ul, um:um, ua: ua, jjbid: jjbid)
    }
    
    @available(*, deprecated, message: "use track(eventWithCategory:action:name:number:url instead")
    @objc public func track(eventWithCategory category: String, action: String, name: String? = nil, number: NSNumber? = nil, pc: String = "", module:String = "", component: String = "", ul: String = "",um: String = "",ua: String = "",jjbid: String = "") {
        track(eventWithCategory: category, action: action, name: name, number: number, url: nil, pc: pc, module: module, component: component, ul: ul, um:um, ua: ua, jjbid: jjbid)
    }
    
    @objc public func trackSearch(query: String, category: String?, resultCount: Int, url: URL? = nil) {
        trackSearch(query: query, category: category, resultCount: resultCount, dimensions: [], url: url)
    }
}

extension MatomoTracker {
    @objc public func copyFromOldSharedInstance() {
        matomoUserDefaults.copy(from: UserDefaults.standard)
    }
}

extension MatomoTracker {
    /// The version of the Matomo SDKs
    @objc public static let sdkVersion = "7.3"
}
