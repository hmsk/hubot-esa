# hubot-esa

[image: react to URL]

[image: get stats]

[image: notify from webhook]

## Installation

```
$ npm install hubot-esa --save
```

And then add `hubot-esa` to external-scripts.json.

Also you should set some variables to environment your Hubot runs.

### Add to your Hubot project

### Settings

#### HUBOT_ESA_ACCESS_TOKEN (required)

Generate and set your "Personal access token" from `https://[your-team].esa.io/user/applications`.

#### HUBOT_ESA_TEAM_NAME (required)

Set your team name.

#### HUBOT_ESA_WEBHOOK_DEFAULT_ROOM (required)

Set channel/room.for webhook notification from esa as default e.g. `general`

#### HUBOT_ESA_WEBHOOK_ENDPOINT (optional)

Set the path for endopoint receiving webhook from esa.
default endpoint: `/hubot/esa`

If you set this value, you should also set this to generic Webhook setting on esa: `https://[your-team].esa.io/team/webhooks`

#### HUBOT_ESA_WEBHOOK_JUST_EMIT (optional)

If you set `true`, you can disable messaging by webhook.
hubot-esa triggers `esa.webhook` events with received data. so you can make customized behavior when receive webhooks.

## Slack message deco

If you set `true` for both `HUBOT_ESA_WEBHOOK_SLACK_DECORATOR` and `HUBOT_ESA_WEBHOOK_ENDPOINT`, you get rich messages on your Slack.

[images]

## License

MIT
