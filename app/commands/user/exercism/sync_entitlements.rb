class User::Exercism::SyncEntitlements
  include Mandate

  queue_as :default

  # Pulls Exercism's current entitled-user rosters and queues a per-user
  # resync for every user whose local state disagrees with the roster.
  # The per-user resync re-fetches that user's status as the source of truth,
  # which naturally resolves any race between roster-fetch and reconcile.
  def call
    rosters = Exercism::FetchEntitledUsers.()
    insider_ids = rosters['insider_ids']
    bootcamp_ids = rosters['bootcamp_member_ids']

    User.where(id: delta_user_ids(insider_ids, bootcamp_ids)).find_each do |user|
      User::Exercism::ResyncUser.defer(user)
    end
  end

  private
  def delta_user_ids(insider_ids, bootcamp_ids)
    (
      insider_gainer_ids(insider_ids) +
      insider_loser_ids(insider_ids) +
      bootcamp_gainer_ids(bootcamp_ids)
    ).uniq
  end

  # Users whose exercism_id is on the insider roster but who don't currently
  # hold an active insider entitlement.
  def insider_gainer_ids(insider_ids)
    return [] if insider_ids.empty?

    User.
      where(exercism_id: insider_ids).
      where.not(id: active_entitlement_user_ids(PremiumEntitlement::EXERCISM_INSIDER)).
      pluck(:id)
  end

  # Users who currently hold an active insider entitlement but whose
  # exercism_id is NOT on the roster.
  def insider_loser_ids(insider_ids)
    User.
      where(id: active_entitlement_user_ids(PremiumEntitlement::EXERCISM_INSIDER)).
      where.not(exercism_id: insider_ids).
      pluck(:id)
  end

  def bootcamp_gainer_ids(bootcamp_ids)
    return [] if bootcamp_ids.empty?

    User.
      where(exercism_id: bootcamp_ids).
      where.not(id: active_entitlement_user_ids(PremiumEntitlement::EXERCISM_BOOTCAMP)).
      pluck(:id)
  end

  def active_entitlement_user_ids(source)
    PremiumEntitlement.active.where(source: source).select(:user_id)
  end
end
