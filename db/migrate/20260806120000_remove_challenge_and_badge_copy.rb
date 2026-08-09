class RemoveChallengeAndBadgeCopy < ActiveRecord::Migration[8.1]
  # Step two of a two-part removal - see AllowCurriculumCopyToBeNull. Only
  # safe once the deploy that stopped reading these columns has fully rolled
  # out.
  #
  # Irreversible: the copy is authored in the front-end curriculum repo now.
  def up
    # The `projects` view (a SELECT * compatibility shim from the
    # projects->challenges rename) depends on these columns, so it has to be
    # dropped and recreated around them. It is overdue for removal in its own
    # right - the rolling deploy it covered is long finished - but that is not
    # this migration's business.
    execute "DROP VIEW projects"

    # Challenges are exercises on the front end - their copy comes from the
    # curriculum exercise named by exercise_slug.
    remove_column :challenges, :title
    remove_column :challenges, :description

    execute "CREATE VIEW projects AS SELECT * FROM challenges"

    # Badge names/descriptions/fun facts are authored in
    # curriculum/src/badges/locales/. Only email copy stays here.
    # Badges are identified by their type/slug, so the unique index on name goes
    # with it.
    remove_column :badges, :name
    remove_column :badges, :description
    remove_column :badges, :fun_fact

    remove_column :badge_translations, :name
    remove_column :badge_translations, :description
    remove_column :badge_translations, :fun_fact
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
