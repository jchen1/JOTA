var OTPAutoFill = function() {};

OTPAutoFill.prototype = {
    run: function(arguments) {
        arguments.completionFunction({"url": document.URL,
                                     "host": window.location.host
                                    });
    },
    
    finalize: function(arguments) {
        var code = arguments.code;
        console.log(arguments, code, code.length);
        if (code && code.length) {
            var element = this.findElement(arguments["id"]);
            if (element) {
                this.setNativeValue(element, code);
                element.dispatchEvent(new Event('input', { bubbles: true }));
            } else {
                console.log(":(");
                throw new Exception("Couldn't find a valid input element!");
            }
        }
    },
    findElement: function(id) {
        if (id) {
            var elementById = document.getElementById(id);
            if (elementById) return elementById;
        }
        
        var elementByOTP = document.querySelector("input[autocomplete=\"one-time-code\"]");
        if (elementByOTP) return elementByOTP;
        
        // special case Twitter
        var elementById = document.getElementById("challenge_response");
        if (elementById) return elementById;
        
        var elementsByInput = document.querySelectorAll("input[type!=\"hidden\"][type!=\"submit\"]");
        if (elementsByInput.length === 1) return elementsByInput[0];
        
        return null;
    },
    
    setNativeValue: function(input, value) {
        try {
            const previousValue = input.value;
            input.value = value;
            
            const tracker = input._valueTracker;
            if (tracker) {
                tracker.setValue(previousValue);
            }
            
            // 'change' instead of 'input', see https://github.com/facebook/react/issues/11488#issuecomment-381590324
            input.dispatchEvent(new Event('change', { bubbles: true }));
        } catch(error) {
            console.error(error);
        }
    }
};

var ExtensionPreprocessingJS = new OTPAutoFill;
