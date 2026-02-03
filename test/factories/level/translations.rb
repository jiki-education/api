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

    trait :french do
      locale { "fr" }
      title { "Titre français" }
      description { "Description française" }
      milestone_summary { "Vous avez terminé ce niveau!" }
      milestone_content { "# Félicitations!\n\nVous avez terminé toutes les leçons." }
      milestone_email_subject { "Félicitations pour avoir terminé ce niveau!" }
      milestone_email_content_markdown { "Vous avez terminé toutes les leçons. Beau travail!" }
    end
  end
end
