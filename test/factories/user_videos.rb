FactoryBot.define do
  factory :user_video do
    user
    uuid { SecureRandom.uuid }
    watched_percentage { 0 }
  end
end
