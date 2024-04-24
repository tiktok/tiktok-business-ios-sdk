# TikTok Business Mobile SDK for Reporting App Events

** For details including integration instructions, see the [TikTok Business Mobile SDK Documentation](https://ads.tiktok.com/marketing_api/docs?rid=rscv11ob9m9&id=1683661413969921). **


## Objective
The TikTok Business SDK is the easiest way to log events (e.g. app install, purchase) in your mobile application and send these events to TikTok for targeting, measurement, conversion optimization, etc. We provide an Android SDK and an iOS SDK that you can integrate into your app easily.
<br/>

`Note`
In essence, the SDK reports app events through the App events marketing API. See the ["Report App Events"](https://ads.tiktok.com/marketing\_api/docs?rid=8ggud9r3gfu&amp;id=1679472066464769) documentation as a source of truth of the app events/properties TikTok marketing API accepts.**

## How it Works

There are two types of app events:

* Automatically logged app events: The TikTok business SDK automatically logs InstallApp, LaunchApp, 2DRetention, and (iOS only) Purchase app events.

* Manually logged app events: You can use the function provided by the TikTok business SDK to track events specific to your app. For a complete list of app events (and properties) supported by the TikTok marketing API, see the &quot;[Report App Events](https://ads.tiktok.com/marketing_api/docs?id=1679472066464769)&quot; marketing API documentation.
<br/>

The TikTok business SDK takes the automatically/manually logged events, and reports these events to TikTok app events marketing API for downstream processing. The reported events will

- [Coming soon] Show up in reporting if attributed to TikTok.

- Be used for audience and DPA.

- Be used in optimization models based on app events.

## Benefits

* Easiest way to log events (e.g. App install, purchase) in your mobile application and send these events to TikTok
   * Automatically logs InstallApp, LaunchApp, 2DRetention, and (iOS only) Purchase.
   * Provides simple functions to manually log events.
   * Handles logic to save app events and flush app events to TikTok marketing API.

* Currently, advertisers are only able to send app event data through their measurement partners. Some advertisers prefer to directly send app event data to TikTok.
   * We may use this app event data for subsequent retargeting and dynamic product ads like we do with app event data forwarded from measurement partners.
   * In the near future, we will introduce our own attribution solutions and input into our optimization models based on these app events.

** For details including integration instructions, see the [TikTok Business Mobile SDK Documentation](https://ads.tiktok.com/marketing_api/docs?rid=rscv11ob9m9&id=1683661413969921). **