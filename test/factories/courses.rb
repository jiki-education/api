FactoryBot.define do
  factory :course do
    slug { "course-#{SecureRandom.hex(4)}" }
    title { "Course #{slug}" }
    description { "Description for #{title}" }
  end
end
