class RenameProjectsToChallenges < ActiveRecord::Migration[8.1]
  def up
    # -- Backfill polymorphic type names --------------------------------------
    # Dedupe conversations double-created during the step A -> step B rollout
    # window (an old-name and a new-name row can coexist for the same
    # user+context because the unique index treats the two strings as
    # different contexts). Keep the new-name row.
    execute <<~SQL
      DELETE FROM assistant_conversations AS legacy
      USING assistant_conversations AS kept
      WHERE legacy.context_type = 'Project'
        AND kept.context_type = 'Challenge'
        AND legacy.user_id = kept.user_id
        AND legacy.context_id = kept.context_id
    SQL

    execute "UPDATE assistant_conversations SET context_type = 'Challenge' WHERE context_type = 'Project'"
    execute "UPDATE exercise_submissions SET context_type = 'UserChallenge' WHERE context_type = 'UserProject'"
    execute "UPDATE friendly_id_slugs SET sluggable_type = 'Challenge' WHERE sluggable_type = 'Project'"

    # -- Rename the tables -----------------------------------------------------
    rename_column :user_projects, :project_id, :challenge_id
    rename_table :projects, :challenges
    rename_table :user_projects, :user_challenges

    # Compatibility views so in-flight step B code keeps working during the
    # rolling deploy. Dropped in a follow-up migration once this deploy has
    # fully rolled out.
    execute <<~SQL
      CREATE VIEW projects AS SELECT * FROM challenges;
      CREATE VIEW user_projects AS
        SELECT id, user_id, challenge_id AS project_id, started_at, completed_at, created_at, updated_at
        FROM user_challenges;
    SQL
  end

  def down
    execute "DROP VIEW user_projects"
    execute "DROP VIEW projects"

    rename_table :user_challenges, :user_projects
    rename_table :challenges, :projects
    rename_column :user_projects, :challenge_id, :project_id

    execute "UPDATE friendly_id_slugs SET sluggable_type = 'Project' WHERE sluggable_type = 'Challenge'"
    execute "UPDATE exercise_submissions SET context_type = 'UserProject' WHERE context_type = 'UserChallenge'"
    execute "UPDATE assistant_conversations SET context_type = 'Project' WHERE context_type = 'Challenge'"
  end
end
