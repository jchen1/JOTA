var OTPAutoFill = function() {};

// In priority order
var elementSelectors = [
    "input[autocomplete=\"one-time-code\"]",                        // ...
    "#challenge_response",                                          // Twitter
    "input[type]:not([type=\"hidden\"]):not([type=\"submit\"])",    // Any non-hidden text input
    "input[name=\"otp\"]"
];

OTPAutoFill.prototype = {
    run: function(arguments) {
        arguments.completionFunction();
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
        const previousValue = input.value;
        input.value = value;
        
        const tracker = input._valueTracker;
        if (tracker) {
            tracker.setValue(previousValue);
        }
        
        // 'change' instead of 'input', see https://github.com/facebook/react/issues/11488#issuecomment-381590324
        input.dispatchEvent(new Event('change', { bubbles: true }));
    }
};

var ExtensionPreprocessingJS = new OTPAutoFill;
