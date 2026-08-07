FactoryBot.define do
  factory :course do
    slug { "course-#{SecureRandom.hex(4)}" }
  end
end
