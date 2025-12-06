FactoryBot.define do
  factory :lesson_translation, class: 'Lesson::Translation' do
    lesson
    locale { "hu" }
    title { "Magyar leckecím" }
    description { "Magyar leckeleírás" }

    trait :hungarian do
      locale { "hu" }
    end

    trait :french do
      locale { "fr" }
      title { "Titre de la leçon" }
      description { "Description de la leçon" }
    end
  end
end
