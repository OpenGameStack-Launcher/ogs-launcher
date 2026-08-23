extends SceneTree
func _init():
    var p = PopupMenu.new()
    print("PopupMenu methods: ")
    for m in p.get_method_list():
        if m.name.begins_with("popup"):
            print("  - ", m.name)
    quit()

