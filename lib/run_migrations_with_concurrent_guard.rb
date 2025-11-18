# This file runs Rails migrations with a retry guard for any concurrent failures
# Prevents race conditions when multiple ECS containers start simultaneously during rolling deployments

begin
  # Offset all the different containers against each other over 30secs
  # Put it in this begin so it keeps on happening on each retry.
  sleep(rand * 30)

  migration_context = ActiveRecord::Base.connection_pool.migration_context
  migrations = migration_context.migrations
  ActiveRecord::Migrator.new(
    :up,
    migrations,
    migration_context.schema_migration,
    migration_context.internal_metadata
  ).migrate

  Rails.logger.info "Migrations ran cleanly"
rescue ActiveRecord::ConcurrentMigrationError
  # If another service is running the migrations, then
  # we wait until it's finished. There's no timeout here
  # because eventually Fargate will just time the machine out.

  Rails.logger.info "Concurrent migration detected. Waiting to try again."
  retry
end
