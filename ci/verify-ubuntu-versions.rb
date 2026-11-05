#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates ci/ubuntu-versions.yml and optionally prints the enabled releases
# as a JSON matrix for the Vagrant workflow.

require "json"
require "optparse"
require "yaml"

options = {
  path: File.expand_path("ubuntu-versions.yml", __dir__),
  matrix: false,
  release: "all"
}

OptionParser.new do |parser|
  parser.banner = "Usage: ci/verify-ubuntu-versions.rb [options]"
  parser.on("--file PATH", "Path to ubuntu-versions.yml") { |path| options[:path] = path }
  parser.on("--matrix", "Print the enabled entries as a JSON matrix") { options[:matrix] = true }
  parser.on("--release RELEASE", 'Limit the matrix to one release, or "all"') do |release|
    options[:release] = release
  end
end.parse!

def fail!(message)
  warn "error: #{message}"
  exit 1
end

fail!("no such file: #{options[:path]}") unless File.file?(options[:path])

begin
  document = YAML.safe_load(File.read(options[:path]), permitted_classes: [], aliases: false)
rescue Psych::Exception => error
  fail!("#{options[:path]}: #{error.message}")
end

fail!("#{options[:path]}: expected a mapping with a versions list") unless document.is_a?(Hash)

versions = document["versions"]
unless versions.is_a?(Array) && !versions.empty?
  fail!("#{options[:path]}: versions must be a non-empty list")
end

seen_releases = {}
seen_boxes = {}
previous_release = nil
previous_release_label = nil

versions.each_with_index do |entry, index|
  label = "versions[#{index}]"

  fail!("#{label}: expected a mapping") unless entry.is_a?(Hash)

  missing = %w[release box box_version enabled] - entry.keys
  fail!("#{label}: missing #{missing.join(', ')}") unless missing.empty?

  release = entry["release"]
  box = entry["box"]
  box_version = entry["box_version"]
  enabled = entry["enabled"]

  unless release.is_a?(String) && release.match?(/\A\d{2}\.\d{2}\z/)
    fail!("#{label}: release must be a quoted YY.MM string, got #{release.inspect}")
  end

  release_parts = release.split(".").map(&:to_i)
  if release_parts[1] > 12
    fail!("#{label}: release #{release} has an invalid month")
  end

  if seen_releases.key?(release)
    fail!("#{label}: duplicate release #{release} (also versions[#{seen_releases[release]}])")
  end
  seen_releases[release] = index

  if previous_release && (release_parts <=> previous_release) <= 0
    fail!(
      "#{label}: releases must be in ascending order; " \
      "#{release} follows #{previous_release_label}"
    )
  end
  previous_release = release_parts
  previous_release_label = release

  unless box.is_a?(String) && box.match?(/\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/)
    fail!("#{label}: box must be an owner/name string, got #{box.inspect}")
  end

  if seen_boxes.key?(box)
    fail!("#{label}: duplicate box #{box} (also versions[#{seen_boxes[box]}])")
  end
  seen_boxes[box] = index

  unless box_version.is_a?(String) && box_version.match?(/\A\d+(?:\.\d+)+\z/)
    fail!(
      "#{label}: box_version must be a fixed numeric version such as \"20260108.1.1\", " \
      "got #{box_version.inspect}"
    )
  end

  unless [true, false].include?(enabled)
    fail!("#{label}: enabled must be true or false, got #{enabled.inspect}")
  end
end

enabled = versions.select { |entry| entry["enabled"] }
fail!("#{options[:path]}: no release is enabled") if enabled.empty?

default = enabled.last
warn(
  "#{options[:path]}: #{versions.length} release(s), #{enabled.length} enabled; " \
  "default #{default['release']}"
)

if options[:matrix]
  selected = enabled

  if options[:release] != "all"
    selected = enabled.select { |entry| entry["release"] == options[:release] }
    fail!("release #{options[:release]} is not enabled in #{options[:path]}") if selected.empty?
  end

  puts JSON.generate(selected.map { |entry| entry.slice("release", "box", "box_version") })
end
