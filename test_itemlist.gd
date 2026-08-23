extends SceneTree
func _init():
    var list = ItemList.new()
    list.max_text_lines = 2
    list.icon_mode = ItemList.ICON_MODE_TOP
    list.fixed_column_width = 200
    list.add_item("Line 1\nLine 2")
    
    print("Item text: ", list.get_item_text(0))
    print("Is newline present? ", list.get_item_text(0).find("\n") != -1)
    
    quit()
