require_relative './base_clinic'

class PharmacyClinic < BaseClinic
  DEFAULT_TWEET_THRESHOLD = ENV['PHARMACY_DEFAULT_TWEET_THRESHOLD']&.to_i || 10
  DEFAULT_TWEET_INCREASE_NEEDED = ENV['PHARMACY_DEFAULT_TWEET_INCREASE_NEEDED']&.to_i || 5
  DEFAULT_TWEET_COOLDOWN = ENV['PHARMACY_DEFAULT_TWEET_COOLDOWN']&.to_i || 60 * 60 # 1 hour
end
