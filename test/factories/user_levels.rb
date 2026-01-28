FactoryBot.define do
  factory :user_level do
    user
    level
    after(:build) do |user_level|
      course = user_level.level.course
      create(:user_course, user: user_level.user, course:) unless UserCourse.exists?(user: user_level.user, course:)
    end
  end
end
