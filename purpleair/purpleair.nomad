job "purpleair" {
    datacenters = ["dc1"]
    type = "service"

    group "notifier" {
          count = 1

          task "notifier" {
               driver = "docker"

               config {
                      image = "scatteredray/purpleair:latest"

                      volumes = [
                          "app/config.js:/app/config.js"
                      ]
               }

               template {
                 data = <<EOH
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
EOH
                      destination = "app/config.js"
               }
          }
    }
}