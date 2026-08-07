FactoryBot.define do
  factory :concept do
    # Zero-padded: concepts are ordered by slug, and an unpadded sequence would
    # sort concept-10 before concept-9.
    sequence(:slug) { |n| "concept-#{n.to_s.rjust(4, '0')}" }
  end
end
