import Foundation

final class EventAPISerializer {
    internal func queryItems(for event: Event) -> [String: String] {
        event.queryItems.reduce(into: [String:String]()) {
            $0[$1.name] = $1.value
        }.compactMapValues {
            $0.addingPercentEncoding(withAllowedCharacters: .urlQueryParameterAllowed)
        }
    }
    
    internal func jsonData(for events: [Event]) throws -> Data {
        let eventsAsQueryItems: [[String: String]] = events.map { self.queryItems(for: $0) }
        let serializedEvents = eventsAsQueryItems.map { items in
            items.map {
                "\($0.key)=\($0.value)"
            }.joined(separator: "&")
        }
        print("-------track-----start0----------")
        print(serializedEvents.count)
        print(serializedEvents)
        let dataStr = serializedEvents[0]
        print(dataStr)
        print("-------track-----start0----------  end---")
        if let data = dataStr.data(using: .utf8){
            return data
        }
        let body = ["requests": serializedEvents.map({ "?\($0)" })]
        print(body)
        
        
        return try JSONSerialization.data(withJSONObject: body, options: [])
    }
}

fileprivate extension Event {
    
    private func customVariableParameterValue() -> String {
        let customVariableParameterValue: [String] = customVariables.map { "\"\($0.index)\":[\"\($0.name)\",\"\($0.value)\"]" }
        return "{\(customVariableParameterValue.joined(separator: ","))}"
    }
    
    private func orderItemParameterValue() -> String? {
        let serializable: [[Codable?]] = orderItems.map {
            let parameters: [Codable?] = [$0.sku, $0.name, $0.category, $0.price, $0.quantity]
            return parameters
        }
        if let data = try? JSONSerialization.data(withJSONObject: serializable, options: []) {
            return String(bytes: data, encoding: .utf8)
        } else {
            return nil
        }
    }

    var queryItems: [URLQueryItem] {
        get {
//            let lastOrderTimestamp = orderLastDate != nil ? "\(Int(orderLastDate!.timeIntervalSince1970))" : nil
            
            let items = [
                // 以下新增jjs
                URLQueryItem(name: "_v", value: "3"),
                URLQueryItem(name: "_uuid", value: uuid.uuidString),
                URLQueryItem(name: "uid", value: visitor.userId),
                URLQueryItem(name: "ua", value: ua),
                URLQueryItem(name: "sr", value:String(format: "%1.0fx%1.0f", screenResolution.width, screenResolution.height)),
                URLQueryItem(name: "e", value: eventAction),
                URLQueryItem(name: "e_c", value: eventCategory),
                URLQueryItem(name: "e_n", value: eventName),
                
                URLQueryItem(name: "tv", value: jjbid),
                URLQueryItem(name: "pc", value: pc),
                URLQueryItem(name: "ul", value: ul),
                URLQueryItem(name: "um", value: um),
                URLQueryItem(name: "pl", value: "ios"),
                URLQueryItem(name: "md", value: module),
                URLQueryItem(name: "mdc", value: component),
                URLQueryItem(name: "gd", value: gd),

                URLQueryItem(name: "v", value: "visitor.userId\(date.timeIntervalSince1970)"),
                URLQueryItem(name: "sc", value: uuid.uuidString),
                
                URLQueryItem(name: "l", value: jjs_l),
                URLQueryItem(name: "r", value: jjs_r),
                URLQueryItem(name: "ct2", value: jjs_ctTwo),
                URLQueryItem(name: "ct1", value: "\(jjs_ctOne)"),
                URLQueryItem(name: "s", value: "\(jjs_s)"),
                URLQueryItem(name: "dp", value: "\(jjs_dp)"),
                
                URLQueryItem(name: "cn", value: jjs_cn),
                URLQueryItem(name: "cs", value: jjs_cs),
                URLQueryItem(name: "cm", value: jjs_cm),
                URLQueryItem(name: "ck", value: "\(jjs_ck)"),
                URLQueryItem(name: "cc", value: "\(jjs_cc)"),
                
                
                
               
                // 以上新增jjs
                
                
//                URLQueryItem(name: "idsite", value: siteId),
//                URLQueryItem(name: "rec", value: "1"),
//                URLQueryItem(name: "ca", value: isCustomAction ? "1" : nil),
//                // Visitor
//                URLQueryItem(name: "_id", value: visitor.id),
//                URLQueryItem(name: "cid", value: visitor.forcedId),
//
//
//                // Session
//                URLQueryItem(name: "_idvc", value: "\(session.sessionsCount)"),
//                URLQueryItem(name: "_viewts", value: "\(Int(session.lastVisit.timeIntervalSince1970))"),
//                URLQueryItem(name: "_idts", value: "\(Int(session.firstVisit.timeIntervalSince1970))"),
//
//                URLQueryItem(name: "url", value:url?.absoluteString),
//                URLQueryItem(name: "action_name", value: actionName.joined(separator: "/")),
//                URLQueryItem(name: "lang", value: language),
//                URLQueryItem(name: "urlref", value: referer?.absoluteString),
//                URLQueryItem(name: "new_visit", value: isNewSession ? "1" : nil),
//
//                URLQueryItem(name: "h", value: DateFormatter.hourDateFormatter.string(from: date)),
//                URLQueryItem(name: "m", value: DateFormatter.minuteDateFormatter.string(from: date)),
//                URLQueryItem(name: "s", value: DateFormatter.secondsDateFormatter.string(from: date)),
//
//                URLQueryItem(name: "cdt", value: DateFormatter.iso8601DateFormatter.string(from: date)),
//
//                //screen resolution
//                URLQueryItem(name: "res", value:String(format: "%1.0fx%1.0f", screenResolution.width, screenResolution.height)),
//
//
//                URLQueryItem(name: "e_a", value: eventAction),
//
//                URLQueryItem(name: "e_v", value: eventValue != nil ? "\(eventValue!)" : nil),
//
//                URLQueryItem(name: "_rcn", value: campaignName),
//                URLQueryItem(name: "_rck", value: campaignKeyword),
//
//                URLQueryItem(name: "search", value: searchQuery),
//                URLQueryItem(name: "search_cat", value: searchCategory),
//                URLQueryItem(name: "search_count", value: searchResultsCount != nil ? "\(searchResultsCount!)" : nil),
//
//                URLQueryItem(name: "c_n", value: contentName),
//                URLQueryItem(name: "c_p", value: contentPiece),
//                URLQueryItem(name: "c_t", value: contentTarget),
//                URLQueryItem(name: "c_i", value: contentInteraction),
//
//                URLQueryItem(name: "idgoal", value: goalId != nil ? "\(goalId!)" : nil),
//                URLQueryItem(name: "revenue", value: revenue != nil ? "\(revenue!)" : nil),
//
//                URLQueryItem(name: "ec_id", value: orderId),
//                URLQueryItem(name: "revenue", value: orderRevenue != nil ? "\(orderRevenue!)" : nil),
//                URLQueryItem(name: "ec_st", value: orderSubTotal != nil ? "\(orderSubTotal!)" : nil),
//                URLQueryItem(name: "ec_tx", value: orderTax != nil ? "\(orderTax!)" : nil),
//                URLQueryItem(name: "ec_sh", value: orderShippingCost != nil ? "\(orderShippingCost!)" : nil),
//                URLQueryItem(name: "ec_dt", value: orderDiscount != nil ? "\(orderDiscount!)" : nil),
//                URLQueryItem(name: "_ects", value: lastOrderTimestamp),
            ]

            let dimensionItems = dimensions.map { URLQueryItem(name: "dimension\($0.index)", value: $0.value) }
            let customItems = customTrackingParameters.map { return URLQueryItem(name: $0.key, value: $0.value) }
            let customVariableItems = customVariables.count > 0 ? [URLQueryItem(name: "_cvar", value: customVariableParameterValue())] : []
            let ecommerceOrderItemsAndFlag = orderItems.count > 0 ? [URLQueryItem(name: "ec_items", value: orderItemParameterValue()), URLQueryItem(name: "idgoal", value: "0")] : []
            
            return items + dimensionItems + ecommerceOrderItemsAndFlag + customVariableItems + customItems
        }
    }
}

fileprivate extension DateFormatter {
    static let hourDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH"
        return dateFormatter
    }()
    static let minuteDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "mm"
        return dateFormatter
    }()
    static let secondsDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "ss"
        return dateFormatter
    }()
    static let iso8601DateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()
}

fileprivate extension CharacterSet {
    
    /// Returns the character set for characters allowed in a query parameter URL component.
    static var urlQueryParameterAllowed: CharacterSet {
        return CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: ###"&/?;',+"!^()=@*$"###))
    }
}
