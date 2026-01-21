FactoryBot.define do
  factory :badge_translation, class: 'Badge::Translation' do
    association :badge, factory: :member_badge
    locale { "hu" }
    name { "Magyar jelvény" }
    description { "Magyar leírás" }
    fun_fact { "Magyar érdekesség" }

    trait :hungarian do
      locale { "hu" }
    end

    trait :french do
      locale { "fr" }
      name { "Badge français" }
      description { "Description française" }
      fun_fact { "Fait amusant français" }
    end
  end
end
