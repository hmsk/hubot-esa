# hubot-esa

[![npm](http://img.shields.io/npm/v/hubot-esa.svg)](https://www.npmjs.com/package/hubot-esa)
[![CircleCI](https://img.shields.io/circleci/project/hmsk/hubot-esa.svg)](https://circleci.com/gh/hmsk/hubot-esa)

A Hubot script handling webhooks and retrieving info from esa: https://esa.io

## Features

### Retrieve info when someone talking about URL of esa

#### Post

![image](https://cloud.githubusercontent.com/assets/85887/15594917/2779611a-236f-11e6-8636-1cf975c79048.png)

#### Comment

![image](https://cloud.githubusercontent.com/assets/85887/15594944/73b3c26e-236f-11e6-921b-7a78dadf0489.png)

### Retrieve stats of your team

- Command: `hubot esa stats`

![image](https://cloud.githubusercontent.com/assets/85887/15595025/29e6acfe-2370-11e6-9564-6d62f3288701.png)

### Handle webhooks

![image](https://cloud.githubusercontent.com/assets/85887/15594882/c5362c18-236e-11e6-8b0f-736d07696933.png)

## Installation

```
$ npm install hubot-esa --save
```

And then add `hubot-esa` to your `external-scripts.json`.

Also you need some variables to environment your Hubot runs.

### Add to your Hubot project

### Settings

```
export HUBOT_ESA_ACCESS_TOKEN='access_token'    # Required, your personal access token
export HUBOT_ESA_TEAM_NAME='gingypurrs'         # Required, your team name
export HUBOT_ESA_WEBHOOK_DEFAULT_ROOM='random'  # Required, room name you get notification by webhook
export HUBOT_ESA_WEBHOOK_ENDPOINT='/ginger/esa' # Optional, Default: "/hubot/esa"
export HUBOT_ESA_WEBHOOK_JUST_EMIT='true'       # Optional, Default: "false"
export HUBOT_ESA_WEBHOOK_SECRET_TOKEN='true'    # Optional
```

- `HUBOT_ESA_ACCESS_TOKEN`
  - **Required**
  - Generate and set your "Personal access token" from `https://[your-team].esa.io/user/applications`.

- `HUBOT_ESA_TEAM_NAME`
  - **Required**
  - Set your team name

- `HUBOT_ESA_WEBHOOK_DEFAULT_ROOM`
  - **Required**
  - Set channel/room.for webhook notification from esa as default e.g. `general`

- `HUBOT_ESA_WEBHOOK_ENDPOINT`
  - Optional (Default: `/hubot/esa`)
  - Set the path for endopoint receives webhook from esa.
  - Configure your completed uri at `https://[your-team].esa.io/team/webhooks` for Generic webhook

- `HUBOT_ESA_JUST_EMIT`
  - Optional (Default: `false`)
  - If you set `true`, you can disable messaging
  - hubot-esa always triggers below custom events. so you can make customized behavior when receive webhooks

- `HUBOT_ESA_WEBHOOK_SECRET_TOKEN`
  - Optional
  - If you set some text, hubot-esa verifies signature of request
  - Same to secret you configured in `https://[your-team].esa.io/team/webhooks` for Generic webhook

## Custom Events

You can implement your script handles these event. for example your can build original message on your own :)

### `esa.hear.stats`

- Trigger by someone says to hubot `hubot esa stats`
- With `stats` object: https://docs.esa.io/posts/102#5-1-0 and hubot Response object

```coffeescript
robot.on 'esa.hear.stats', (res, stats) ->
  console.log(stats)
```

### `esa.hear.post`

- Trigger by someone chats post url
- With `post` object: https://docs.esa.io/posts/102#7-2-0 and hubot Response object

```coffeescript
robot.on 'esa.hear.post', (res, post) ->
  console.log(post)
```

### `esa.hear.comment`

- Trigger by someone chats comment url
- With `comment` object: https://docs.esa.io/posts/102#8-2-0, `post` object: https://docs.esa.io/posts/102#7-2-0 and hubot Response object

```coffeescript
robot.on 'esa.hear.comment', (res, comment, post) ->
  console.log(comment)
  console.log(post)
```

### `esa.webhook`

- Trigger by receiving webhook
- With `kind` https://docs.esa.io/posts/37 and `data` object

```coffeescript
robot.on 'esa.webhook', (kind, data) ->
  console.log(comment)
```

```coffeescript
data:
  team: 'team name'
  user: 'user object by webhook'
  post: 'post object by webhook'
  comment: 'comment object by webhook'
```

## Author

- [@hmsk](http://hmsk.me)

## License

- [MIT License](https://github.com/hmsk/hubot-esa/blob/master/LICENSE)
