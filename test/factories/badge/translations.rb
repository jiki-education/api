FactoryBot.define do
  factory :badge_translation, class: 'Badge::Translation' do
    association :badge, factory: :member_badge
    locale { "hu" }
    email_subject { "Új jelvényt szereztél!" }
    email_content_markdown { "Gratulálunk a jelvényhez!" }

    trait :hungarian do
      locale { "hu" }
    end

    trait :spanish do
      locale { "es-ES" }
      email_subject { "¡Has ganado una nueva insignia!" }
      email_content_markdown { "¡Enhorabuena por tu insignia!" }
    end
  end
end
