browser.runtime.sendMessage({ greeting: "hello" }).then((response) => {
    console.log("Received response: ", response);
});

browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    console.log("Received request: ", request);
});

const elementSelectors = [
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

//function run(arguments) {
//    arguments.completionFunction({"host": window.location.host});
//}
//
//function finalize(arguments) {
//    try {
//        var code = arguments.code;
//        if (code && code.length) {
//            var element = this.findElement(arguments["id"]);
//            if (element) {
//                setNativeValue(element, code);
//                element.dispatchEvent(new Event('input', { bubbles: true }));
//            } else {
//                throw new Error("Couldn't find a valid input element!");
//            }
//        }
//    } catch(error) {
//        console.error(error);
//    }
//}


function findElement(id) {
    if (id) {
        const elementById = document.getElementById(id);
        if (elementById) return elementById;
    }

    for (let i = 0; i < elementSelectors.length; i++) {
        const selector = elementSelectors[i];
        const elements = document.querySelectorAll(selector);
        if (elements.length === 1) {
            return elements[0];
        }
    }

    return null;
}

function setNativeValue(input, value) {
    const previousValue = input.value;
    input.value = value;
    
    const tracker = input._valueTracker;
    if (tracker) {
        tracker.setValue(previousValue);
    }
    const event = new Event("input", { bubbles: true });
    event.simulated = true;
    
    // 'change' instead of 'input', see https://github.com/facebook/react/issues/11488#issuecomment-381590324
    input.dispatchEvent(event);
}

