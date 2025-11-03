require "test_helper"

class VideoProduction::InvokeLambdaTest < ActiveSupport::TestCase
  def setup
    skip "AWS Lambda SDK not installed yet" unless defined?(Aws::Lambda)
  end

  test "invokes Lambda function asynchronously" do
    function_name = 'jiki-video-merger-test'
    payload = { input_videos: ['s3://bucket/video1.mp4'], output_bucket: 'test-bucket', output_key: 'output.mp4' }

    # Mock Lambda client and response
    mock_client = mock('lambda_client')
    mock_response = mock('lambda_response')
    mock_response.stubs(:status_code).returns(202) # Async returns 202 Accepted

    Jiki.stubs(:lambda_client).returns(mock_client)
    mock_client.expects(:invoke).with(
      function_name: function_name,
      invocation_type: 'Event', # Async invocation
      payload: payload.to_json
    ).returns(mock_response)

    result = VideoProduction::InvokeLambda.(function_name, payload)

    # Async invocation returns acknowledgment, not result
    assert_equal 'invoked', result[:status]
  end

  test "raises error when Lambda returns non-202 status for async invocation" do
    function_name = 'test-function'
    payload = {}

    mock_client = mock('lambda_client')
    mock_response = mock('lambda_response')
    mock_response.stubs(:status_code).returns(500)

    Jiki.stubs(:lambda_client).returns(mock_client)
    mock_client.stubs(:invoke).returns(mock_response)

    error = assert_raises(RuntimeError) do
      VideoProduction::InvokeLambda.(function_name, payload)
    end

    assert_match(/Lambda invocation failed with status 500/, error.message)
  end
end
