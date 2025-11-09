#!/usr/bin/env ruby

ENV['RAILS_ENV'] ||= 'development'

require 'bundler/setup'
require 'jiki-config'
require 'fileutils'
require 'tmpdir'
require 'open3'

puts "=== Video Production Lambda Setup ==="
puts ""

# Check LocalStack is running
print "Checking LocalStack... "
begin
  Jiki.lambda_client.list_functions
  puts "✓"
rescue StandardError => e
  puts "✗"
  puts "Error: LocalStack is not running or not accessible"
  puts "Start it with: bin/dev"
  puts "Error details: #{e.message}"
  exit 1
end

# Configuration
LAMBDA_FUNCTION_NAME = "jiki-video-merger-development".freeze
LAMBDA_SOURCE_DIR = File.expand_path("..", __dir__)
FFMPEG_URL = "https://johnvansickle.com/ffmpeg/builds/ffmpeg-git-amd64-static.tar.xz".freeze

puts ""
puts "Configuration:"
puts "  Function name: #{LAMBDA_FUNCTION_NAME}"
puts "  Source directory: #{LAMBDA_SOURCE_DIR}"
puts ""

# Step 1: Install Node dependencies (including dev dependencies for build)
print "Installing Node.js dependencies... "
Dir.chdir(LAMBDA_SOURCE_DIR) do
  _stdout, stderr, status = Open3.capture3("npm install")
  unless status.success?
    puts "✗"
    puts "Error installing dependencies:"
    puts stderr
    exit 1
  end
end
puts "✓"

# Step 1.5: Build TypeScript
print "Building TypeScript... "
Dir.chdir(LAMBDA_SOURCE_DIR) do
  _stdout, stderr, status = Open3.capture3("npm run build")
  unless status.success?
    puts "✗"
    puts "Error building TypeScript:"
    puts stderr
    exit 1
  end
end
puts "✓"

# Step 2: Download FFmpeg (if not already present)
ffmpeg_binary = File.join(LAMBDA_SOURCE_DIR, "bin", "ffmpeg")
if File.exist?(ffmpeg_binary)
  puts "FFmpeg binary already present ✓"
else
  print "Downloading FFmpeg static binary... "

  Dir.mktmpdir do |tmpdir|
    tarball = File.join(tmpdir, "ffmpeg.tar.xz")

    # Download FFmpeg
    _stdout, stderr, status = Open3.capture3("curl", "-L", "-o", tarball, FFMPEG_URL)
    unless status.success?
      puts "✗"
      puts "Error downloading FFmpeg:"
      puts stderr
      exit 1
    end

    # Extract FFmpeg
    _stdout, stderr, status = Open3.capture3("tar", "xf", tarball, "-C", tmpdir)
    unless status.success?
      puts "✗"
      puts "Error extracting FFmpeg:"
      puts stderr
      exit 1
    end

    # Find the ffmpeg binary in extracted directory
    ffmpeg_dir = Dir.glob(File.join(tmpdir, "ffmpeg-*-static")).first
    unless ffmpeg_dir
      puts "✗"
      puts "Error: Could not find extracted FFmpeg directory"
      exit 1
    end

    # Copy ffmpeg to Lambda source
    FileUtils.mkdir_p(File.join(LAMBDA_SOURCE_DIR, "bin"))
    FileUtils.cp(File.join(ffmpeg_dir, "ffmpeg"), ffmpeg_binary)
    FileUtils.chmod(0o755, ffmpeg_binary)
  end

  puts "✓"
end

# Step 3: Create deployment package
print "Creating deployment package... "
package_file = File.join(Dir.tmpdir, "video-merger-#{Time.now.to_i}.zip")

Dir.chdir(LAMBDA_SOURCE_DIR) do
  files_to_zip = [
    "dist",
    "package.json",
    "node_modules",
    "bin/ffmpeg"
  ]

  _stdout, stderr, status = Open3.capture3("zip", "-r", package_file, *files_to_zip, "-q")
  unless status.success?
    puts "✗"
    puts "Error creating ZIP package:"
    puts stderr
    exit 1
  end
end
puts "✓ (#{File.size(package_file) / 1024 / 1024}MB)"

# Step 4: Delete existing function (if it exists)
print "Checking for existing Lambda function... "
begin
  Jiki.lambda_client.get_function(function_name: LAMBDA_FUNCTION_NAME)
  print "found, deleting... "
  Jiki.lambda_client.delete_function(function_name: LAMBDA_FUNCTION_NAME)
  puts "✓"
rescue Aws::Lambda::Errors::ResourceNotFoundException
  puts "not found"
end

# Step 5: Create Lambda function
print "Deploying Lambda function to LocalStack... "
begin
  Jiki.lambda_client.create_function(
    function_name: LAMBDA_FUNCTION_NAME,
    runtime: 'nodejs20.x',
    role: 'arn:aws:iam::000000000000:role/lambda-role', # LocalStack doesn't validate roles
    handler: 'dist/index.handler',
    code: {
      zip_file: File.read(package_file)
    },
    timeout: 900, # 15 minutes
    memory_size: 3008,
    environment: {
      variables: {
        'AWS_REGION' => 'eu-west-2'
      }
    }
  )
  puts "✓"
rescue StandardError => e
  puts "✗"
  puts "Error deploying Lambda:"
  puts e.message
  puts e.backtrace.first(5).join("\n")
  exit 1
ensure
  FileUtils.rm_f(package_file)
end

puts ""
puts "=== Setup Complete ==="
puts ""
puts "Lambda function '#{LAMBDA_FUNCTION_NAME}' is deployed to LocalStack"
puts ""
puts "Test it with:"
puts "  bin/rails runner \"VideoProduction::InvokeLambda.('#{LAMBDA_FUNCTION_NAME}', { test: true })\""
puts ""
