class_name TooltipPolicy
extends RefCounted
## A scope has one inspector for pointer and focus; native delayed tooltips are hidden in it.

static func suppress_native(scope: Control) -> void:
	var local_theme := scope.theme.duplicate() as Theme if scope.theme != null else UITheme.build()
	local_theme.set_color("font_color", "TooltipLabel", Color.TRANSPARENT)
	local_theme.set_color("font_shadow_color", "TooltipLabel", Color.TRANSPARENT)
	local_theme.set_color("font_outline_color", "TooltipLabel", Color.TRANSPARENT)
	local_theme.set_constant("outline_size", "TooltipLabel", 0)
	local_theme.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())
	scope.theme = local_theme


static func install(scope: Control) -> void:
	if scope.has_node("ContextTooltip"): return
	suppress_native(scope)
	var inspector := HoverInspector.new()
	inspector.name = "ContextTooltip"
	inspector.manages_detail_input = true
	# A modal owns inspection while open; the title/settings scope stays quiet underneath it.
	inspector.suppressed = func() -> bool:
		for modal in scope.get_children():
			if (modal is WorldModal or modal is OwnedChoicePopup) and modal.is_visible_in_tree(): return true
		return false
	scope.add_child(inspector)
	UIFeedback.install(scope)
