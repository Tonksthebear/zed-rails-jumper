# Zed Rails Jumper

A CLI gem for the Zed editor that helps developers quickly jump between Rails controllers and their associated views. Inspired by [zed-test-toggle](https://github.com/MoskitoHero/zed-test-toggle).

## Installation

Ensure the [Zed CLI is installed](https://zed.dev/docs/getting-started?highlight=cli#cli)

Install the gem:

```bash
gem install zed-rails-jumper
```

## Usage

This tool is designed to be called from Zed tasks. It can jump in both directions:
- From controller methods to associated view files
- From view files to their corresponding controller and action

**Note**: The tool automatically opens the target file in Zed using `system("zed", file_path)`.

### Zed Task Configuration

Add these tasks to your Zed tasks configuration:

```json
[
  {
    "label": "Jump to Rails View",
    "command": "bundle exec zed-rails-jumper",
    "args": [
      "lookup",
      "-p",
      "\"$ZED_RELATIVE_FILE\"",
      "-r",
      "./",
      "-l",
      "\"$ZED_ROW\""
    ],
    "hide": "always",
    "use_new_terminal": false,
    "reveal": "never"
  },
  {
    "label": "Jump to Rails Controller",
    "command": "bundle exec zed-rails-jumper",
    "args": ["controller", "-p", "\"$ZED_RELATIVE_FILE\"", "-r", "./"],
    "hide": "always",
    "use_new_terminal": false,
    "reveal": "never"
  }
]
```

### Keybinding Configuration

Add these keybindings to your Zed keybindings:

```json
[
  {
    "bindings": {
      "cmd-shift-v": [
        "task::Spawn",
        {
          "task_name": "Jump to Rails View",
          "reevaluate_context": true
        }
      ],
      "cmd-shift-c": [
        "task::Spawn",
        {
          "task_name": "Jump to Rails Controller",
          "reevaluate_context": true
        }
      ]
    }
  }
]
```

## How it Works

### Controller to View Jumping
1. **Controller Detection**: The tool detects if you're in a Rails controller file
2. **Method Detection**: Based on cursor position, it finds the current controller method
3. **View Discovery**: It searches for view files in the corresponding `app/views` directory
4. **File Opening**: Opens the first matching view file in Zed using `system("zed", file_path)`
5. **Multiple Formats**: Supports various view formats:
   - `.html.erb`
   - `.erb`
   - `.js.erb`
   - `.json.erb`
   - `.json.jbuilder`
   - `.xml.builder`

### View to Controller Jumping
1. **View Detection**: The tool detects if you're in a Rails view file
2. **Controller Mapping**: It maps the view path to the corresponding controller
3. **Action Detection**: It extracts the action name from the view filename
4. **Method Verification**: It checks if the action method exists in the controller
5. **File Opening**: Opens the controller file in Zed using `system("zed", file_path)`

## Examples

### Controller to View
If you're in `app/controllers/users_controller.rb` at line 5 (inside the `index` method), the tool will:
1. Find `app/views/users/index.html.erb`
2. Automatically open it in Zed

### View to Controller
If you're in `app/views/users/show.html.erb`, the tool will:
1. Find `app/controllers/users_controller.rb`
2. Automatically open it in Zed

## CLI Commands

### `lookup` - Find and open views for current controller method
```bash
zed-rails-jumper lookup -p "app/controllers/users_controller.rb" -r "/path/to/rails/app" -l 5
```

### `controller` - Find and open controller for current view
```bash
zed-rails-jumper controller -p "app/views/users/show.html.erb" -r "/path/to/rails/app"
```

## Development

To set up the development environment:

```bash
bundle install
bin/test
```

## License

MIT License - see the [LICENSE](MIT-LICENSE) file for details.
