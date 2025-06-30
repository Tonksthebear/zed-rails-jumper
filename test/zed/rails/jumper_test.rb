require "test_helper"

class Zed::Rails::JumperTest < ActiveSupport::TestCase
  def setup
    @rails_root = Pathname.new(File.expand_path("../../dummy", __dir__))
  end
  
  def test_finds_erb_view
    controller_file = @rails_root.join("app", "controllers", "users_controller.rb")
    # Line 3 is inside the index method
    view_finder = Zed::Rails::Jumper::CLI::ViewFinder.new(controller_file, @rails_root, 3)
    
    views = view_finder.send(:find_associated_views)
    assert_includes views, @rails_root.join("app", "views", "users", "index.html.erb").to_s
  end
  
  def test_finds_multiple_view_formats
    controller_file = @rails_root.join("app", "controllers", "users_controller.rb")
    # Line 7 is inside the show method
    view_finder = Zed::Rails::Jumper::CLI::ViewFinder.new(controller_file, @rails_root, 7)
    
    views = view_finder.send(:find_associated_views)
    assert_includes views, @rails_root.join("app", "views", "users", "show.html.erb").to_s
    assert_includes views, @rails_root.join("app", "views", "users", "show.json.jbuilder").to_s
  end
  
  def test_extracts_controller_name
    controller_file = @rails_root.join("app", "controllers", "users_controller.rb")
    view_finder = Zed::Rails::Jumper::CLI::ViewFinder.new(controller_file, @rails_root)
    
    controller_name = view_finder.send(:extract_controller_name)
    assert_equal "users", controller_name
  end

  def test_extracts_nested_controller_name
    controller_file = @rails_root.join("app", "controllers", "users", "archives_controller.rb")
    view_finder = Zed::Rails::Jumper::CLI::ViewFinder.new(controller_file, @rails_root)
    
    controller_name = view_finder.send(:extract_controller_name)
    assert_equal "users/archives", controller_name
  end
  
  def test_extracts_action_name_from_line
    controller_file = @rails_root.join("app", "controllers", "users_controller.rb")
    # Line 3 is inside the index method
    view_finder = Zed::Rails::Jumper::CLI::ViewFinder.new(controller_file, @rails_root, 3)
    
    action_name = view_finder.send(:extract_action_name)
    assert_equal "index", action_name
  end

  def test_finds_views_for_nested_controller
    controller_file = @rails_root.join("app", "controllers", "users", "archives_controller.rb")
    # Line 3 is inside the show method
    view_finder = Zed::Rails::Jumper::CLI::ViewFinder.new(controller_file, @rails_root, 3)
    
    views = view_finder.send(:find_associated_views)
    assert_includes views, @rails_root.join("app", "views", "users", "archives", "show.html.erb").to_s
  end

  def test_finds_views_in_inherited_controller
    controller_file = @rails_root.join("app", "controllers", "users", "archives_controller.rb")
    # Line 7 is inside the index method (which does not have a view in the nested dir, so should fall back to parent)
    view_finder = Zed::Rails::Jumper::CLI::ViewFinder.new(controller_file, @rails_root, 7)
    
    views = view_finder.send(:find_associated_views)
    # Should find the view in the parent controller's directory
    assert_includes views, @rails_root.join("app", "views", "users", "index.html.erb").to_s
  end

  def test_finds_controller_from_view
    view_file = @rails_root.join("app", "views", "users", "show.html.erb")
    controller_finder = Zed::Rails::Jumper::CLI::ControllerFinder.new(view_file, @rails_root)
    
    result = controller_finder.find_controller_and_action
    assert_equal @rails_root.join("app", "controllers", "users_controller.rb").to_s, result[:controller_file]
    assert_equal "show", result[:action_name]
  end

  def test_finds_nested_controller_from_view
    view_file = @rails_root.join("app", "views", "users", "archives", "show.html.erb")
    controller_finder = Zed::Rails::Jumper::CLI::ControllerFinder.new(view_file, @rails_root)
    
    result = controller_finder.find_controller_and_action
    assert_equal @rails_root.join("app", "controllers", "users", "archives_controller.rb").to_s, result[:controller_file]
    assert_equal "show", result[:action_name]
  end

  def test_finds_controller_from_json_view
    view_file = @rails_root.join("app", "views", "users", "show.json.jbuilder")
    controller_finder = Zed::Rails::Jumper::CLI::ControllerFinder.new(view_file, @rails_root)
    
    result = controller_finder.find_controller_and_action
    assert_equal @rails_root.join("app", "controllers", "users_controller.rb").to_s, result[:controller_file]
    assert_equal "show", result[:action_name]
  end

  def test_returns_nil_for_nonexistent_controller
    view_file = @rails_root.join("app", "views", "nonexistent", "show.html.erb")
    controller_finder = Zed::Rails::Jumper::CLI::ControllerFinder.new(view_file, @rails_root)
    
    result = controller_finder.find_controller_and_action
    assert_nil result
  end

  def test_detects_method_exists_in_controller
    view_file = @rails_root.join("app", "views", "users", "index.html.erb")
    controller_finder = Zed::Rails::Jumper::CLI::ControllerFinder.new(view_file, @rails_root)
    
    result = controller_finder.find_controller_and_action
    assert_equal @rails_root.join("app", "controllers", "users_controller.rb").to_s, result[:controller_file]
    assert_equal "index", result[:action_name]
    assert_nil result[:warning] # No warning means method was found
  end

  def test_detects_method_missing_in_controller
    view_file = @rails_root.join("app", "views", "users", "missing_action.html.erb")
    controller_finder = Zed::Rails::Jumper::CLI::ControllerFinder.new(view_file, @rails_root)
    
    result = controller_finder.find_controller_and_action
    assert_equal @rails_root.join("app", "controllers", "users_controller.rb").to_s, result[:controller_file]
    assert_equal "missing_action", result[:action_name]
    assert_equal "Method not found in controller", result[:warning]
  end

  def test_converts_class_name_to_path
    view_finder = Zed::Rails::Jumper::CLI::ViewFinder.new(@rails_root.join("app", "controllers", "users_controller.rb"), @rails_root)
    
    assert_equal "users", view_finder.send(:convert_class_name_to_path, "UsersController")
    assert_equal "users/archives", view_finder.send(:convert_class_name_to_path, "Users::ArchivesController")
    assert_equal "admin/users", view_finder.send(:convert_class_name_to_path, "Admin::UsersController")
    assert_nil view_finder.send(:convert_class_name_to_path, "ApplicationController")
  end

  def test_finds_inherited_controllers
    view_finder = Zed::Rails::Jumper::CLI::ViewFinder.new(@rails_root.join("app", "controllers", "users", "archives_controller.rb"), @rails_root)
    
    inherited_controllers = view_finder.send(:find_inherited_controllers, "users/archives")
    assert_includes inherited_controllers, "users"
  end
end
