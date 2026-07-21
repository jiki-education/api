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

    trait :spanish do
      locale { "es-ES" }
      name { "Insignia española" }
      description { "Descripción española" }
      fun_fact { "Dato curioso español" }
      email_subject { "¡Has ganado una nueva insignia!" }
      email_content_markdown { "¡Enhorabuena por tu insignia!" }
    end
  end
end
