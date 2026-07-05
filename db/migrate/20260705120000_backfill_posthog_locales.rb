class BackfillPosthogLocales < ActiveRecord::Migration[8.1]
  # PostHog persons now carry a `locales` property (the browser's raw
  # Accept-Language preferences) alongside the served `locale`. Existing
  # persons only pick it up on their next identify, so re-identify every
  # user whose locales have already been captured to seed the field.
  def up
    User::Data.where("cardinality(locales) > 0").includes(:user).find_each do |data|
      User::Identify.defer(data.user)
    end
  end

  def down
    # Enqueues analytics jobs only; nothing to reverse.
  end
end
