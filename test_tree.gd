extends SceneTree
func _init():
    var t = Tree.new()
    print("Has item_mouse_selected: ", t.has_signal("item_mouse_selected"))
    print("Has gui_input: ", t.has_signal("gui_input"))
    print("Methods: ", t.get_method_list().filter(func(m): return m.name.begins_with("popup")))
    quit()

