var OTPAutoFill = function() {};

OTPAutoFill.prototype = {
    run: function(arguments) {
        arguments.completionFunction({"url": document.URL,
                                     "host": window.location.host
                                     });
    },
    
    finalize: function(arguments) {
        var elementId = arguments["id"];
        var code = arguments["code"];
        var element = document.getElementById(elementId);
        element.value = code;
    }
};

var ExtensionPreprocessingJS = new OTPAutoFill;
