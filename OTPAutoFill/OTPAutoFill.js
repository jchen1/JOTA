var OTPAutoFill = function() {};

OTPAutoFill.prototype = {
    run: function(arguments) {
        arguments.completionFunction({"url": document.URL,
                                     "host": window.location.host
                                    });
    },
    
    findElement: function(id) {
        var elementById = document.getElementById(elementById);
        if (elementById) return elementById;
        
        var elementByOTP = document.querySelector("input[autocomplete=\"one-time-code\"]");
        if (elementByOTP) return elementByOTP;
        
        var elementsByInput = document.querySelectorAll("input");
        if (elementsByInput.length === 1) return elementsByInput[0];
        
        return null;
    },
    
    finalize: function(arguments) {
        var code = arguments["code"];
        var element = findElement(arguments["id"]);
        
        if (element) {
            element.value = code;
        } else {
            alert("Couldn't find a valid input element!");
        }
    }
};

var ExtensionPreprocessingJS = new OTPAutoFill;
