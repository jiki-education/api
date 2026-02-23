#!/usr/bin/env ruby
# frozen_string_literal: true

# Unlocks all lessons for a given user by creating progress records directly.
# Bypasses command validations and side effects (emails, badges, etc).
# Usage: ruby scripts/unlock_everything.rb <handle>

require_relative "../config/environment"

handle = ARGV[0]

if handle.blank?
  puts "Usage: ruby scripts/unlock_everything.rb <handle>"
  exit 1
end

user = User.where("LOWER(handle) = ?", handle.downcase).first

if user.nil?
  puts "User '#{handle}' not found"
  exit 1
end

now = Time.current

Course.find_each do |course|
  user_course = UserCourse.find_or_create_by!(user:, course:)

  course.levels.each do |level|
    user_level = UserLevel.find_or_create_by!(user:, level:)

    level.lessons.each do |lesson|
      UserLesson.find_or_create_by!(user:, lesson:) do |ul|
        ul.started_at = now
      end
    end
  end
end

puts "All lessons unlocked for #{handle}!"
