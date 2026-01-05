FactoryBot.define do
  # Default to MemberBadge for backward compatibility
  factory :badge, class: "Badges::MemberBadge"

  # Generate specific badge factories using metaprogrammatic pattern (like Exercism)
  %i[
    member
    maze_navigator
    test_public_1
    test_public_2
    test_public_3
    test_public_4
    test_secret_1
    test_secret_2
    test_secret_3
  ].each do |type|
    factory "#{type}_badge", class: "Badges::#{type.to_s.camelize}Badge"
  end
end
