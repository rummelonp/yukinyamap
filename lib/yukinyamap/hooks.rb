# -*- coding: utf-8 -*-

module Yukinyamap
  class MongoHook
    def match(status)
      true
    end

    def call(status)
      if status.text
        status.keywords = YM.tagger.parse(status.text).split(' ')
      end
      YM.collection(YM.col_key_from_status(status)).insert(status)
    end
  end

  class LogHook
    def match(status)
      true
    end

    def call(status)
      key = YM.col_key_from_status(status)
      message = key
      if key == 'status'
        message += ": @#{status.user!.screen_name}"
      end
      YM.tee message, :debug
    end
  end

  class StoreHook
    def match(status)
      status.user!.screen_name != YM.screen_name &&
        status.text &&
        !status.protected?
    end

    def call(status)
      YM.malkov.rotate(status.text)
    end
  end

  class TweetHook
    def initialize
      @tweet_count = 0
      @users       = {}
      @update_time = Time.now
      @min_count   = YM.config[:tweet][:min][:count]
      @min_minutes = YM.config[:tweet][:min][:minutes].minutes
      @max_count   = YM.config[:tweet][:max][:count]
      @max_minutes = YM.config[:tweet][:max][:minutes].minutes
      @keywords    = YM.config[:keywords]
    end

    def match(status)
      status.user!.screen_name != YM.screen_name
    end

    def call(status)
      update_state(status)
      return if runaway?(status)
      if message = message_from_keyword(status.text)
        reset_state
        do_reply(status, message)
      elsif status.in_reply_to_screen_name == YM.screen_name
        reset_state
        do_popular_reply(status)
      elsif state?
        reset_state
        do_tweet
      end
    end

    def state?
      diff = Time.now.to_i - @update_time.to_i
      return true if diff > @max_minutes
      return true if @tweet_count > @max_count
      return true if @tweet_count > @min_count && diff > @min_minutes
      false
    end

    def runaway?(status)
      return true unless status.user
      @users.select { |t, s| s == status.user.screen_name }.size > 5
    end

    def update_state(status)
      return unless status.text
      @tweet_count += 1
      return unless status.user
      @users[Time.now] = status.user.screen_name
      @users.each { |t, s| @users.delete(t) if t < 1.minutes.ago }
    end

    def reset_state
      @tweet_count = 0
      @update_time = Time.now
    end

    def message_from_keyword(text)
      return unless text
      keyword = @keywords.find { |h| text.match(h[:condition]) }
      keyword[:messages].sample if keyword
    end

    def do_tweet
      YM.twitter.update(YM.malkov.generate)
    end

    def do_reply(status, message)
      tweet = "@#{status.user.screen_name} #{message}"
      options = {:in_reply_to_status_id => status.id}
      YM.twitter.update(tweet, options)
    end

    def do_popular_reply(status)
      popular_words = YM.malkov.popular_words.map(&:first)
      word = popular_words.find { |w|
        status.keywords.include?(w)
      } || YM.malkov.popular_word
      do_reply(status, YM.malkov.generate_from_word(word))
    end
  end

  class FollowHook
    def match(status)
      status.event == 'follow' &&
        status.source.screen_name != YM.screen_name
    end

    def call(status)
      YM.twitter.follow(status.source.screen_name)
      tweet = "@#{status.source.screen_name} #{YM.malkov.generate_popular}"
      YM.twitter.update(tweet)
    end
  end
end

Dir[YM.root + '/hooks/**.rb'].each { |f| require f }
