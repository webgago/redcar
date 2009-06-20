
module Redcar
  # A Pane is a fixed viewport. A Redcar window may have multiple
  # Panes. Panes can be split horizontally and vertically to allow
  # the user to lay out their workspace as they see fit.
  #
  # Plugin authors should not create Panes by hand, rather they should
  # use Pane#split_horizontal and Window#panes to create and locate
  # panes.
  class Pane
    extend FreeBASE::StandardPlugin
    include FreeBASE::DataBusHelper

    # The Window the Pane is in.
    attr_accessor :window

    # Do not call this directly. Creates a new pane
    # attached to the given window. Redcar::Window manages
    # the creation of panes.
    def initialize(window)
      @window = window
    end

    # Replace this Pane in the Window with two new Panes, on
    # the left and right.
    def split_vertical
      @window.split_vertical(self)
    end

    # Replace this Pane in the Window with two new Panes, on
    # the top and bottom.
    def split_horizontal
      @window.split_horizontal(self)
    end

    # Undo the split_horizontal or split_vertical that created
    # this tab.
    def unify
      @window.unify(self)
    end
    
    # Subclasses should implement this to return the gtk_widget
    # that is displayed as the pane.
    def gtk_widget
      raise "abstract method"
    end
  end
end
