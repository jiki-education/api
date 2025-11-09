require 'test_helper'

class VideoProduction::InvokeLambdaLocalTest < ActiveSupport::TestCase
  test "raises error if Process.spawn fails" do
    # Mock Process.spawn to raise an error
    Process.stubs(:spawn).raises(Errno::ENOENT, "command not found")

    error = assert_raises(RuntimeError) do
      VideoProduction::InvokeLambdaLocal.(
        'jiki-video-merger-development',
        { test: true }
      )
    end

    assert_match(/Failed to invoke Lambda locally/, error.message)
    assert_match(/command not found/, error.message)
  end

  test "successfully spawns background process" do
    # Mock Process.spawn to return a fake PID
    fake_pid = 12_345

    Process.stubs(:spawn).returns(fake_pid)
    Process.stubs(:detach)

    result = VideoProduction::InvokeLambdaLocal.(
      'jiki-video-merger-development',
      { test: true }
    )

    assert_equal({ status: 'invoked' }, result)
  end
end
