FactoryBot.define do
  factory :level do
    slug { "level-#{SecureRandom.hex(4)}" }
    title { "Level #{slug}" }
    description { "Description for #{title}" }
  end
end
