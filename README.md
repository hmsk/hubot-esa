# hubot-esa

[![npm](http://img.shields.io/npm/v/hubot-esa.svg)](https://www.npmjs.com/package/hubot-esa)
[![CircleCI](https://img.shields.io/circleci/project/hmsk/hubot-esa.svg)](https://circleci.com/gh/hmsk/hubot-esa)

A Hubot script handling webhooks and retrieving info from esa: https://esa.io

![hubot-esa-screen ](https://cloud.githubusercontent.com/assets/85887/16569333/2517c0e4-41ea-11e6-9cb8-b436ec1625df.gif)

- Handle received webhooks
  - Post created
  - Post update
  - Post archived
  - Comment created
  - Member joined
- Retrieve info when someone talking about URL of esa
  - Post
  - Comment
- Retrieve stats of your team by `hubot esa stats`

## Installation

### Add to your Hubot project

```
$ npm install hubot-esa --save
```

Then add `hubot-esa` to your `external-scripts.json`.

Also you need some variables to environment your Hubot runs. See below.

### Base Settings

```
export HUBOT_ESA_ACCESS_TOKEN='access_token'    # Required, your personal access token
export HUBOT_ESA_TEAM_NAME='gingypurrs'         # Required, your team name
export HUBOT_ESA_WEBHOOK_DEFAULT_ROOM='random'  # Required, room name you get notification by webhook
export HUBOT_ESA_WEBHOOK_ENDPOINT='/ginger/esa' # Optional, Default: "/hubot/esa"
export HUBOT_ESA_WEBHOOK_SECRET_TOKEN='stoken'  # Optional
```

#### `HUBOT_ESA_ACCESS_TOKEN` Required

- Generate and set your "Personal access token" from `https://[your-team].esa.io/user/applications`.

#### `HUBOT_ESA_TEAM_NAME` Required

- Set your team name

#### `HUBOT_ESA_WEBHOOK_DEFAULT_ROOM` Required

- Set channel/room.for webhook notification from esa as default e.g. `general`

#### `HUBOT_ESA_WEBHOOK_ENDPOINT` Optional (Default: `/hubot/esa`)

- Set the path for endopoint receives webhook from esa.
- Configure your completed uri at `https://[your-team].esa.io/team/webhooks` for Generic webhook

#### `HUBOT_ESA_WEBHOOK_SECRET_TOKEN` Optional

- If some text is set, hubot-esa verifies signature of HTTPS request by esa.io
- Same to secret you configured in `https://[your-team].esa.io/team/webhooks` for Generic webhook

#### `HUBOT_ESA_JUST_EMIT` Optional (Default: `false`)

- If `true` is set, disables messaging
- hubot-esa always triggers below custom events. so you can make customized behavior when receive webhooks

#### `HUBOT_ESA_SLACK_DECORATOR` Optional (Default: `false`)

- If `true` is set, decorates message for Slack

## Use Built-in Slack Decorator

If you're using Hubot for Slack with [hubot-slack](https://www.npmjs.com/package/hubot-slack), you can use built-in Slack decorator implemented for `slack.attachment` event.

Set env values like below.

```
export HUBOT_ESA_WEBHOOK_JUST_EMIT='true'       # Optional, Default: "false"
export HUBOT_ESA_SLACK_DECORATOR='true'         # Optional, Default: "false"
```

## Handle event listener manually

You can implement your script handles above events. For example your can build original message on your own :)

By below setting, disable posting by hubot-esa. Then you can get just emitted event.

```
export HUBOT_ESA_WEBHOOK_JUST_EMIT='true'       # Optional, Default: "false"
```

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

- [@hmsk](http://hmsk.me) who is an esa lover (\\( ⁰⊖⁰)/)

## License

- [MIT License](https://github.com/hmsk/hubot-esa/blob/master/LICENSE)
