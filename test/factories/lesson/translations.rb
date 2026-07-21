FactoryBot.define do
  factory :lesson_translation, class: 'Lesson::Translation' do
    association :lesson, factory: %i[lesson exercise]
    locale { "hu" }
    title { "Magyar leckecím" }
    description { "Magyar leckeleírás" }

    trait :hungarian do
      locale { "hu" }
    end

    trait :spanish do
      locale { "es-ES" }
      title { "Título de la lección" }
      description { "Descripción de la lección" }
    end
  end
end
