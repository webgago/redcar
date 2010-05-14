module Redcar
  # This class is your plugin. Try adding new commands in here
  # and putting them in the menus.
  class MyPlugin
    
    # This method is run as Redcar is booting up.
    def self.menus
      # Here's how the plugin menus are drawn. Try adding more
      # items or sub_menus.
      Menu::Builder.build do
        sub_menu "Plugins" do
          sub_menu "My Plugin" do
            item "Hello World!", HelloWorldCommand
            item "Edit My Plugin", EditMyPluginCommand
          end
        end
      end
    end
    
    # Example command: showing a dialog box.
    class HelloWorldCommand < Redcar::Command
      def execute
        controller = Controller.new
        tab = win.new_tab(HtmlTab)
        tab.html_view.controller = controller
        tab.focus
      end
    end
    
    # Command to open a new window, make the project my_plugin
    # and open this file.
    class EditMyPluginCommand < Redcar::Command
      def execute
        # Open the project in a new window
        Project::Manager.open_project_for_path("plugins/my_plugin")
        
        # Create a new edittab
        tab  = Redcar.app.focussed_window.new_tab(Redcar::EditTab)
        
        # A FileMirror's job is to wrap up the file in an interface that the Document understands.
        mirror = Project::FileMirror.new(File.join(Redcar.root, "plugins", "my_plugin", "lib", "my_plugin.rb"))
        tab.edit_view.document.mirror = mirror
        
        # Make sure the tab is focussed and the user can't undo the insertion of the document text
        tab.edit_view.reset_undo
        tab.focus
      end
    end
    
    class Controller
      def title
        "Test"
      end
      
      def index
        keymap = all_keymap
        @keymap = all_keymap
        rhtml = ERB.new(File.read(File.join(File.dirname(__FILE__), "index.html.erb")))
        rhtml.result(binding)
      end
      
      private
      def all_keymap        
        keymap = Keymap.new("main", Redcar.platform)
        Redcar.plugin_manager.objects_implementing(:keymaps).each do |object|
          maps = object.keymaps
          keymaps = maps.select do |map| 
            map.platforms.include?(Redcar.platform)
          end
          keymap = keymaps.inject(keymap) {|k, nk| k.merge(nk) }
        end
        keymap.map
      end
      
    end
  end
end