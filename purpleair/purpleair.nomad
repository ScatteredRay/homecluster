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
        "https://www.purpleair.com/json?show=2910", //tactrix rooftop
        "https://www.purpleair.com/json?show=19657" //Western SoMa (Outside)
    ],
    phoneNumbers: [
        "{{key "personal/nd/phone"}}",
        "{{key "personal/rb/phone"}}"
    ],

    lowAQI: {{key "purpleair/aqi/low"}},
    highAQI: {{key "purpleair/aqi/high"}},
    schedule: "*/2 * * * *"
};
EOH
                      destination = "app/config.js"
               }
          }
    }
}