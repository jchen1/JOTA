var OTPAutoFill = function() {};

var TARGET_ATTRIBUTE = "data-jota-target";

// Site-specific selectors, checked before the generic heuristics.
var knownSelectors = [
    "#challenge_response",                  // Twitter
    "input[name=\"otp\"]",                  // GitHub
    "input[name=\"verificationCode\"]",     // LastPass
    "input[name=\"yubikeyotp\"]",           // LastPass alt
    "input[data-input=\"token\"]",          // Rippling
    "input[name=\"pin\"]"                   // LinkedIn
];

var TEXT_TYPES = ["", "text", "tel", "number", "password", "search"];
var CODE_HINT = /(one.?time|otp|totp|2fa|mfa|two.?factor|verif|token|passcode|security.?code|auth.*code|approvals?_code|\bpin\b|\bcode\b)/i;
var NOT_CODE_HINT = /(email|e-mail|user|login|phone|mobile|search|zip|postal|captcha|coupon|promo|gift|card|cvc|cvv)/i;

function describe(element) {
    var parts = [
        element.name, element.id, element.className, element.placeholder,
        element.getAttribute("aria-label"), element.getAttribute("autocomplete"),
        element.getAttribute("data-testid")
    ];
    if (element.labels) {
        for (var i = 0; i < element.labels.length; i++) {
            parts.push(element.labels[i].textContent);
        }
    }
    return parts.filter(Boolean).join(" ");
}

function isFillable(element) {
    if (!element || element.tagName !== "INPUT") return false;
    var type = (element.getAttribute("type") || "").toLowerCase();
    if (TEXT_TYPES.indexOf(type) < 0) return false;
    if (element.disabled || element.readOnly) return false;

    // Transparent inputs are allowed: some OTP widgets draw their own boxes over a
    // single invisible input. Zero-size or display:none inputs are never the target.
    var rect = element.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) return false;
    var style = window.getComputedStyle(element);
    return style.display !== "none" && style.visibility !== "hidden";
}

// All inputs, including inside open shadow roots and same-origin iframes.
function collectInputs(root, out) {
    var elements = root.querySelectorAll("*");
    for (var i = 0; i < elements.length; i++) {
        var element = elements[i];
        if (element.tagName === "INPUT") {
            out.push(element);
        }
        if (element.shadowRoot) {
            collectInputs(element.shadowRoot, out);
        }
        if (element.tagName === "IFRAME") {
            try {
                if (element.contentDocument) collectInputs(element.contentDocument, out);
            } catch (e) {
                // Cross-origin frame.
            }
        }
    }
    return out;
}

function score(element) {
    var description = describe(element);
    var autocomplete = (element.getAttribute("autocomplete") || "").toLowerCase();
    var type = (element.getAttribute("type") || "").toLowerCase();
    var maxLength = element.maxLength;
    var points = 0;

    if (autocomplete.indexOf("one-time-code") >= 0) points += 100;
    for (var i = 0; i < knownSelectors.length; i++) {
        if (element.matches(knownSelectors[i])) {
            points += 80;
            break;
        }
    }
    var looksLikeCode = CODE_HINT.test(description);
    if (looksLikeCode) points += 40;
    // "login-verification-code" is a code field; only penalize words like "login" alone.
    if (NOT_CODE_HINT.test(description) && !looksLikeCode) points -= 60;
    if ((element.getAttribute("inputmode") || "").toLowerCase() === "numeric") points += 20;
    if (maxLength >= 4 && maxLength <= 10) points += 20;
    if (maxLength === 1) points += 10;
    if (type === "password" || /pass(word)?/i.test(description)) points -= 50;
    if (autocomplete === "username" || autocomplete === "email" || type === "email") points -= 100;
    return points;
}

function findTarget() {
    var inputs = collectInputs(document, []).filter(isFillable);
    if (inputs.length === 0) return null;

    var marked = inputs.filter(function(element) { return element.hasAttribute(TARGET_ATTRIBUTE); });
    if (marked.length > 0 && (score(marked[0]) >= 0 || CODE_HINT.test(describe(marked[0])))) return marked[0];

    var best = null;
    var bestScore = 0;
    for (var i = 0; i < inputs.length; i++) {
        var points = score(inputs[i]);
        if (points > bestScore) {
            best = inputs[i];
            bestScore = points;
        }
    }
    if (best) return best;

    // A page with a single plain text field is almost certainly asking for the code.
    return inputs.length === 1 && score(inputs[0]) === 0 ? inputs[0] : null;
}

// One-character boxes that together hold the code, in document order.
function splitGroup(element, codeLength) {
    if (element.maxLength !== 1) return null;
    var container = element.parentElement;
    while (container) {
        var boxes = collectInputs(container, []).filter(function(input) {
            return input.maxLength === 1 && isFillable(input);
        });
        if (boxes.length >= codeLength) {
            return boxes.slice(0, codeLength);
        }
        container = container.parentElement;
    }
    return null;
}

// Uses the prototype's setter so frameworks that wrap `value` (React, Vue) see the change.
function setNativeValue(input, value) {
    var setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
    input.focus();
    setter.call(input, value);
    input.dispatchEvent(new Event("input", { bubbles: true }));
    input.dispatchEvent(new Event("change", { bubbles: true }));
}

OTPAutoFill.prototype = {
    run: function(args) {
        var previous = document.querySelectorAll("[" + TARGET_ATTRIBUTE + "]");
        for (var i = 0; i < previous.length; i++) {
            previous[i].removeAttribute(TARGET_ATTRIBUTE);
        }
        var active = document.activeElement;
        if (isFillable(active)) {
            active.setAttribute(TARGET_ATTRIBUTE, "");
        }
        args.completionFunction({ "host": window.location.host });
    },

    finalize: function(args) {
        var code = args.code;
        if (!code || !code.length) return;

        var target = findTarget();
        if (!target) {
            console.error("JOTA: couldn't find a verification code field");
            return;
        }

        var boxes = splitGroup(target, code.length);
        if (boxes) {
            for (var i = 0; i < boxes.length; i++) {
                setNativeValue(boxes[i], code.charAt(i));
            }
        } else {
            setNativeValue(target, code);
        }
        target.removeAttribute(TARGET_ATTRIBUTE);
    },

    // Exposed for tests.
    findTarget: findTarget
};

var ExtensionPreprocessingJS = new OTPAutoFill;
