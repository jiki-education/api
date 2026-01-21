class SerializeBadge
  include Mandate

  initialize_with :badge, :state, acquired_badge: nil, content: nil

  def call
    {
      id: badge.id,
      name: badge_content[:name],
      slug: badge.slug,
      description: badge_content[:description],
      fun_fact: badge_content[:fun_fact],
      state:,
      num_awardees: badge.num_awardees
    }.tap do |hash|
      hash[:unlocked_at] = acquired_badge.created_at.iso8601 if acquired_badge
    end
  end

  private
  def badge_content
    content || { name: badge.name, description: badge.description, fun_fact: badge.fun_fact }
  end
end
