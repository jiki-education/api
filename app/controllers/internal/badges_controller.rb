class Internal::BadgesController < Internal::BaseController
  def index
    num_locked_secret_badges = Badge.secret.where.not(
      id: current_user.acquired_badges.select(:badge_id)
    ).count

    render json: {
      badges: SerializeBadges.(current_user),
      num_locked_secret_badges:
    }
  end

  def reveal
    acquired_badge = current_user.acquired_badges.find_by(badge_id: params[:id])

    return render_404(:badge_not_found) if acquired_badge.nil?

    User::AcquiredBadge::Reveal.(acquired_badge)

    render json: { badge: SerializeAcquiredBadge.(acquired_badge) }
  end
end
