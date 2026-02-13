FactoryBot.define do
  factory :badge_translation, class: 'Badge::Translation' do
    association :badge, factory: :member_badge
    locale { "hu" }
    name { "Magyar jelvény" }
    description { "Magyar leírás" }
    fun_fact { "Magyar érdekesség" }
    email_subject { "Új jelvényt szereztél!" }
    email_content_markdown { "Gratulálunk a jelvényhez!" }

    trait :hungarian do
      locale { "hu" }
    end

    trait :french do
      locale { "fr" }
      name { "Badge français" }
      description { "Description française" }
      fun_fact { "Fait amusant français" }
      email_subject { "Vous avez gagné un nouveau badge!" }
      email_content_markdown { "Félicitations pour votre badge!" }
    end
  end
end
