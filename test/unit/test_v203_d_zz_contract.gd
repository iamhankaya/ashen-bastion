extends GutTest
## v2.0.3 sözleşme (D ad alanı): ana sayfa/ayarlar iskeletleri. D iskeletin gövdesini doldurur; adları değiştirmez.
## `zz` ayırıcısı için test_v203_c_zz_schema.gd'ye bak.


func test_settings_sections_are_the_designed_four_in_order() -> void:
	assert_eq(
		SettingsSections.IDS, [&"ses", &"dokunus", &"gorunum", &"hakkinda"] as Array[StringName]
	)


func test_section_node_names_use_the_settings_prefix() -> void:
	for id in SettingsSections.IDS:
		assert_eq(SettingsSections.node_name(id), "settings_%s" % id)


func test_settings_flow_has_the_two_entry_sources_and_signals() -> void:
	assert_eq(SettingsFlow.SOURCE_MENU, &"menu")
	assert_eq(SettingsFlow.SOURCE_PAUSE, &"pause")
	var flow := SettingsFlow.new()
	assert_true(flow.has_signal("closed"))
	assert_true(flow.has_signal("hareket_azalt_toggled"))
	assert_true(flow.has_method("open"))
	assert_true(flow.has_method("close"))
