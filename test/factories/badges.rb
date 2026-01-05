FactoryBot.define do
  # Default to MemberBadge for backward compatibility
  factory :badge, class: "Badges::MemberBadge"

  # Generate specific badge factories using metaprogrammatic pattern (like Exercism)
  %i[
    member
    maze_navigator
    test_secret
  ].each do |type|
    factory "#{type}_badge", class: "Badges::#{type.to_s.camelize}Badge"
  end
end
