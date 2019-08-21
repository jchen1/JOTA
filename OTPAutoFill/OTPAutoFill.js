var OTPAutoFill = function() {};

OTPAutoFill.prototype = {
    run: function(arguments) {
        arguments.completionFunction({"test": "value"});
    }
};

var ExtensionPreprocessingJS = new OTPAutoFill;
