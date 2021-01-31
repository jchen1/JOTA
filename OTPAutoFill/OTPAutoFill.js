var OTPAutoFill = function() {};

// In priority order
var elementSelectors = [
    // Specific sites
    "#challenge_response",                                          // Twitter
    "input[name=\"otp\"]:not([type=\"hidden\"])",                   // Github
    "input[name=\"verificationCode\"]",                             // LastPass
    "input[name=\"yubikeyotp\"]",                                   // LastPass alt
    // Generic inputs
    "input[autocomplete=\"one-time-code\"]",                        // ...
    "input[data-input=\"token\"]",                                  // Rippling
    "input[type]:not([type=\"hidden\"]):not([type=\"submit\"])"     // Any non-hidden text input
];

OTPAutoFill.prototype = {
    run: function(arguments) {
        arguments.completionFunction({"host": window.location.host});
    },
    
    finalize: function(arguments) {
        try {
            var code = arguments.code;
            if (code && code.length) {
                var element = this.findElement(arguments["id"]);
                if (element) {
                    this.setNativeValue(element, code);
                    element.dispatchEvent(new Event('input', { bubbles: true }));
                } else {
                    throw new Error("Couldn't find a valid input element!");
                }
            }
        } catch(error) {
            console.error(error);
        }
    },
    findElement: function(id) {
        if (id) {
            var elementById = document.getElementById(id);
            if (elementById) return elementById;
        }

        for (var i = 0; i < elementSelectors.length; i++) {
            var selector = elementSelectors[i];
            var elements = document.querySelectorAll(selector);
            if (elements.length === 1) {
                return elements[0];
            }
        }

        return null;
    },
    setNativeValue: function(input, value) {
        var previousValue = input.value;
        input.value = value;
        
        var tracker = input._valueTracker;
        if (tracker) {
            tracker.setValue(previousValue);
        }
        var event = new Event("input", { bubbles: true });
        event.simulated = true;
        
        // 'change' instead of 'input', see https://github.com/facebook/react/issues/11488#issuecomment-381590324
        input.dispatchEvent(event);
    }
};

var ExtensionPreprocessingJS = new OTPAutoFill;
