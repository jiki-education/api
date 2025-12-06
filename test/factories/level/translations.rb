FactoryBot.define do
  factory :level_translation, class: 'Level::Translation' do
    level
    locale { "hu" }
    title { "Magyar cím" }
    description { "Magyar leírás" }
    milestone_summary { "Teljesítetted ezt a szintet! Nagyszerű munka." }
    milestone_content { "# Gratulálunk!\n\nBefejezted az összes leckét." }

    trait :hungarian do
      locale { "hu" }
    end

    trait :french do
      locale { "fr" }
      title { "Titre français" }
      description { "Description française" }
      milestone_summary { "Vous avez terminé ce niveau!" }
      milestone_content { "# Félicitations!\n\nVous avez terminé toutes les leçons." }
    end
  end
end
