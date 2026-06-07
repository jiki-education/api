class RenameUserSeenFlagsToUserFlags < ActiveRecord::Migration[8.1]
  def up
    rename_table :user_seen_flags, :user_flags

    # All existing rows were written by the FE via the seen_flags endpoint.
    # The new endpoint server-prefixes FE-written keys with "client:" so
    # server-controlled flags are unreachable from the FE; bring existing
    # rows in line with that convention.
    execute %(UPDATE user_flags SET "key" = 'client:' || "key")
  end

  def down
    execute %(UPDATE user_flags SET "key" = SUBSTRING("key" FROM 8) WHERE "key" LIKE 'client:%')
    rename_table :user_flags, :user_seen_flags
  end
end
