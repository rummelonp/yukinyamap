#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

root = File.dirname(__FILE__)
$:.unshift File.join(root, 'lib')
ENV['BUNDLE_GEMFILE'] ||= File.join(root, 'Gemfile')

require 'rubygems'
require 'bundler'
Bundler.require
require 'yukinyamap'

command = ARGV.shift
if command =~ /(?:console|cli)/
  Pry.start
else
  Yukinyamap::Stream.new.start
end
