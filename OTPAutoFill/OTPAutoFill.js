var OTPAutoFill = function() {};

OTPAutoFill.prototype = {
    run: function(arguments) {
        arguments.completionFunction({"url": document.URL,
                                     "host": window.location.host
                                     });
    }
};

var ExtensionPreprocessingJS = new OTPAutoFill;
