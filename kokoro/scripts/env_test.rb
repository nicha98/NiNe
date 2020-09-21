#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'
require 'tmpdir'

current_dir = FileUtils.pwd()
puts("--- current_dir: #{current_dir}")

realpath = Pathname.new("./").realpath
puts("--- Pathname.new(\"./\").realpath: #{realpath}")

temp_dir = Pathname(Dir.mktmpdir(['CocoaPods-Lint-', "-TestTempDir"]))
puts("--- temp_dir: #{temp_dir}")

temp_realpath = Pathname.new(temp_dir).realpath
puts("--- Pathname.new(temp_dir).realpath: #{temp_realpath}")

puts("--- File.directory?(temp_realpath): #{File.directory?(temp_realpath)}")