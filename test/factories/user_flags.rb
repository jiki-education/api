FactoryBot.define do
  factory :user_flag, class: "User::Flag" do
    association :user
    sequence(:key) { |n| "flag_#{n}" }
  end
end
