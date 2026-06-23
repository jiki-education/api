FactoryBot.define do
  factory :user_mailshot, class: "User::Mailshot" do
    user
    mailshot
  end
end
