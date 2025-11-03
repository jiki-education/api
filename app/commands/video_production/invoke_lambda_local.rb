class VideoProduction::InvokeLambdaLocal
  include Mandate

  initialize_with :function_name, :payload

  def call
    # Spawn background process to execute Lambda handler asynchronously
    # This mimics AWS Lambda's async 'Event' invocation type

    pid = Process.spawn(
      aws_env,
      'ruby',
      '-e', background_script,
      chdir: Rails.root,
      out: '/dev/null',
      err: Rails.root.join('log', 'lambda_local.log').to_s
    )

    # Detach process so it runs independently
    Process.detach(pid)

    # Return immediately, matching InvokeLambda async behavior
    # Lambda will callback to SPI endpoint when complete
    { status: 'invoked' }
  rescue StandardError => e
    Rails.logger.error("[Lambda Local] Failed to spawn process: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise "Failed to invoke Lambda locally: #{e.message}"
  end

  private
  # Background Ruby script that executes Lambda and sends callback
  memoize
  def background_script
    <<~RUBY
      require 'bundler/setup'
      require 'jiki-config'
      require 'open3'
      require 'json'

      begin
        # Sleep 1 second to ensure parent request completes
        sleep 1

        # Execute Node.js handler
        # The Lambda handler will call the callback URL itself via fetch()
        stdout, stderr, status = Open3.capture3(
          #{aws_env.inspect},
          'node',
          '-e', #{node_script.to_json},
          #{JSON.generate(payload).to_json},
          chdir: #{Rails.root.to_s.to_json}
        )

        # Log execution results
        if status.success?
          puts "[Lambda Local] Lambda execution completed successfully"
          puts "[Lambda Local] stdout: \#{stdout}" if stdout && !stdout.empty?
        else
          puts "[Lambda Local] Lambda execution failed with exit code \#{status.exitstatus}"
          puts "[Lambda Local] stdout: \#{stdout}" if stdout && !stdout.empty?
          puts "[Lambda Local] stderr: \#{stderr}" if stderr && !stderr.empty?
        end
      rescue => e
        puts "[Lambda Local] Background execution failed: \#{e.message}"
        puts e.backtrace.first(5).join("\\n")
      end
    RUBY
  end

  # Map function name to handler path
  memoize
  def handler_path
    case function_name
    when /video-merger/
      'services/video_production/video-merger/dist/index.js'
    else
      raise "Unknown Lambda function: #{function_name}"
    end
  end

  # Build Node.js script that requires and invokes the handler
  memoize
  def node_script
    <<~JAVASCRIPT
      const handler = require('./#{handler_path}').handler;
      const event = JSON.parse(process.argv[1]);

      handler(event).then(result => {
        console.log(JSON.stringify(result));
        process.exit(result.statusCode === 200 ? 0 : 1);
      }).catch(error => {
        console.error('[Lambda Local Error]', error.message);
        console.error(error.stack);
        const errorResult = { error: error.message, statusCode: 500 };
        console.log(JSON.stringify(errorResult));
        process.exit(1);
      });
    JAVASCRIPT
  end

  # Get AWS settings from config gem (handles LocalStack in dev/test)
  memoize
  def aws_env
    aws_settings = JikiConfig::GenerateAwsSettings.()
    env = {
      'AWS_REGION' => aws_settings[:region]
    }
    env['AWS_ENDPOINT_URL'] = aws_settings[:endpoint] if aws_settings[:endpoint]
    env['AWS_ACCESS_KEY_ID'] = aws_settings[:access_key_id] if aws_settings[:access_key_id]
    env['AWS_SECRET_ACCESS_KEY'] = aws_settings[:secret_access_key] if aws_settings[:secret_access_key]
    env
  end
end
