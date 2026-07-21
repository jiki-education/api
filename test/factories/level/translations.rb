FactoryBot.define do
  factory :level_translation, class: 'Level::Translation' do
    level
    locale { "hu" }
    title { "Magyar cím" }
    description { "Magyar leírás" }
    milestone_summary { "Teljesítetted ezt a szintet! Nagyszerű munka." }
    milestone_content { "# Gratulálunk!\n\nBefejezted az összes leckét." }
    milestone_email_subject { "Gratulálunk a szint befejezéséhez!" }
    milestone_email_content_markdown { "Befejezted az összes leckét. Szép munka!" }

    trait :hungarian do
      locale { "hu" }
    end

    trait :spanish do
      locale { "es-ES" }
      title { "Título español" }
      description { "Descripción española" }
      milestone_summary { "¡Has completado este nivel!" }
      milestone_content { "# ¡Enhorabuena!\n\nHas terminado todas las lecciones." }
      milestone_email_subject { "¡Enhorabuena por completar el nivel!" }
      milestone_email_content_markdown { "Has terminado todas las lecciones. ¡Buen trabajo!" }
    end
  end
end
