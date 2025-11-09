# frozen_string_literal: true

namespace :typescript do
  desc "Generate TypeScript types from Rails schemas"
  task generate: :environment do
    require_relative '../typescript_generator/generator'

    TypescriptGenerator::Generator.generate_all
  end

  desc "Clean generated TypeScript files"
  task clean: :environment do
    output_dir = Rails.root.join('typescript', 'dist')

    if Dir.exist?(output_dir)
      FileUtils.rm_rf(output_dir)
      puts "🗑️  Cleaned #{output_dir}"
    else
      puts "✨ Nothing to clean"
    end
  end

  desc "Publish TypeScript package to npm"
  task publish: :generate do
    output_dir = Rails.root.join('typescript')

    Dir.chdir(output_dir) do
      puts "📦 Publishing @jiki/api-types to npm..."

      # Bump version (patch by default)
      system('npm version patch')

      # Publish
      result = system('npm publish')

      if result
        puts "✅ Published to npm!"
      else
        puts "❌ Publish failed"
        exit 1
      end
    end
  end
end
