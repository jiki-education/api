class BackfillAvatarUrlScheme < ActiveRecord::Migration[8.0]
  def up
    User.where("avatar_url IS NOT NULL AND avatar_url <> '' AND avatar_url NOT LIKE 'http%'").
      update_all("avatar_url = 'https://' || avatar_url")
  end

  def down
    # No-op: cannot reliably reverse without knowing which rows were backfilled
  end
end
