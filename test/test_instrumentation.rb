require File.dirname(__FILE__) + '/test_helper'
require "minitest/autorun"

class InstrumentationTest < MiniTest::Test

  def setup
    @instrumentor = TestInstrumentor
    Resque::Plugins::Instrumentation.instrumentor = @instrumentor
  end

  def test_fork
    worker = Resque::Worker.new(:test)
    Resque::Job.create(:test, InstrumentedJob)
    worker.work(0)

    notification = @instrumentor.notifications['before_first_fork.resque']
    assert !notification.nil?, "before_first_fork should be instrumented"

    notification = @instrumentor.notifications['before_fork.resque']
    assert !notification.nil?, "before_fork should be instrumented"

    # FIXME: this test is failing, not using `fork_per_job`?
    notification = @instrumentor.notifications['after_fork.resque']
    assert !notification.nil?, "after_fork should be instrumented"
  end

  def test_enqueue
    Resque.enqueue(InstrumentedJob, 'foo')

    notification = @instrumentor.notifications['before_enqueue.resque']
    assert !notification.nil?, "before_enqueue should be instrumented"
    assert_equal notification, { queue: 'test', job: 'InstrumentedJob', args: ['foo'] }

    notification = @instrumentor.notifications['after_enqueue.resque']
    assert !notification.nil?, "after_enqueue should be instrumented"
    assert_equal notification, { queue: 'test', job: 'InstrumentedJob', args: ['foo'] }
  end

  def test_dequeue
    Resque.enqueue(InstrumentedJob, 'foo')
    Resque.dequeue(InstrumentedJob, 'bar')

    notification = @instrumentor.notifications['before_dequeue.resque']
    assert !notification.nil?, "before_dequeue should be instrumented"
    assert_equal notification, { queue: 'test', job: 'InstrumentedJob', args: ['bar'] }

    notification = @instrumentor.notifications['after_dequeue.resque']
    assert !notification.nil?, "after_dequeue should be instrumented"
    assert_equal notification, { queue: 'test', job: 'InstrumentedJob', args: ['bar'] }
  end

  def test_perform
    Resque::Job.new('test', { 'class' => 'InstrumentedJob', 'args' => ['bar']}).perform

    notification = @instrumentor.notifications['before_perform.resque']
    assert !notification.nil?, "before_perform should be instrumented"
    assert_equal notification, { queue: 'test', job: 'InstrumentedJob', args: ['bar'] }

    notification = @instrumentor.notifications['after_perform.resque']
    assert !notification.nil?, "after_perform should be instrumented"
    assert_equal notification, { queue: 'test', job: 'InstrumentedJob', args: ['bar'] }

    notification = @instrumentor.notifications['perform.resque']
    assert !notification.nil?, "around_perform should be instrumented"
    assert_equal notification, { queue: 'test', job: 'InstrumentedJob', args: ['bar'] }
  end

  def test_on_failure
    begin
      Resque::Job.new('test', { 'class' => 'InstrumentedFailureJob', 'args' => ['bar']}).perform
    rescue Exception => raised_exception
    end

    notification = @instrumentor.notifications['on_failure.resque']
    assert !notification.nil?, "on_failure should be instrumented"
    instrumented_exception = notification.delete(:exception)
    assert !instrumented_exception.nil?, "on_failure instrumentation should propagate the exception"
    assert_equal raised_exception, instrumented_exception
    assert_equal notification, { queue: 'test', job: 'InstrumentedFailureJob', args: ['bar'] }
  end

  def test_im_a_good_plugin
    Resque::Plugin.lint(Resque::Plugins::Instrumentation)
  end
end

class TestInstrumentor

  def self.instrument(name, params = {}, &block_given)
    notifications[name] = params
    yield if block_given?
  end

  def self.notifications
    @notifications ||= {}
  end
end
