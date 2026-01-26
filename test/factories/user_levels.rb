FactoryBot.define do
  factory :user_level do
    user
    level
    course { level.course }

    after(:build) do |user_level|
      unless UserCourse.exists?(user: user_level.user, course: user_level.course)
        create(:user_course, user: user_level.user, course: user_level.course)
      end
    end
  end
end
