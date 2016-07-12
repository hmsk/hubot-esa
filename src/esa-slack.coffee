# Descriptipn
#   Hubot script decorated message from webhook of https://esa.io
#
# Dependencies:
#   hubot-esa
#   hubot-slack
#
# Commands:
#   None
#
# Configuration:
#   HUBOT_ESA_SLACK_DECORATOR
#
# Author:
#   hmsk <k.hamasaki@gmail.com>
#

module.exports = (robot) ->
  options =
    enabled: process.env.HUBOT_ESA_SLACK_DECORATOR == 'true'
    default_room: process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM

  if options.enabled
    robot.emit 'esa.debug', 'Slack decorator enabled'
    # https://api.slack.com/docs/attachments
    buildContent = (message) ->
      content =
        color: '#13958D' # Theme color from esa icon
        fields: []
        pretext: message
        fallback: ''
        thumb_url: 'https://img.esa.io/uploads/production/pictures/105/6161/image/425c3b1e777d356c34973e818543420e.gif'

    emitSlackAttachment = (content, channel) ->
      channel ?= options.default_room
      att =
        channel: channel
        content: content
      robot.emit 'slack.attachment', att
      robot.emit 'esa.debug', "emit slack.attachment with\n#{att}"

    robot.on 'esa.webhook', (kind, data) ->
      putUserAndPostToContent = (content, user, post) ->
        content.author_name = user.screen_name
        content.author_icon = user.icon.url
        content.title = post.name
        content.title_link = post.url

      message_by_kind =
        'post_create': 'New post created'
        'post_update': 'The post updated'
        'post_archive': 'The post archived'
        'comment_create': 'The comment posted'
        'member_join': 'New member joined'

      content = buildContent message_by_kind[kind]
      putUserAndPostToContent content, data.user, data.post unless kind is 'member_join'

      switch kind
        when 'post_create', 'post_update'
          content.text = data.post.message
        when 'comment_create'
          content.text = data.comment.body_md
        when 'member_join'
          content.text = data.user.screen_name

      emitSlackAttachment(content)

    robot.on 'esa.hear.stats', (res, stats) ->
      content = buildContent 'The stats of esa'
      fields = [
        { title: 'Posts', value: stats.posts }
        { title: 'Comments', value: stats.comments }
        { title: 'Stars', value: stats.stars }
        { title: 'Daily Active Users', value: stats.daily_active_users }
        { title: 'Weekly Active Users', value: stats.weekly_active_users }
        { title: 'Monthly Active Users', value: stats.monthly_active_users }
      ]
      content.fields = fields.map (item, i) ->
        item.short = true
        item

      emitSlackAttachment(content, res.envelope.room)

    robot.on 'esa.hear.post', (res, post) ->
      content = buildContent ''
      content.title = post.full_name
      content.title_link = post.url
      content.text = post.body_md
      emitSlackAttachment(content, res.envelope.room)

    robot.on 'esa.hear.comment', (res, comment, post) ->
      content = buildContent ''
      content.title = 'Comment for ' + post.full_name
      content.title_link = comment.url
      content.text = comment.body_md
      content.author_name = comment.created_by.screen_name
      content.author_icon = comment.created_by.icon
      emitSlackAttachment(content, res.envelope.room)
