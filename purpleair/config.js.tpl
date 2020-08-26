exports.config = {
    twilioAccountSid: "{{key "twilio/account_sid"}}",
    twilioAuthToken: "{{key "twilio/auth_token"}}",
    twilioPhoneNumber: "{{key "twilio/default/phone"}}",

    urls: [
        "https://www.purpleair.com/json?show=2910", //tactrix rooftop
        "https://www.purpleair.com/json?show=19657" //Western SoMa (Outside)
    ],
    phoneNumbers: [
        "{{key "personal/nd/phone"}}",
        "{{key "personal/rb/phone"}}"
    ],

    lowAQI: 25,
    highAQI: 35,

    schedule: "*/2 * * * *"
};
