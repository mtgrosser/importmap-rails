require "test_helper"

class CacheSweeperTest < ActiveSupport::TestCase

  test "sweep is triggered when asset with extra extension changes" do
    previous_accept = Rails.application.config.importmap.accept
    Rails.application.config.importmap.accept += %w[jsx]

    @importmap = Importmap::Map.new.tap do |map|
      map.draw do
        pin "application"
        pin "components/Clock.jsx"
      end
    end

    @importmap.cache_sweeper watches: %w[app/javascript vendor/javascript].map(&Rails.root.method(:join))

    resolver = MockResolver.new(%r{components/Clock\.js\z})
    imports = generate_imports(resolver: resolver)
    touch_asset 'components/Clock.jsx'
    new_imports = generate_imports(resolver: resolver)

    assert_not_nil imports["components/Clock.jsx"]
    assert_not_nil new_imports["components/Clock.jsx"]
    assert_not_nil imports["application"]
    assert_not_nil new_imports["application"]
    assert_not_equal imports["components/Clock.jsx"], new_imports["components/Clock.jsx"]
    assert_equal imports["application"], new_imports["application"]
  ensure
    Rails.application.config.importmap.accept = previous_accept
  end

  private
    def touch_asset(name)
      FileUtils.touch Rails.root.join('app', 'javascript', name)
      sleep 3
      @importmap.cache_sweeper.execute_if_updated
    end

    def generate_imports(resolver: ApplicationController.helpers)
      JSON.parse(@importmap.to_json(resolver: resolver))["imports"]
    end
end
