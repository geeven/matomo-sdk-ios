import Foundation
import CoreGraphics

/// Represents an event of any kind.
///
/// - Todo:
///     - Add Action info
///     - Add Content Tracking info
///
/// # Key Mapping:
/// Most properties represent a key defined at: [Tracking HTTP API](https://developer.piwik.org/api-reference/tracking-api). Keys that are not supported for now are:
///
/// - idsite, rec, rand, apiv, res, cookie,
/// - All Plugins: fla, java, dir, qt, realp, pdf, wma, gears, ag
public struct Event: Codable {
    public let uuid: UUID
    let siteId: String
    let visitor: Visitor
    let session: Session
    
    /// This flag defines if this event is a so called cutom action.
    /// api-key: ca
    /// More info: https://github.com/matomo-org/matomo-sdk-ios/issues/354
    /// and https://github.com/matomo-org/matomo-sdk-ios/issues/363
    let isCustomAction: Bool
    
    /// The Date and Time the event occurred.
    /// api-key: h, m, s
    let date: Date
    
    /// The full URL for the current action.
    /// api-key: url
    let url: URL?
    
    /// api-key: action_name
    let actionName: [String]
    
    /// The language of the device.
    /// Should be in the format of the Accept-Language HTTP header field.
    /// api-key: lang
    let language: String
    
    /// Should be set to true for the first event of a session.
    /// api-key: new_visit
    let isNewSession: Bool
    
    /// Currently only used for Campaigns
    /// api-key: urlref
    let referer: URL?
    var screenResolution: CGSize = Device.makeCurrentDevice().screenSize
    
    /// api-key: _cvar
    let customVariables: [CustomVariable]
    
    /// Event tracking
    /// https://piwik.org/docs/event-tracking/
    let eventCategory: String?
    let eventAction: String?
    let eventName: String?
    let eventValue: Float?
    
    /// Campaign tracking
    /// https://matomo.org/docs/tracking-campaigns/
    let campaignName: String?
    let campaignKeyword: String?

    /// Search tracking
    /// api-keys: search, search_cat, search_count
    let searchQuery: String?
    let searchCategory: String?
    let searchResultsCount: Int?
    
    let dimensions: [CustomDimension]
    
    let customTrackingParameters: [String:String]
    
    /// Content tracking
    /// https://matomo.org/docs/content-tracking/
    let contentName: String?
    let contentPiece: String?
    let contentTarget: String?
    let contentInteraction: String?
    
    /// Goal tracking
    /// https://matomo.org/docs/tracking-goals-web-analytics/
    let goalId: Int?
    let revenue: Float?

    /// Ecommerce Order tracking
    /// https://matomo.org/docs/ecommerce-analytics/#tracking-ecommerce-orders-items-purchased-required
    let orderId: String?
    let orderItems: [OrderItem]
    let orderRevenue: Float?
    let orderSubTotal: Float?
    let orderTax: Float?
    let orderShippingCost: Float?
    let orderDiscount: Float?
    let orderLastDate: Date?
    
    
    // 以下新增jjs
    /// cookie中的JJABID
    var jjbid:String = ""
    /// 页面code
    var pc: String = ""
    /// 国家语言
    var ul: String = ""
    /// 货币符号
    var um: String = ""
    var module: String = ""
    var component: String = ""
    var ua: String = ""
    var gd: String = ""
    
    var jjs_s: Int = 0
    var jjs_l: String = ""
    var jjs_r: String = ""
    var jjs_dp: Float = 0
    var jjs_ctOne: Int = 0
    var jjs_ctTwo: String = ""
    
    var jjs_cn: String = ""
    var jjs_cs: String = ""
    var jjs_cm: String = ""
    var jjs_ck: String = ""
    var jjs_cc: String = ""
    var jjs_sc: Int = 0
    
    
}

extension Event {
    public init(tracker: MatomoTracker, action: [String], url: URL? = nil, referer: URL? = nil, eventCategory: String = "",
                eventAction: String = "", eventName: String = "", eventValue: Float? = nil, customTrackingParameters: [String:String] = [:],
                searchQuery: String? = nil, searchCategory: String? = nil, searchResultsCount: Int? = nil,dimensions: [CustomDimension] = [],
                variables: [CustomVariable] = [], contentName: String? = nil, contentInteraction: String? = nil, contentPiece: String? = nil,
                contentTarget: String? = nil, goalId: Int? = nil, revenue: Float? = nil, orderId: String? = nil, orderItems: [OrderItem] = [],
                orderRevenue: Float? = nil, orderSubTotal: Float? = nil, orderTax: Float? = nil, orderShippingCost: Float? = nil,
                orderDiscount: Float? = nil, orderLastDate: Date? = nil, isCustomAction: Bool,
                pc: String = "", module:String = "", component: String = "",ul: String = "",um: String = "",
                ua: String = "", jjbid: String = "", gd: String = "", jjs_s: Int = 0, jjs_l: String = "", jjs_r: String = "",
                jjs_dp: Float = 0, jjs_ctTwo: String = "", jjs_ctOne: Int = 0,
                jjs_cn: String = "", jjs_cs: String = "", jjs_cm: String = "", jjs_ck: String = "", jjs_cc: String = "", jjs_sc: Int = 0)

    {
        self.siteId = tracker.siteId
        self.uuid = UUID()
        self.visitor = tracker.visitor
        self.session = tracker.session
        self.date = Date()
        self.url = url ?? tracker.contentBase?.appendingPathComponent(action.joined(separator: "/"))
        self.actionName = action
        self.language = Locale.httpAcceptLanguage
        self.isNewSession = tracker.nextEventStartsANewSession
        self.referer = referer
        self.eventCategory = eventCategory
        self.eventAction = eventAction
        self.eventName = eventName
        self.eventValue = eventValue
        self.searchQuery = searchQuery
        self.searchCategory = searchCategory
        self.searchResultsCount = searchResultsCount
        self.dimensions = tracker.dimensions + dimensions
        self.campaignName = tracker.campaignName
        self.campaignKeyword = tracker.campaignKeyword
        self.customTrackingParameters = customTrackingParameters
        self.customVariables = tracker.customVariables + variables
        self.contentName = contentName
        self.contentPiece = contentPiece
        self.contentTarget = contentTarget
        self.contentInteraction = contentInteraction
        self.goalId = goalId
        self.revenue = revenue
        self.orderId = orderId
        self.orderItems = orderItems
        self.orderRevenue = orderRevenue
        self.orderSubTotal = orderSubTotal
        self.orderTax = orderTax
        self.orderShippingCost = orderShippingCost
        self.orderDiscount = orderDiscount
        self.orderLastDate = orderLastDate
        self.isCustomAction = isCustomAction
        
        // 以下新增jjs
        self.jjbid = jjbid
        self.ul = ul
        self.um = um
        self.ua = ua
        self.gd = gd
        
        self.pc = pc
        self.module = module
        self.component = component
        
        self.jjs_s = jjs_s
        self.jjs_l = jjs_l
        self.jjs_r = jjs_r
        self.jjs_dp = jjs_dp
        self.jjs_ctOne = jjs_ctOne
        self.jjs_ctTwo = jjs_ctTwo
        
        
        self.jjs_cn = jjs_cn
        self.jjs_cs = jjs_cs
        self.jjs_cm = jjs_cm
        self.jjs_ck = jjs_ck
        self.jjs_cc = jjs_cc
        self.jjs_sc = jjs_sc
    }
}
