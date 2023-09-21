exports.config = {
    twilioAccountSid: "{{key "twilio/account_sid"}}",
    twilioAuthToken: "{{key "twilio/auth_token"}}",
    twilioPhoneNumber: "{{key "twilio/default/phone"}}",

    urls: [
        "https://www.purpleair.com/json?show=37715", //Pine
        "https://www.purpleair.com/json?show=74241" //Levy
    ],
    phoneNumbers: [
        "{{key "personal/nd/phone"}}",
    ],

    lowAQI: 25,
    highAQI: 35,

    schedule: "*/2 * * * *"
};
