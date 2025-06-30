require "thor"
require "pathname"
require "fileutils"

module Zed
  module Rails
    module Jumper
      class CLI < Thor
        def self.start(*)
          super
        rescue Thor::InvocationError, ArgumentError, Errno::ENOENT, IOError => exc
          warn String(exc)
          exit(1)
        end

        def self.exit_on_failure?
          true
        end

        desc "lookup", "Find associated Rails views for the current controller method"
        option :path, aliases: "-p", required: true, desc: "Path to the current file"
        option :root, aliases: "-r", required: true, desc: "Rails application root directory"
        option :line, aliases: "-l", type: :numeric, desc: "Current line number (for cursor position)"
        def lookup
          current_file = options[:path]
          rails_root = options[:root]
          current_line = options[:line]

          view_finder = ViewFinder.new(current_file, rails_root, current_line)
          associated_views = view_finder.find_associated_views

          if associated_views.any?
            # Open the first view file found in Zed
            system("zed", associated_views.first)
          else
            warn "No associated views found"
            exit 1
          end
        end

        desc "controller", "Find the controller and action for a given Rails view file"
        option :path, aliases: "-p", required: true, desc: "Path to the current view file"
        option :root, aliases: "-r", required: true, desc: "Rails application root directory"
        def controller
          view_file = options[:path]
          rails_root = options[:root]

          controller_finder = ControllerFinder.new(view_file, rails_root)
          result = controller_finder.find_controller_and_action

          if result
            # Open the controller file in Zed
            system("zed", result[:controller_file])
          else
            warn "No corresponding controller/action found"
            exit 1
          end
        end

        private

        class ViewFinder
          def initialize(current_file, rails_root, current_line = nil)
            @current_file = Pathname.new(current_file)
            @rails_root = Pathname.new(rails_root)
            @current_line = current_line
          end

          def find_associated_views
            return [] unless controller_file?

            controller_name = extract_controller_name
            action_name = extract_action_name

            return [] unless controller_name && action_name

            find_views_for_action(controller_name, action_name)
          end

          private

          def controller_file?
            @current_file.to_s.include?("controllers") && @current_file.extname == ".rb"
          end

          def extract_controller_name
            # Extract controller name from file path
            # e.g., app/controllers/users_controller.rb -> users
            # e.g., app/controllers/users/archives_controller.rb -> users/archives
            relative_path = @current_file.relative_path_from(@rails_root.join("app", "controllers"))
            return nil unless relative_path.to_s.end_with?("_controller.rb")

            relative_path.to_s.sub("_controller.rb", "")
          end

          def extract_action_name
            return "index" unless @current_line && @current_file.exist?

            # Read the file and find the method at the current line
            lines = @current_file.readlines
            current_line_content = lines[@current_line - 1] if @current_line <= lines.length

            # Look for method definitions around the current line
            method_name = find_method_at_line(lines, @current_line)

            method_name || "index"
          end

          def find_method_at_line(lines, target_line)
            # Find the method definition that contains the target line
            current_method = nil

            lines.each_with_index do |line, line_num|
              line_index = line_num + 1

              # Check if this line is a method definition
              match = line.strip.match(/^\s*def\s+(\w+)/)
              if match
                current_method = match[1]
              end

              # If we've reached the target line, return the current method
              if line_index == target_line
                return current_method
              end
            end

            nil
          end

          def find_views_for_action(controller_name, action_name)
            view_files = []

            # First, try the current controller's view directory
            views_dir = @rails_root.join("app", "views", controller_name)
            view_files.concat(find_view_files_in_directory(views_dir, action_name)) if views_dir.exist?

            # If no views found, check inherited controllers
            if view_files.empty?
              inherited_controllers = find_inherited_controllers(controller_name)
              inherited_controllers.each do |inherited_controller|
                inherited_views_dir = @rails_root.join("app", "views", inherited_controller)
                view_files.concat(find_view_files_in_directory(inherited_views_dir, action_name)) if inherited_views_dir.exist?
              end
            end

            view_files
          end

          def find_view_files_in_directory(views_dir, action_name)
            view_files = []

            # Check for .erb files
            erb_file = views_dir.join("#{action_name}.erb")
            view_files << erb_file.to_s if erb_file.exist?

            # Check for .html.erb files
            html_erb_file = views_dir.join("#{action_name}.html.erb")
            view_files << html_erb_file.to_s if html_erb_file.exist?

            # Check for .js.erb files
            js_erb_file = views_dir.join("#{action_name}.js.erb")
            view_files << js_erb_file.to_s if js_erb_file.exist?

            # Check for .json.jbuilder files
            jbuilder_file = views_dir.join("#{action_name}.json.jbuilder")
            view_files << jbuilder_file.to_s if jbuilder_file.exist?

            # Check for .json.erb files
            json_erb_file = views_dir.join("#{action_name}.json.erb")
            view_files << json_erb_file.to_s if json_erb_file.exist?

            # Check for .xml.builder files
            xml_builder_file = views_dir.join("#{action_name}.xml.builder")
            view_files << xml_builder_file.to_s if xml_builder_file.exist?

            view_files
          end

          def find_inherited_controllers(controller_name)
            inherited_controllers = []

            # Read the controller file to find inheritance
            controller_file = @rails_root.join("app", "controllers", "#{controller_name}_controller.rb")
            return inherited_controllers unless controller_file.exist?

            lines = controller_file.readlines
            lines.each do |line|
              # Look for class definition with inheritance
              # e.g., class Users::ArchivesController < UsersController
              # e.g., class Admin::UsersController < ApplicationController
              if line.strip.match(/class\s+([A-Z][A-Za-z0-9:]*Controller)\s*<\s*([A-Z][A-Za-z0-9:]*Controller)/)
                parent_controller = $2
                # Convert class name to path (e.g., UsersController -> users)
                parent_path = convert_class_name_to_path(parent_controller)
                inherited_controllers << parent_path if parent_path
              end
            end

            inherited_controllers
          end

          def convert_class_name_to_path(class_name)
            return nil if class_name == "ApplicationController"
            # Remove "Controller" suffix
            path = class_name.sub(/Controller$/, "")
            # Replace :: with /
            path = path.gsub(/::/, "/")
            # Convert CamelCase to snake_case for each segment
            path = path.split("/").map { |seg| seg.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase }.join("/")
            path
          end
        end

        class ControllerFinder
          def initialize(view_file, rails_root)
            @view_file = Pathname.new(view_file)
            @rails_root = Pathname.new(rails_root)
          end

          def find_controller_and_action
            # Extract the path relative to app/views
            # e.g., app/views/users/archives/show.html.erb -> users/archives/show
            relative_path = @view_file.relative_path_from(@rails_root.join("app", "views"))
            return nil unless relative_path.to_s.match?(/\.(erb|jbuilder|builder)$/)

            # Remove all possible Rails view extensions
            path_without_ext = relative_path.to_s.sub(/\.(html|json|js|xml)?\.(erb|jbuilder|builder)$/, "").sub(/\.(erb|jbuilder|builder)$/, "")
            path_parts = path_without_ext.split("/")

            return nil if path_parts.empty?

            # The last part is the action name
            action_name = path_parts.pop
            # The remaining parts form the controller path
            controller_parts = path_parts

            return nil if controller_parts.empty?

            # Build the controller file path
            # e.g., users/archives -> app/controllers/users/archives_controller.rb
            controller_path = controller_parts.join("/")
            controller_file = @rails_root.join("app", "controllers", "#{controller_path}_controller.rb")

            return nil unless controller_file.exist?

            # Optionally, check if the method exists in the controller
            if method_defined_in_controller?(controller_file, action_name)
              { controller_file: controller_file.to_s, action_name: action_name }
            else
              { controller_file: controller_file.to_s, action_name: action_name, warning: "Method not found in controller" }
            end
          end

          private

          def method_defined_in_controller?(controller_file, action_name)
            lines = controller_file.readlines
            lines.any? { |line| line.strip.match(/^def\s+#{action_name}\b/) }
          end
        end
      end
    end
  end
end
