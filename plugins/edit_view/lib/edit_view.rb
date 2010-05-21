
require "edit_view/actions/arrow_keys"
require "edit_view/actions/deletion"
require "edit_view/actions/esc"
require "edit_view/actions/tab"
require "edit_view/command"
require "edit_view/document"
require "edit_view/document/command"
require "edit_view/document/controller"
require "edit_view/document/indentation"
require "edit_view/document/mirror"
require "edit_view/edit_tab"
require "edit_view/modified_tabs_checker"
require "edit_view/tab_settings"
require "edit_view/info_speedbar"

module Redcar
  class EditView
    include Redcar::Model
    extend Redcar::Observable
    include Redcar::Observable
    
    extend Forwardable

    module Handler
      include Interface::Abstract

      def handle(edit_view, modifiers)
      end
    end
    
    class << self
      attr_reader :undo_sensitivity, :redo_sensitivity
      attr_reader :focussed_edit_view
    end
    
    def self.tab_settings
      @tab_settings ||= TabSettings.new
    end

    # unused?      
    def self.storage
      @storage ||= Plugin::Storage.new('edit_view_plugin')
    end

    def self.all_handlers(type)
      result = []
      method_name = :"#{type}_handlers"
      Redcar.plugin_manager.objects_implementing(method_name).each do |object|
        result += object.send(method_name)
      end
      result.each {|h| Handler.verify_interface!(h) }
    end

    def self.arrow_left_handlers
      [Actions::ArrowLeftHandler]
    end
    
    def self.arrow_right_handlers
      [Actions::ArrowRightHandler]
    end
    
    def self.tab_handlers
      [Actions::IndentTabHandler]
    end
    
    def self.backspace_handlers
      [Actions::BackspaceHandler]
    end
    
    def self.delete_handlers
      [Actions::DeleteHandler]
    end
    
    def self.esc_handlers
      [Actions::EscapeHandler]
    end
    
    def self.all_tab_handlers
      all_handlers(:tab)
    end
    
    def self.all_esc_handlers
      all_handlers(:esc)
    end

    def self.all_arrow_left_handlers
      all_handlers(:arrow_left)
    end

    def self.all_arrow_right_handlers
      all_handlers(:arrow_right)
    end

    def self.all_delete_handlers
      all_handlers(:delete)
    end

    def self.all_backspace_handlers
      all_handlers(:backspace)
    end

    def handle_key(handlers, modifiers)

      sorted_handlers = handlers.sort_by {|h| (h.respond_to?(:priority) and h.priority) || 0 }.reverse
      sorted_handlers.detect do |h|
        begin
          h.handle(self, modifiers)
        rescue => e
          puts "*** Error in key handler: #{e.class} #{e.message}"
          puts e.backtrace.map {|l| " - " + l }
        end
      end
    end

    def tab_pressed(modifiers)
      handle_key(EditView.all_tab_handlers, modifiers)
    end
    
    def esc_pressed(modifiers)
      handle_key(EditView.all_esc_handlers, modifiers)
    end
    
    def left_pressed(modifiers)
      handle_key(EditView.all_arrow_left_handlers, modifiers)
    end
    
    def right_pressed(modifiers)
      handle_key(EditView.all_arrow_right_handlers, modifiers)
    end
    
    def delete_pressed(modifiers)
      handle_key(EditView.all_delete_handlers, modifiers)
    end
    
    def backspace_pressed(modifiers)
      handle_key(EditView.all_backspace_handlers, modifiers)
    end
    
    # Called by the GUI whenever an EditView is focussed or
    # loses focus. Sends :focussed_edit_view event.
    def self.focussed_edit_view=(edit_view)
      @focussed_edit_view = edit_view
      edit_view.check_for_updated_document if edit_view
      notify_listeners(:focussed_edit_view, edit_view)
    end
    
    def self.sensitivities
      [
        Sensitivity.new(:edit_tab_focussed, Redcar.app, false, [:tab_focussed]) do |tab|
          tab and tab.is_a?(EditTab)
        end,
        Sensitivity.new(:edit_view_focussed, EditView, false, [:focussed_edit_view]) do |edit_view|
          edit_view
        end,
        Sensitivity.new(:selected_text, Redcar.app, false, [:focussed_tab_selection_changed, :tab_focussed]) do
          if win = Redcar.app.focussed_window
            tab = win.focussed_notebook.focussed_tab
            tab and tab.is_a?(EditTab) and tab.edit_view.document.selection?
          end
        end,
        @undo_sensitivity = 
          Sensitivity.new(:undoable, Redcar.app, false, [:focussed_tab_changed, :tab_focussed]) do
            tab = Redcar.app.focussed_window.focussed_notebook.focussed_tab
            tab and tab.is_a?(EditTab) and tab.edit_view.undoable?
          end,
        @redo_sensitivity = 
          Sensitivity.new(:redoable, Redcar.app, false, [:focussed_tab_changed, :tab_focussed]) do
            tab = Redcar.app.focussed_window.focussed_notebook.focussed_tab
            tab and tab.is_a?(EditTab) and tab.edit_view.redoable?
          end,
        Sensitivity.new(:clipboard_not_empty, Redcar.app, false, [:clipboard_added, :focussed_window]) do
          Redcar.app.clipboard.length > 0
        end
      ]
    end

    def self.font_info
      if Redcar.platform == :osx
        default_font = "Monaco"
        default_font_size = 15
      elsif Redcar.platform == :linux
        default_font = "Monospace"
        default_font_size = 11
      elsif Redcar.platform == :windows
        default_font = "Courier New"
        default_font_size = 9
      end
      [ ARGV.option("font") || default_font, 
        (ARGV.option("font-size") || default_font_size).to_i ]
    end
    
    def self.font
      font_info[0]
    end
    
    def self.font_size
      font_info[1]
    end
    
    def self.theme
      ARGV.option("theme") || "Twilight"
    end    
    
    def self.focussed_tab_edit_view
      Redcar.app.focussed_notebook_tab.edit_view if Redcar.app.focussed_notebook_tab and Redcar.app.focussed_notebook_tab.edit_tab?
    end
    
    def self.focussed_edit_view_document
      focussed_tab_edit_view.document if focussed_tab_edit_view
    end
    
    def self.focussed_document_mirror
      focussed_edit_view_document.mirror if focussed_edit_view_document
    end
    
    def self.all_edit_views
      Redcar.app.windows.map {|w| w.notebooks.map {|n| n.tabs}.flatten }.flatten.select {|t| t.is_a?(EditTab)}.map {|t| t.edit_view}
    end
    
    attr_reader :document
    
    def initialize
      create_document
      @grammar = nil
      @focussed = nil
    end
    
    def create_document
      @document = Redcar::Document.new(self)
    end
    
    def_delegators :controller, :undo,      :redo,
                                :undoable?, :redoable?,
                                :reset_undo,
                                :cursor_offset, :cursor_offset=,
                                :scroll_to_line
    
    def grammar
      @grammar
    end
    
    def grammar=(name)
      set_grammar(name)
      notify_listeners(:grammar_changed, name)
    end
    
    def set_grammar(name)
      @grammar = name
      self.tab_width = EditView.tab_settings.width_for(name)
      self.soft_tabs = EditView.tab_settings.softness_for(name)
      refresh_show_invisibles
    end
    
    def focus
      notify_listeners(:focussed)
    end

    def tab_width
      @tab_width
    end
    
    def tab_width=(val)
      @tab_width = val
      EditView.tab_settings.set_width_for(grammar, val)
      notify_listeners(:tab_width_changed, val)
    end
    
    def set_tab_width(val)
      @tab_width = val
    end
    
    def soft_tabs?
      @soft_tabs
    end
    
    def soft_tabs=(bool)
      @soft_tabs = bool
      EditView.tab_settings.set_softness_for(grammar, bool)
      notify_listeners(:softness_changed, bool)
    end
    
    def show_invisibles?
      @show_invisibles
    end

    def self.show_invisibles?
      EditView.tab_settings.show_invisibles?
    end

    def self.show_invisibles=(bool)
      EditView.tab_settings.set_show_invisibles(bool)
      all_edit_views.each {|ev| ev.refresh_show_invisibles }
    end
    
    def refresh_show_invisibles
      @show_invisibles = EditView.tab_settings.show_invisibles?
      notify_listeners(:invisibles_changed, @show_invisibles)
    end

    def title=(title)
      notify_listeners(:title_changed, title)
    end

    def serialize
      { :contents      => document.to_s,
        :cursor_offset => cursor_offset,
        :grammar       => grammar         }
    end
    
    def deserialize(data)
      self.grammar       = data[:grammar]
      document.text      = data[:contents]
      self.cursor_offset = data[:cursor_offset]
    end
    
    def delay_parsing
      controller.delay_parsing { yield }
    end
    
    def reset_last_checked
      @last_checked = Time.now
    end
    
    def check_for_updated_document
      # awful forward dependency on the Project plugin here....
      if document and 
            document.mirror and 
            document.mirror.is_a?(Project::FileMirror) and 
            document.mirror.changed_since?(@last_checked)
        if document.modified?
          result = Application::Dialog.message_box(
                     "This file has been changed on disc, and you have unsaved changes in Redcar.\n\n" + 
                     "Revert to version on disc (and lose your changes)?",
                     :buttons => :yes_no
                    )
          case result
          when :yes
            document.update_from_mirror
          end
        else
          puts "updating document as has changed since #{@last_checked}"
          document.update_from_mirror
        end
      end
      @last_checked = Time.now
    end
  end
end

