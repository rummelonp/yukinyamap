# -*- coding: utf-8 -*-

require 'logger'

module Yukinyamap
  module Helper
    def root
      @root ||= File.join(File.dirname(File.expand_path(__FILE__)), '..', '..')
    end

    def config
      return @config if @config

      path = File.join(root, 'config', 'config.yml')
      @config = YAML.load_file(path)
    end

    def logger
      return @logger if @logger

      path = File.join(root, 'log', 'yukinyamap.log')
      @logger = Logger.new(path)
    end

    def tee(msg, level = :info)
      if [:error, :warn, :fatal].include?(level)
        error msg
      else
        say msg
      end
      logger.send level, msg
    end

    def say(msg)
      $stdout.puts msg
    end

    def error(msg)
      if msg.is_a?(Exception)
        $stderr.puts "#{msg.message} (#{msg.class})\n" << (msg.backtrace || []).join("\n")
      else
        $stderr.puts msg
      end
    end

    def user_stream
      @twitter ||= UserStream.client(config[:twitter])
    end

    def db
      @db ||= Mongo::Connection.new.db('yukinyamap')
    end

    def collection(col_key)
      db.collection(col_key)
    end

    def col_key_from_status(status)
      %w{friends event delete}.find {|key| status.key?(key)} || 'status'
    end

    def tagger
      @tagger ||= Natto::MeCab.new('-O wakati')
    end
  end

  extend Helper
end
