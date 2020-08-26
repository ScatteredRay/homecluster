const fetch = require('node-fetch');
const twilio = require('twilio');
const {config} = require('./config');

let twilioAccountSid = config.twilioAccountSid;
let twilioAuthToken = config.twilioAuthToken;
let twilioPhoneNumber = config.twilioPhoneNumber;


let urls = config.urls;
let phoneNumbers = config.phoneNumbers;

let lowAQI = config.lowAQI;
let highAQI = config.highAQI;

let schedule = config.schedule;


let tClient = new twilio(twilioAccountSid, twilioAuthToken);

let pm2_5Map = [
    {
        iLow: 0,
        iHigh: 50,
        cLow: 0,
        cHigh: 12.0
    },
    {
        iLow: 51,
        iHigh: 100,
        cLow: 12.1,
        cHigh: 35.4
    },
    {
        iLow: 101,
        iHigh: 150,
        cLow: 35.5,
        cHigh: 55.4
    },
    {
        iLow: 151,
        iHigh: 200,
        cLow: 55.5,
        cHigh: 150.4
    },
    {
        iLow: 201,
        iHigh: 300,
        cLow: 150.5,
        cHigh: 250.4
    },
    {
        iLow: 301,
        iHigh: 400,
        cLow: 250.5,
        cHigh: 350.4
    },
    {
        iLow: 401,
        iHigh: 500,
        cLow: 350.5,
        cHigh: 500.4
    }
];

let pm10Map = [
    {
        iLow: 0,
        iHigh: 50,
        cLow: 0,
        cHigh: 54.0
    },
    {
        iLow: 51,
        iHigh: 100,
        cLow: 55,
        cHigh: 154,
    },
    {
        iLow: 101,
        iHigh: 150,
        cLow: 155,
        cHigh: 254
    },
    {
        iLow: 151,
        iHigh: 200,
        cLow: 255,
        cHigh: 354
    },
    {
        iLow: 201,
        iHigh: 300,
        cLow: 355,
        cHigh: 424
    },
    {
        iLow: 301,
        iHigh: 400,
        cLow: 425,
        cHigh: 504
    },
    {
        iLow: 401,
        iHigh: 500,
        cLow: 505,
        cHigh: 604
    }
];

function pmToAQI(pm, pmMap) {
    for(var i = 0; i < pmMap.length; i++) {
        let p = pmMap[i];
        if(pm <= p.cHigh) {
            let aqi = ((p.iHigh - p.iLow) / (p.cHigh - p.cLow)) * (pm - p.cLow) + p.iLow;
            return Math.ceil(aqi);
        }
    }
}

function pm2_5ToAQI(pm) {
    return pmToAQI(pm, pm2_5Map);
}
function pm10ToAQI(pm) {
    return pmToAQI(pm, pm10Map);
}

function update() {
    let fetches = [];
    for(url of urls) {
        fetches.push(fetch(url));
    }
    Promise.all(urls.map((url) => fetch(url)))
        .then((reses) => {
            return Promise.all(reses.map((res) => res.json()))
        })
        .then((datas) => {
            let aqis = [];
            for(data of datas) {
                for(result of data.results) {
                    // ATM for outside and cf_1 for inside: https://www2.purpleair.com/community/faq#!hc-what-is-the-difference-between-cf-1-and-cf-atm
                    let aqi2_5 = pm2_5ToAQI(result.pm2_5_atm);
                    let aqi10 = pm10ToAQI(result.pm10_0_atm);
                    let aqi = Math.max(aqi2_5, aqi10);
                    aqis.push(aqi);
                    //console.log(result);
                    console.log(`aqi: ${aqi} aqi(2.5): ${aqi2_5}, aqi(10): ${aqi10}`);
                }
            }

            let aqiMax = Math.max(...aqis);
            let aqiMin = Math.min(...aqis);
            updateAQI(aqiMin, aqiMax);
        })
        .catch((err) => {
            // Log the error and we'll try again later.
            console.log(err);
        });
}

let bHighAQIState = false;

function updateAQI(aqiMin, aqiMax) {
    console.log(`aqiMin: ${aqiMin} aqiMax: ${aqiMax}`);
    // Seems more appropiate to use aqiMax here.
    let bNewHighAQIState = false;
    if(aqiMax >= highAQI) {
        bNewHighAQIState = true;
    }
    else if (aqiMax <= lowAQI) {
        bNewHighAQIState = false;
    }
    else {
        return;
    }

    if(bHighAQIState != bNewHighAQIState) {
        bHighAQIState = bNewHighAQIState;
        let change = bHighAQIState ? "raised" : "lowered"
        sendMessage(`AQI(${aqiMax}) Update! AQI ${change} to ${aqiMin}-${aqiMax}`);
    }
}

function sendMessage(msg) {
    Promise.all(phoneNumbers.map((number) => {
        tClient.messages.create({
            body: msg,
            to: number,
            from: twilioPhoneNumber
        })
    }))
        .then((messages) => console.log(messages));
}

let cron = require('node-cron');
cron.schedule(schedule, update)

