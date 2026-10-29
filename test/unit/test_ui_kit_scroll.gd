extends GutTest
## UiKit.make_scroll (sözleşme-B S-scroll): tek üretim noktası; touch_scroll ikinci çağrıda tekrar bağlamaz (meta bekçisi).


func _handlers(sc: ScrollContainer) -> int:
	return sc.gui_input.get_connections().size()


func test_default_is_vertical_with_touch_scroll() -> void:
	var sc: ScrollContainer = autofree(UiKit.make_scroll())
	assert_eq(sc.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
	assert_eq(sc.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	assert_true(sc.has_meta(&"touch_scroll"))
	assert_eq(_handlers(sc), 1)


func test_horizontal_axis_disables_vertical() -> void:
	var sc: ScrollContainer = autofree(UiKit.make_scroll(UiKit.SCROLL_AXIS_HORIZONTAL))
	assert_eq(sc.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
	assert_eq(sc.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)


func test_both_axes_open() -> void:
	var sc: ScrollContainer = autofree(UiKit.make_scroll(UiKit.SCROLL_AXIS_BOTH))
	assert_eq(sc.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
	assert_eq(sc.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)


func test_show_bars_false_hides_open_axis_bar_only() -> void:
	var sc: ScrollContainer = autofree(
		UiKit.make_scroll(UiKit.SCROLL_AXIS_HORIZONTAL, {"show_bars": false})
	)
	assert_eq(sc.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_SHOW_NEVER)
	assert_eq(sc.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)


func test_opts_are_applied() -> void:
	var sc: ScrollContainer = autofree(
		(
			UiKit
			. make_scroll(
				UiKit.SCROLL_AXIS_VERTICAL,
				{
					"name": "List",
					"follow_focus": true,
					"deadzone": 12,
					"mouse_filter": Control.MOUSE_FILTER_PASS,
					"size_flags_h": Control.SIZE_EXPAND_FILL,
					"size_flags_v": Control.SIZE_FILL,
					"custom_min": Vector2(10, 20),
				}
			)
		)
	)
	assert_eq(sc.name, &"List")
	assert_true(sc.follow_focus)
	assert_eq(sc.scroll_deadzone, 12)
	assert_eq(sc.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(sc.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	assert_eq(sc.size_flags_vertical, Control.SIZE_FILL)
	assert_eq(sc.custom_minimum_size, Vector2(10, 20))


func test_absent_opts_keep_godot_defaults() -> void:
	var ref: ScrollContainer = autofree(ClassDB.instantiate("ScrollContainer"))
	var sc: ScrollContainer = autofree(UiKit.make_scroll())
	assert_eq(sc.follow_focus, ref.follow_focus)
	assert_eq(sc.scroll_deadzone, ref.scroll_deadzone)
	assert_eq(sc.mouse_filter, ref.mouse_filter)
	assert_eq(sc.size_flags_horizontal, ref.size_flags_horizontal)
	assert_eq(sc.custom_minimum_size, ref.custom_minimum_size)


func test_touch_scroll_is_idempotent() -> void:
	var sc: ScrollContainer = autofree(ClassDB.instantiate("ScrollContainer"))
	UiKit.touch_scroll(sc)
	UiKit.touch_scroll(sc)
	assert_eq(_handlers(sc), 1)


func test_touch_scroll_after_make_scroll_does_not_double_bind() -> void:
	var sc: ScrollContainer = autofree(UiKit.make_scroll())
	UiKit.touch_scroll(sc)
	assert_eq(_handlers(sc), 1)
