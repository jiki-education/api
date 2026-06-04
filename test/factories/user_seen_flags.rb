FactoryBot.define do
  factory :user_seen_flag, class: "User::SeenFlag" do
    association :user
    sequence(:key) { |n| "flag_#{n}" }
  end
end
