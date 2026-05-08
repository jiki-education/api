FactoryBot.define do
  factory :user_video do
    user
    sequence(:slug) { |n| "video-slug-#{n}" }
    watched_percentage { 0 }
  end
end
