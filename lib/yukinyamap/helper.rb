# -*- coding: utf-8 -*-

require 'logger'

module Yukinyamap
  module Helper
    def screen_name
      'yukinyamap'
    end

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
      @logger.formatter = Logger::Formatter.new

      @logger
    end

    def stdout
      return @standard_output_logger if @standard_output_logger

      @standard_output_logger = Logger.new(STDOUT)
      @standard_output_logger.formatter = Logger::Formatter.new

      @standard_output_logger
    end

    def stderr
      return @standard_error_logger if @standard_error_logger

      @standard_error_logger = Logger.new(STDERR)
      @standard_error_logger.formatter = Logger::Formatter.new

      @standard_error_logger
    end

    def tee(msg, level = :info)
      if [:error, :warn, :fatal].include?(level)
        error msg
      else
        say msg
      end
      logger.send level, msg
    end

    def say(msg, level = :info)
      stdout.send level, msg
    end

    def error(msg, level = :error)
      if msg.is_a?(Exception)
        msg = "#{msg.message} (#{msg.class})\n" << (msg.backtrace || []).join("\n")
      end
      stderr.send level, msg
    end

    def twitter
      @twitter ||= Twitter.new(config[:twitter])
    end

    def user_stream
      @user_stream ||= UserStream.client(config[:twitter])
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

    def malkov
      @malkov ||= Malkov.new
    end

    def hook_classes
      YM.constants.grep(/Hook$/).map { |c| YM.const_get(c) }
    end
  end

  extend Helper
end
