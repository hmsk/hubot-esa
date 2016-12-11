Helper = require 'hubot-test-helper'
chai = require 'chai'
fs = require 'fs'

expect = chai.expect

helper = new Helper '../src/esa-slack.coffee'

describe 'esa-slack', ->
  room = null
  response = null

  initializingKeyword = 'esa mock response object'
  initializingMessage = '@hubot' + initializingKeyword

  lastSentAttachment = ()->
    room.messages[room.messages.length - 1][1].attachments[0]

  initializeRoom = ->
    room = helper.createRoom()
    # Build response object manually
    response = null
    room.robot.respond initializingKeyword, (res) -> response = res
    room.user.say 'gingy', initializingMessage

  beforeEach ->
    process.env.HUBOT_ESA_ACCESS_TOKEN = 'dummy'
    process.env.HUBOT_ESA_TEAM = 'ginger'
    process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM = 'general'
    process.env.HUBOT_ESA_WEBHOOK_ENDPOINT = '/hubot/ginger'
    process.env.HUBOT_ESA_WEBHOOK_SECRET_TOKEN = 'purrs'
    process.env.HUBOT_ESA_JUST_EMIT = 'true'

  context 'disabled by env value', ->
    beforeEach ->
      process.env.HUBOT_ESA_SLACK_DECORATOR = 'false'
      initializeRoom()

    afterEach ->
      room.destroy()

    context 'emit esa.hear.stats event', ->
      beforeEach (done)->
        @stats = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/stats.json")
        room.robot.emit 'esa.hear.stats', response, @stats
        setTimeout done, 200

      it 'not send attachment event', ->
        expect(room.messages[room.messages.length - 1][1]).to.equal initializingMessage

  context 'enabled by env value', ->
    beforeEach ->
      process.env.HUBOT_ESA_SLACK_DECORATOR = 'true'
      initializeRoom()

    afterEach ->
      room.destroy()

    context 'emit esa.hear.stats event', ->
      beforeEach (done)->
        @stats = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/stats.json")
        room.robot.emit 'esa.hear.stats', response, @stats
        setTimeout done, 200

      it 'send attachment with base information', ->
        expect(lastSentAttachment().color).to.equal '#13958D'
        expect(lastSentAttachment().thumb_url).to.equal 'https://img.esa.io/uploads/production/pictures/105/6161/image/425c3b1e777d356c34973e818543420e.gif'

      it 'send attachment with stats', ->
        expect(lastSentAttachment().pretext).to.equal 'The stats of esa'
        expect(lastSentAttachment().fields).to.include {
          title: 'Daily Active Users'
          value: @stats.daily_active_users
          short: true
        }

    context 'emit esa.hear.post event', ->
      beforeEach (done)->
        @post = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/post.json")
        room.robot.emit 'esa.hear.post', response, @post
        setTimeout done, 200

      it 'send attachment with post', ->
        att = lastSentAttachment()
        expect(att.pretext).to.equal ''
        expect(att.title).to.equal @post.full_name
        expect(att.title_link).to.equal @post.url
        expect(att.text).to.equal @post.body_md

    context 'emit esa.hear.comment event', ->
      beforeEach (done)->
        @comment = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/comment.json")
        @post = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/post.json")
        room.robot.emit 'esa.hear.comment', response, @comment, @post
        setTimeout done, 200

      it 'send attachment with post', ->
        att = lastSentAttachment()
        expect(att.pretext).to.equal ''
        expect(att.title).to.equal ('Comment for ' + @post.full_name)
        expect(att.title_link).to.equal @comment.url
        expect(att.text).to.equal @comment.body_md
        expect(att.author_name).to.equal @comment.created_by.screen_name
        expect(att.author_icon).to.equal @comment.created_by.icon

    context 'emit esa.webhook event', ->
      buildWebhookArgs = (fixture) ->
        webhook = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/webhook_#{fixture}.json")
        data =
          team: webhook.team
          user: webhook.user
          post: webhook.post
          comment: webhook.comment || null
        return [webhook.kind, data]

      expectCommonFields = (att, actual) ->
        expect(att.author_name).to.equal actual.user.screen_name
        expect(att.author_icon).to.equal actual.user.icon.url
        expect(att.title).to.equal actual.post.name
        expect(att.title_link).to.equal actual.post.url

      it 'send attachment for post_create', ->
        [kind, data] = buildWebhookArgs('post_create')
        room.robot.emit 'esa.webhook', kind, data
        att = lastSentAttachment()
        expectCommonFields(att, data)
        expect(att.pretext).to.equal 'New post created'
        expect(att.text).to.equal data.post.message

      it 'send attachment for post_update', ->
        [kind, data] = buildWebhookArgs('post_update')
        room.robot.emit 'esa.webhook', kind, data
        att = lastSentAttachment()
        expectCommonFields(att, data)
        expect(att.pretext).to.equal 'The post updated'
        expect(att.text).to.equal data.post.message

      it 'send attachment for post_archive', ->
        [kind, data] = buildWebhookArgs('post_archive')
        room.robot.emit 'esa.webhook', kind, data
        att = lastSentAttachment()
        expectCommonFields(att, data)
        expect(att.pretext).to.equal 'The post archived'
        expect(att.text).to.be.undefined

      it 'send attachment for comment_create', ->
        [kind, data] = buildWebhookArgs('comment_create')
        room.robot.emit 'esa.webhook', kind, data
        att = lastSentAttachment()
        expectCommonFields(att, data)
        expect(att.pretext).to.equal 'The comment posted'
        expect(att.text).to.equal data.comment.body_md

      it 'send attachment for member_join', ->
        [kind, data] = buildWebhookArgs('member_join')
        room.robot.emit 'esa.webhook', kind, data
        att = lastSentAttachment()
        expect(att.pretext).to.equal 'New member joined'
        expect(att.text).to.equal data.user.screen_name
