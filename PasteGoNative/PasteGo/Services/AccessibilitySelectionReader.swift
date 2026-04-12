import AppKit
import ApplicationServices

struct AccessibilitySelectionReader {
    struct Result {
        let text: String?
        let diagnostics: [String]
    }

    private let maxCandidateCount = 12
    private let maxSubtreeDepth = 5

    func readSelectedText(from application: NSRunningApplication?) -> Result {
        guard AXIsProcessTrusted() else {
            return Result(text: nil, diagnostics: ["AX permission unavailable"])
        }
        guard let application else {
            return Result(text: nil, diagnostics: ["No source application"])
        }

        let axApp = AXUIElementCreateApplication(application.processIdentifier)
        var diagnostics = ["App=\(application.localizedName ?? "<unknown>")"]
        let text = readSelectedText(from: axApp, diagnostics: &diagnostics)
        return Result(text: text, diagnostics: diagnostics)
    }

    private func readSelectedText(from application: AXUIElement, diagnostics: inout [String]) -> String? {
        if let focusedElement = copyElementAttribute(application, kAXFocusedUIElementAttribute as CFString),
           let text = selectedText(from: focusedElement) {
            diagnostics.append("FocusedUIElement hit")
            return text
        } else {
            diagnostics.append("FocusedUIElement miss")
        }

        guard let focusedWindow = copyElementAttribute(application, kAXFocusedWindowAttribute as CFString) else {
            diagnostics.append("FocusedWindow missing")
            return nil
        }
        diagnostics.append("FocusedWindow found")

        if let hitTestElement = hitTestElementInFocusedWindow(focusedWindow),
           let text = selectedTextByScanningSubtree(from: hitTestElement, depthRemaining: 3) {
            diagnostics.append("Hit-test scan hit")
            return text
        } else {
            diagnostics.append("Hit-test scan miss")
        }

        if let text = selectedTextFromWindowCandidates(focusedWindow) {
            diagnostics.append("Window candidates hit")
            return text
        }
        diagnostics.append("Window candidates miss")

        let scanned = selectedTextByScanningSubtree(from: focusedWindow, depthRemaining: maxSubtreeDepth)
        diagnostics.append(scanned == nil ? "Subtree scan miss" : "Subtree scan hit")
        return scanned
    }

    private func selectedTextFromWindowCandidates(_ window: AXUIElement) -> String? {
        if let text = selectedText(from: window) {
            return text
        }

        for attribute in candidateAttributes {
            guard let elements = copyChildrenAttribute(window, attribute: attribute) else { continue }
            for element in elements.prefix(6) {
                if let text = selectedText(from: element) {
                    return text
                }

                guard let children = copyChildrenAttribute(element, attribute: kAXChildrenAttribute as CFString) else {
                    continue
                }

                for child in children.prefix(3) {
                    if let text = selectedText(from: child) {
                        return text
                    }
                }
            }
        }

        return nil
    }

    private func selectedTextByScanningSubtree(from root: AXUIElement, depthRemaining: Int) -> String? {
        if let text = selectedText(from: root) {
            return text
        }

        guard depthRemaining > 0 else { return nil }

        for attribute in candidateAttributes {
            guard let children = copyChildrenAttribute(root, attribute: attribute) else { continue }
            for child in children.prefix(8) {
                if let text = selectedTextByScanningSubtree(from: child, depthRemaining: depthRemaining - 1) {
                    return text
                }
            }
        }

        return nil
    }

    private func hitTestElementInFocusedWindow(_ window: AXUIElement) -> AXUIElement? {
        let mouseLocation = NSEvent.mouseLocation
        let point = NSPoint(x: mouseLocation.x, y: mouseLocation.y)

        var hit: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(window, Float(point.x), Float(point.y), &hit)
        guard result == .success else { return nil }
        return hit
    }

    private func selectedText(from element: AXUIElement) -> String? {
        if let directText = copyStringAttribute(element, attribute: kAXSelectedTextAttribute as CFString),
           let trimmed = sanitize(directText) {
            return trimmed
        }

        if let multiRangeText = selectedTextFromRangesArray(on: element),
           let trimmed = sanitize(multiRangeText) {
            return trimmed
        }

        if let rangedText = selectedTextFromRange(on: element),
           let trimmed = sanitize(rangedText) {
            return trimmed
        }

        if let markerText = selectedTextFromMarkerRange(on: element),
           let trimmed = sanitize(markerText) {
            return trimmed
        }

        return nil
    }

    private func selectedTextFromMarkerRange(on element: AXUIElement) -> String? {
        guard let markerRange = copyAttributeValue(element, attribute: kAXSelectedTextMarkerRangeAttribute as CFString),
              let value = copyParameterizedAttributeValue(
                element,
                attribute: kAXStringForTextMarkerRangeParameterizedAttribute as CFString,
                parameter: markerRange
              ) as? String
        else {
            return nil
        }

        return value
    }

    private func selectedTextFromRangesArray(on element: AXUIElement) -> String? {
        guard let rawRanges = copyAttributeValue(element, attribute: "AXSelectedTextRanges" as CFString),
              CFGetTypeID(rawRanges) == CFArrayGetTypeID()
        else {
            return nil
        }

        let ranges = unsafeBitCast(rawRanges, to: CFArray.self)
        let count = min(CFArrayGetCount(ranges), 4)

        guard count > 0 else { return nil }

        for index in 0..<count {
            guard let rawRange = CFArrayGetValueAtIndex(ranges, index) else { continue }

            let rangeObject = unsafeBitCast(rawRange, to: CFTypeRef.self)
            guard CFGetTypeID(rangeObject) == AXValueGetTypeID() else { continue }

            let rangeValue = unsafeBitCast(rangeObject, to: AXValue.self)
            guard AXValueGetType(rangeValue) == .cfRange else { continue }

            var range = CFRange()
            guard AXValueGetValue(rangeValue, .cfRange, &range), range.length > 0 else { continue }

            if let parameterizedText = copyParameterizedStringAttribute(
                element,
                attribute: kAXStringForRangeParameterizedAttribute as CFString,
                parameter: rangeValue
            ) {
                return parameterizedText
            }

            if let value = copyStringAttribute(element, attribute: kAXValueAttribute as CFString),
               !value.isEmpty {
                let nsValue = value as NSString
                let safeLocation = max(0, min(range.location, nsValue.length))
                let safeLength = max(0, min(range.length, nsValue.length - safeLocation))
                if safeLength > 0 {
                    return nsValue.substring(with: NSRange(location: safeLocation, length: safeLength))
                }
            }
        }

        return nil
    }

    private func selectedTextFromRange(on element: AXUIElement) -> String? {
        guard let rangeValue = copyAXValueAttribute(element, attribute: kAXSelectedTextRangeAttribute as CFString),
              AXValueGetType(rangeValue) == .cfRange
        else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &range), range.length > 0 else {
            return nil
        }

        if let parameterizedText = copyParameterizedStringAttribute(
            element,
            attribute: kAXStringForRangeParameterizedAttribute as CFString,
            parameter: rangeValue
        ) {
            return parameterizedText
        }

        guard let value = copyStringAttribute(element, attribute: kAXValueAttribute as CFString),
              !value.isEmpty
        else {
            return nil
        }

        let nsValue = value as NSString
        let safeLocation = max(0, min(range.location, nsValue.length))
        let safeLength = max(0, min(range.length, nsValue.length - safeLocation))
        guard safeLength > 0 else { return nil }

        return nsValue.substring(with: NSRange(location: safeLocation, length: safeLength))
    }

    private func sanitize(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var candidateAttributes: [CFString] {
        [
            kAXChildrenAttribute as CFString,
            "AXChildrenInNavigationOrder" as CFString,
            "AXSections" as CFString,
            "AXContents" as CFString,
            "AXVisibleChildren" as CFString,
            "AXRows" as CFString,
            "AXSelectedChildren" as CFString,
            "AXSelectedRows" as CFString,
            "AXSharedTextUIElements" as CFString
        ]
    }

    private func copyElementAttribute(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        guard let value = copyAttributeValue(element, attribute: attribute) else { return nil }
        return (value as! AXUIElement)
    }

    private func copyChildrenAttribute(_ element: AXUIElement, attribute: CFString) -> [AXUIElement]? {
        var values: CFArray?
        let result = AXUIElementCopyAttributeValues(element, attribute, 0, maxCandidateCount, &values)
        guard result == .success, let values else { return nil }

        let count = CFArrayGetCount(values)
        guard count > 0 else { return nil }

        return (0..<count).map { index in
            unsafeBitCast(CFArrayGetValueAtIndex(values, index), to: AXUIElement.self)
        }
    }

    private func copyStringAttribute(_ element: AXUIElement, attribute: CFString) -> String? {
        guard let value = copyAttributeValue(element, attribute: attribute) else { return nil }
        return value as? String
    }

    private func copyAXValueAttribute(_ element: AXUIElement, attribute: CFString) -> AXValue? {
        guard let value = copyAttributeValue(element, attribute: attribute) else { return nil }
        return (value as! AXValue)
    }

    private func copyParameterizedStringAttribute(_ element: AXUIElement, attribute: CFString, parameter: AXValue) -> String? {
        guard let value = copyParameterizedAttributeValue(element, attribute: attribute, parameter: parameter) else {
            return nil
        }
        return value as? String
    }

    private func copyAttributeValue(_ element: AXUIElement, attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        return value
    }

    private func copyParameterizedAttributeValue(_ element: AXUIElement, attribute: CFString, parameter: CFTypeRef) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(element, attribute, parameter, &value)
        guard result == .success else { return nil }
        return value
    }
}
