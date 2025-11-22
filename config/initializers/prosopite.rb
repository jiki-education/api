# Configure Prosopite to ignore specific files with known N+1 queries
# These should be fixed eventually, but are temporarily ignored

return unless defined?(Prosopite)

Prosopite.allow_stack_paths = [
  'app/commands/level/create_all_from_json.rb'
]
