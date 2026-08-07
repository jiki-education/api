FactoryBot.define do
  factory :level_translation, class: 'Level::Translation' do
    level
    locale { "hu" }
    milestone_email_subject { "Gratulálunk a szint befejezéséhez!" }
    milestone_email_content_markdown { "Befejezted az összes leckét. Szép munka!" }

    trait :hungarian do
      locale { "hu" }
    end

    trait :spanish do
      locale { "es-ES" }
      milestone_email_subject { "¡Enhorabuena por completar el nivel!" }
      milestone_email_content_markdown { "Has terminado todas las lecciones. ¡Buen trabajo!" }
    end
  end
end
